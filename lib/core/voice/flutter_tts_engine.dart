import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Android Google TTS. Completion is tracked with our own completer so that
/// stop() or an engine error always ends the pending speak() future.
///
/// flutter_tts delivers cancel/complete events asynchronously and without an
/// utterance id, so a late event from the previous utterance could otherwise
/// finish a newer speak(). The platform always emits the previous utterance's
/// stop event before the new utterance's start event, so cancel/complete
/// events are only honoured once the current utterance has reported start.
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine._(this._tts);

  /// Engine speech rate at speed 1.0.
  static const _baseRate = 0.42;

  static const _safetyTimeout = Duration(seconds: 15);

  final FlutterTts _tts;

  /// Locales (e.g. 'vi-VN') the device has no voice for; shown in the parent area.
  Set<String> missingLocales = const {};
  Completer<void>? _current;
  bool _started = false;
  String? _locale;
  double _speed = 1.0;

  static Future<FlutterTtsEngine> create() => createWith(FlutterTts());

  @visibleForTesting
  static Future<FlutterTtsEngine> createWith(FlutterTts tts) async {
    final engine = FlutterTtsEngine._(tts);
    await tts.awaitSpeakCompletion(false);
    await tts.setSpeechRate(_baseRate);
    await tts.setPitch(1.15);
    tts.setStartHandler(engine._onStart);
    tts.setCompletionHandler(engine._onEnd);
    tts.setCancelHandler(engine._onEnd);
    tts.setErrorHandler((_) => engine._finish());
    engine.missingLocales = {
      for (final l in const ['vi-VN', 'en-US'])
        if (!await _isAvailable(tts, l)) l,
    };
    return engine;
  }

  /// isLanguageAvailable returns a bool or an int depending on the platform
  /// code path; anything unexpected, a hang (3 s) or a thrown error counts as
  /// unavailable so app start never blocks on a broken engine.
  static Future<bool> _isAvailable(FlutterTts tts, String locale) async {
    try {
      final r = await tts.isLanguageAvailable(locale).timeout(const Duration(seconds: 3));
      return r == true || r == 1 || r == 'true';
    } catch (_) {
      return false;
    }
  }

  void _onStart() => _started = true;

  /// Completion/cancel: only meaningful for the utterance that has started.
  void _onEnd() {
    if (_started) _finish();
  }

  void _finish() {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> speak(String text, {required String lang, double speed = 1.0}) async {
    _finish();
    if (speed != _speed) {
      await _tts.setSpeechRate(_baseRate * speed);
      _speed = speed;
    }
    final locale = lang == 'vi' ? 'vi-VN' : 'en-US';
    if (_locale != locale) {
      // Only remember the locale once the engine accepted it (1 / true).
      final r = await _tts.setLanguage(locale);
      if (r == true || r == 1) _locale = locale;
    }
    final c = Completer<void>();
    _current = c;
    _started = false;
    // The platform call itself can hang when the Android TTS engine is
    // missing or broken, so it and the completion wait share one timeout.
    // A fixed 15 s (rather than scaled by text length) keeps long phrases from
    // being cut off at the slow speech rate.
    try {
      await (() async {
        await _tts.speak(text);
        await c.future;
      })().timeout(_safetyTimeout);
    } on TimeoutException {
      // Nothing to report: the child just moves on without sound.
    } finally {
      if (identical(_current, c)) _current = null;
      if (!c.isCompleted) c.complete();
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _finish();
  }
}
