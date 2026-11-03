import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_recognizer.dart';

typedef _OnResult = void Function(List<String> transcripts, bool isFinal);

class _Session {
  _Session(this.onResult);

  final _OnResult onResult;
  bool onDevice = true;
  bool retriedOnline = false;
  bool gotResult = false;
  bool finished = false;

  /// stop() was called (the child let go): a final result is on its way.
  bool stopping = false;

  /// The platform listen call has returned successfully.
  bool listening = false;
  List<String> last = const [];
  Timer? grace;
  Timer? doneTimer;
}

/// [SpeechRecognizer] on top of the `speech_to_text` plugin (Android's
/// SpeechRecognizer service), US English.
///
/// Findings from speech_to_text 7.5.0 that shape this class:
///  * `initialize` asks for RECORD_AUDIO and returns false when it is denied or
///    no recognition service exists; it is safe to call again.
///  * `SpeechListenOptions.onDevice` is only honoured on Android 12+, and when
///    the device cannot do it the plugin quietly uses the online recogniser; a
///    missing offline language model instead surfaces as an
///    `error_language_*` error, which we answer by listening again online.
///  * `listenFor`/`pauseFor` are enforced by the plugin (Android adds its own
///    1-3 s pause limit); on expiry it stops and delivers a final result.
///  * Every result carries `alternates` (best first); all are passed on.
///  * After [stop], a missing final result is covered by the plugin's 2 s final
///    timeout (last partial becomes final) and the `done` status; a grace timer
///    here covers anything else. Android reports `doneNoResult` right at stop()
///    when no partial was sent, and the real final follows 0.5-1.5 s later, so
///    `done` never ends a stopped session; the plugin also drops errors that
///    arrive after stop(), which is why a silent attempt ends at the grace timer.
class SpeechToTextRecognizer implements SpeechRecognizer {
  SpeechToTextRecognizer({SpeechToText? speech, this.listenFor = const Duration(seconds: 8), this.pauseFor = const Duration(seconds: 3)})
    : _stt = speech ?? SpeechToText();

  final SpeechToText _stt;
  final Duration listenFor;
  final Duration pauseFor;

  /// Errors that mean "this recogniser cannot do it", not "the child said nothing".
  static const _retryOnlineErrors = {
    'error_language_not_supported',
    'error_language_unavailable',
    'error_server',
    'error_server_disconnected',
    'error_client',
  };
  static const _doneDelay = Duration(milliseconds: 400);
  static const _graceAfterStop = Duration(seconds: 4);

  bool _available = false;
  Future<bool>? _initFuture;
  String _localeId = 'en_US';
  _Session? _session;

  /// The offline recogniser failed once: later sessions go straight online.
  bool _onDeviceFailed = false;

  @override
  bool get available => _available;

  @override
  Future<bool> init() async {
    final future = _initFuture ??= _initialize();
    // A refusal is not cached: the next call may be asked again.
    final ok = await future;
    if (!ok && identical(_initFuture, future)) _initFuture = null;
    // The permission can be withdrawn after a successful init.
    return ok && _available;
  }

  Future<bool> _initialize() async {
    try {
      _available = await _stt.initialize(onError: _onError, onStatus: _onStatus);
    } on Object catch (e) {
      debugPrint('Speech init failed: $e');
      _available = false;
    }
    if (_available) _localeId = await _pickLocale();
    return _available;
  }

  /// `en_US` when the recogniser lists it, else another English, else `en_US`
  /// anyway (Android only lists the on-device locales).
  Future<String> _pickLocale() async {
    try {
      final ids = [for (final l in await _stt.locales()) l.localeId];
      String norm(String id) => id.replaceAll('-', '_');
      final us = ids.where((id) => norm(id) == 'en_US');
      if (us.isNotEmpty) return us.first;
      final en = ids.where((id) => norm(id).startsWith('en_'));
      if (en.isNotEmpty) return en.first;
    } on Object catch (e) {
      debugPrint('Speech locales failed: $e');
    }
    return 'en_US';
  }

  @override
  Future<void> start({required _OnResult onResult}) async {
    if (!_available) return;
    // The new session is registered BEFORE the old one is cancelled, so a
    // stop() or cancel() landing during that await reaches this session.
    final previous = _session;
    if (previous != null) _discard(previous);
    final session = _session = _Session(onResult);
    await _cancelPlatform();
    if (session.finished || !identical(session, _session)) return;
    await _listen(session, onDevice: !_onDeviceFailed);
  }

  Future<void> _listen(_Session s, {required bool onDevice}) async {
    s.onDevice = onDevice;
    s.listening = false;
    try {
      await _stt.listen(
        onResult: (r) => _onSpeech(s, r),
        listenOptions: SpeechListenOptions(
          onDevice: onDevice,
          partialResults: true,
          cancelOnError: false,
          listenFor: listenFor,
          pauseFor: pauseFor,
          localeId: _localeId,
        ),
      );
    } on Object catch (e) {
      debugPrint('Speech listen failed (onDevice=$onDevice): $e');
      if (onDevice) _onDeviceFailed = true;
      if (identical(s, _session) && !s.finished) {
        // The child already let go: do not start listening again behind their back.
        if (onDevice && !s.stopping) {
          await _retryOnline(s);
        } else {
          _finish(s);
        }
      }
      return;
    }
    if (s.finished || !identical(s, _session)) return;
    s.listening = true;
    // A stop() that arrived while the listen was starting is applied now.
    if (s.stopping) await _applyStop(s);
  }

  Future<void> _retryOnline(_Session s) async {
    s.retriedOnline = true;
    s.listening = false;
    await _cancelPlatform();
    if (identical(s, _session) && !s.finished) await _listen(s, onDevice: false);
  }

  void _onSpeech(_Session s, SpeechRecognitionResult r) {
    if (s.finished || !identical(s, _session)) return;
    final heard = <String>[];
    for (final a in r.alternates) {
      final text = a.recognizedWords.trim();
      if (text.isNotEmpty && !heard.contains(text)) heard.add(text);
    }
    if (heard.isNotEmpty) {
      s.gotResult = true;
      s.last = heard;
    }
    if (r.finalResult) {
      _finish(s);
    } else if (heard.isNotEmpty) {
      s.onResult(heard, false);
    }
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('Speech error: $error');
    if (error.errorMsg == 'error_permission') _available = false;
    final s = _session;
    if (s == null || s.finished) return;
    final onDeviceUnusable = s.onDevice && !s.gotResult && _retryOnlineErrors.contains(error.errorMsg);
    if (onDeviceUnusable) _onDeviceFailed = true;
    if (onDeviceUnusable && !s.retriedOnline && !s.stopping) {
      s.doneTimer?.cancel();
      unawaited(_retryOnline(s));
    } else {
      _finish(s);
    }
  }

  void _onStatus(String status) {
    final s = _session;
    if (s == null || s.finished || status != SpeechToText.doneStatus) return;
    // After stop() Android reports `doneNoResult` at once when no partial was
    // sent, yet the real final result follows ~0.5-1.5 s later: wait for it (or
    // for the error, or the grace timer armed by stop()).
    if (s.stopping) return;
    s.doneTimer?.cancel();
    // `done` is also sent BEFORE the error that explains a failed on-device
    // listen, so give that error a moment to trigger the online retry. Any other
    // `done` (plugin-side pause/listenFor stop) may also precede a late final.
    final mayRetryOnline = s.onDevice && !s.retriedOnline && !s.gotResult;
    s.doneTimer = Timer(mayRetryOnline ? _doneDelay : _graceAfterStop, () => _finish(s));
  }

  /// Delivers the one final result of [s]: the last transcripts, or none.
  void _finish(_Session s) {
    if (s.finished) return;
    s.finished = true;
    s.grace?.cancel();
    s.doneTimer?.cancel();
    if (identical(s, _session)) _session = null;
    s.onResult(s.last, true);
  }

  @override
  Future<void> stop() async {
    final s = _session;
    if (s == null || s.finished) return;
    s.stopping = true;
    // Still starting (cancelling the old session / waiting for listen): the
    // stop is applied as soon as the listen is running.
    if (!s.listening) return;
    await _applyStop(s);
  }

  Future<void> _applyStop(_Session s) async {
    s.doneTimer?.cancel();
    s.grace?.cancel();
    s.grace = Timer(_graceAfterStop, () => _finish(s));
    try {
      await _stt.stop();
    } on Object catch (e) {
      debugPrint('Speech stop failed: $e');
      _finish(s);
    }
  }

  @override
  Future<void> cancel() async {
    final s = _session;
    _session = null;
    if (s != null) _discard(s);
    if (!_available) return;
    await _cancelPlatform();
  }

  void _discard(_Session s) {
    s.finished = true;
    s.grace?.cancel();
    s.doneTimer?.cancel();
    if (identical(s, _session)) _session = null;
  }

  Future<void> _cancelPlatform() async {
    try {
      await _stt.cancel();
    } on Object catch (e) {
      debugPrint('Speech cancel failed: $e');
    }
  }
}
