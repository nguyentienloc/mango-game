import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Android Google TTS. Completion is tracked with our own completer so that
/// stop() or an engine error always ends the pending speak() future.
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine._(this._tts);

  final FlutterTts _tts;
  Completer<void>? _current;
  String? _locale;

  static Future<FlutterTtsEngine> create() async {
    final tts = FlutterTts();
    final engine = FlutterTtsEngine._(tts);
    await tts.awaitSpeakCompletion(false);
    await tts.setSpeechRate(0.42);
    await tts.setPitch(1.15);
    tts.setCompletionHandler(engine._finish);
    tts.setCancelHandler(engine._finish);
    tts.setErrorHandler((_) => engine._finish());
    return engine;
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
    await _tts.speak(text);
    await c.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _finish();
  }
}
