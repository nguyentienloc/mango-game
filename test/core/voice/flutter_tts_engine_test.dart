import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:xoai_castle/core/voice/flutter_tts_engine.dart';

class FakeFlutterTts extends Fake implements FlutterTts {
  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onCancel;
  ErrorHandler? onError;

  final spoken = <String>[];
  final languages = <String>[];
  double? rate;
  double? pitch;
  Object? speakError;
  Object? languageError;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;
  @override
  Future<dynamic> setSpeechRate(double rate) async {
    this.rate = rate;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    this.pitch = pitch;
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    if (languageError != null) throw languageError!;
    languages.add(language);
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (speakError != null) throw speakError!;
    spoken.add(text);
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;

  @override
  void setStartHandler(VoidCallback callback) => onStart = callback;
  @override
  void setCompletionHandler(VoidCallback callback) => onComplete = callback;
  @override
  void setCancelHandler(VoidCallback callback) => onCancel = callback;
  @override
  void setErrorHandler(ErrorHandler handler) => onError = handler;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeFlutterTts tts;
  late FlutterTtsEngine engine;

  setUp(() async {
    tts = FakeFlutterTts();
    engine = await FlutterTtsEngine.createWith(tts);
  });

  test('configures rate, pitch and maps lang to locale', () async {
    final f = engine.speak('hi', lang: 'vi');
    await settle();
    expect(tts.rate, 0.42);
    expect(tts.pitch, 1.15);
    expect(tts.languages, ['vi-VN']);
    tts.onStart?.call();
    tts.onComplete!();
    await f;
    final g = engine.speak('hello', lang: 'en');
    await settle();
    expect(tts.languages, ['vi-VN', 'en-US']);
    tts.onStart?.call();
    tts.onComplete!();
    await g;
  });

  test('speak completes on its own completion event after start', () async {
    var done = false;
    final f = engine.speak('hi', lang: 'en').then((_) => done = true);
    await settle();
    expect(done, isFalse);
    tts.onStart?.call();
    await settle();
    expect(done, isFalse);
    tts.onComplete!();
    await f;
    expect(done, isTrue);
  });

  test('stale cancel/complete before start of new speak does not complete it',
      () async {
    final first = engine.speak('one', lang: 'en');
    await settle();
    tts.onStart?.call();

    // VoiceService does stop() then speak(); the stop ends the first future.
    await engine.stop();
    await first;

    var done = false;
    final second = engine.speak('two', lang: 'en').then((_) => done = true);
    await settle();

    // Late events from the first utterance arrive before the second starts.
    tts.onCancel!();
    tts.onComplete!();
    await settle();
    expect(done, isFalse);

    tts.onStart?.call();
    await settle();
    expect(done, isFalse);

    tts.onComplete!();
    await second;
    expect(done, isTrue);
  });

  test('stop() completes a pending speak', () async {
    var done = false;
    final f = engine.speak('hi', lang: 'en').then((_) => done = true);
    await settle();
    expect(done, isFalse);
    await engine.stop();
    await f;
    expect(done, isTrue);
  });

  test('engine error completes a pending speak even before start', () async {
    var done = false;
    final f = engine.speak('hi', lang: 'en').then((_) => done = true);
    await settle();
    tts.onError!('boom');
    await f;
    expect(done, isTrue);
  });

  test('a new speak completes the previous pending one', () async {
    var firstDone = false;
    final first =
        engine.speak('one', lang: 'en').then((_) => firstDone = true);
    await settle();
    final second = engine.speak('two', lang: 'en');
    await first;
    expect(firstDone, isTrue);
    tts.onStart?.call();
    tts.onComplete!();
    await second;
  });

  test('throwing platform speak propagates and leaves nothing pending',
      () async {
    tts.speakError = StateError('platform down');
    await expectLater(
        engine.speak('hi', lang: 'en'), throwsA(isA<StateError>()));

    tts.speakError = null;
    var done = false;
    final f = engine.speak('again', lang: 'en').then((_) => done = true);
    await settle();
    expect(tts.spoken, ['again']);
    // A stale event from before must not matter; only the real completion does.
    tts.onComplete!();
    await settle();
    expect(done, isFalse);
    tts.onStart?.call();
    tts.onComplete!();
    await f;
    expect(done, isTrue);
  });

  test('throwing setLanguage propagates and the next speak works', () async {
    tts.languageError = StateError('no voice');
    await expectLater(
        engine.speak('hi', lang: 'vi'), throwsA(isA<StateError>()));

    tts.languageError = null;
    final f = engine.speak('again', lang: 'vi');
    await settle();
    tts.onStart?.call();
    tts.onComplete!();
    await f;
    expect(tts.languages, ['vi-VN']);
  });

  testWidgets('15 s safety timeout completes speak and clears pending state',
      (tester) async {
    var done = false;
    final f = engine.speak('hi', lang: 'en').then((_) => done = true);
    await tester.pump(const Duration(seconds: 14));
    expect(done, isFalse);
    await tester.pump(const Duration(seconds: 2));
    await f;
    expect(done, isTrue);

    // Nothing pending: the next speak is independent and needs its own events.
    var done2 = false;
    final g = engine.speak('again', lang: 'en').then((_) => done2 = true);
    await tester.pump();
    tts.onStart?.call();
    tts.onComplete!();
    await g;
    expect(done2, isTrue);
  });
}
