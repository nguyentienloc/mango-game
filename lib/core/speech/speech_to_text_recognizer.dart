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
///    here covers anything else.
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

  @override
  bool get available => _available;

  @override
  Future<bool> init() {
    final future = _initFuture ??= _initialize();
    // A refusal is not cached: the next call may be asked again.
    future.then((ok) {
      if (!ok && identical(_initFuture, future)) _initFuture = null;
    });
    return future;
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
    await cancel();
    final session = _session = _Session(onResult);
    await _listen(session, onDevice: true);
  }

  Future<void> _listen(_Session s, {required bool onDevice}) async {
    s.onDevice = onDevice;
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
      if (identical(s, _session) && !s.finished) {
        if (onDevice) {
          await _retryOnline(s);
        } else {
          _finish(s);
        }
      }
    }
  }

  Future<void> _retryOnline(_Session s) async {
    s.retriedOnline = true;
    try {
      await _stt.cancel();
    } on Object catch (_) {}
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
    if (s.onDevice && !s.retriedOnline && !s.gotResult && _retryOnlineErrors.contains(error.errorMsg)) {
      s.doneTimer?.cancel();
      unawaited(_retryOnline(s));
    } else {
      _finish(s);
    }
  }

  void _onStatus(String status) {
    final s = _session;
    if (s == null || s.finished) return;
    // `done` = nothing more is coming (the plugin only reports it once the final
    // result was delivered, or when there never will be one). On Android it is
    // sent BEFORE the error that explains a failed listen, so wait a moment: an
    // on-device failure must get its chance to retry online.
    if (status == SpeechToText.doneStatus) {
      s.doneTimer?.cancel();
      s.doneTimer = Timer(_doneDelay, () => _finish(s));
    }
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
    if (s != null) {
      s.finished = true;
      s.grace?.cancel();
      s.doneTimer?.cancel();
    }
    if (!_available) return;
    try {
      await _stt.cancel();
    } on Object catch (e) {
      debugPrint('Speech cancel failed: $e');
    }
  }
}
