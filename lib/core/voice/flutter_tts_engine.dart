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

  static const _safetyTimeout = Duration(seconds: 15);

  final FlutterTts _tts;
  Completer<void>? _current;
  bool _started = false;
  String? _locale;

  static Future<FlutterTtsEngine> create() => createWith(FlutterTts());

  @visibleForTesting
  static Future<FlutterTtsEngine> createWith(FlutterTts tts) async {
    final engine = FlutterTtsEngine._(tts);
    await tts.awaitSpeakCompletion(false);
    await tts.setSpeechRate(0.42);
    await tts.setPitch(1.15);
    tts.setStartHandler(engine._onStart);
    tts.setCompletionHandler(engine._onEnd);
    tts.setCancelHandler(engine._onEnd);
    tts.setErrorHandler((_) => engine._finish());
    return engine;
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
  Future<void> speak(String text, {required String lang}) async {
    _finish();
    final locale = lang == 'vi' ? 'vi-VN' : 'en-US';
    if (_locale != locale) {
      await _tts.setLanguage(locale);
      _locale = locale;
    }
    final c = Completer<void>();
    _current = c;
    _started = false;
    try {
      await _tts.speak(text);
    } catch (_) {
      if (identical(_current, c)) _current = null;
      rethrow;
    }
    await c.future.timeout(_safetyTimeout, onTimeout: () {
      if (identical(_current, c)) _finish();
    });
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _finish();
  }
}
