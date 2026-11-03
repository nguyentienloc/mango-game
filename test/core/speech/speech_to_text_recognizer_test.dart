import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:xoai_castle/core/speech/speech_to_text_recognizer.dart';

/// Drives the real recogniser against a scripted platform channel, the way the
/// Android plugin talks to it (including its quirks: `done` arrives before the
/// error that explains a failed listen).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late bool initAnswer;
  late List<String> locales;
  late List<Object?> listenReplies; // per listen call: true / false / an error to throw

  setUp(() {
    calls = [];
    initAnswer = true;
    locales = ['en_GB:English (UK)', 'en_US:English (US)', 'vi_VN:Vietnamese'];
    listenReplies = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return initAnswer;
        case 'locales':
          return locales;
        case 'listen':
          final reply = listenReplies.isEmpty ? true : listenReplies.removeAt(0);
          if (reply is Exception) throw reply;
          return reply;
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> push(String method, Object args) async {
    await messenger.handlePlatformMessage(channel.name, const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)), (_) {});
  }

  Future<void> hear(List<String> words, {bool isFinal = true}) => push(
    'textRecognition',
    jsonEncode({
      'alternates': [for (final w in words) {'recognizedWords': w, 'confidence': 0.9}],
      'resultType': isFinal ? 2 : 0,
    }),
  );

  Future<void> error(String msg) => push('notifyError', jsonEncode({'errorMsg': msg, 'permanent': true}));
  Future<void> status(String s) => push('notifyStatus', s);

  List<MethodCall> listens() => calls.where((c) => c.method == 'listen').toList();

  String fmt(List<String> t, bool f) => '${t.join(' | ')}${f ? ' [final]' : ''}';

  SpeechToTextRecognizer make() => SpeechToTextRecognizer(speech: SpeechToText.withMethodChannel());

  test('not available until init succeeds; a refusal is reported and may be retried', () async {
    initAnswer = false;
    final r = make();
    expect(r.available, isFalse);
    expect(await r.init(), isFalse);
    expect(r.available, isFalse);
    initAnswer = true;
    expect(await r.init(), isTrue);
    expect(r.available, isTrue);
    expect(calls.where((c) => c.method == 'initialize'), hasLength(2));
  });

  test('init asks the plugin once, even when called repeatedly', () async {
    final r = make();
    await Future.wait([r.init(), r.init()]);
    await r.init();
    expect(calls.where((c) => c.method == 'initialize'), hasLength(1));
  });

  test('start before init does nothing', () async {
    final r = make();
    var results = 0;
    await r.start(onResult: (_, _) => results++);
    expect(listens(), isEmpty);
    expect(results, 0);
  });

  test('listens in en_US, on-device first, 8 s / 3 s', () async {
    final r = make();
    await r.init();
    await r.start(onResult: (_, _) {});
    final args = listens().single.arguments as Map;
    expect(args['localeId'], 'en_US');
    expect(args['onDevice'], isTrue);
    expect(args['listenFor'], 8000);
    expect(args['pauseFor'], 3000);
    expect(args['partialResults'], isTrue);
  });

  test('falls back to en_US even when the recogniser lists no locales', () async {
    locales = [];
    final r = make();
    await r.init();
    await r.start(onResult: (_, _) {});
    expect((listens().single.arguments as Map)['localeId'], 'en_US');
  });

  test('passes partials, then every alternate of the final result once', () async {
    final r = make();
    await r.init();
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    await hear(['my'], isFinal: false);
    await hear(['my name is an', 'my name is ann', 'my name is an'], isFinal: true);
    await status('done');
    expect(got, ['my', 'my name is an | my name is ann [final]']);
  });

  test('silence: a final empty result, not a hang', () async {
    final r = make();
    await r.init();
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    await status('notListening');
    await status('doneNoResult');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(got, [' [final]']);
  });

  test('stop with only a partial heard still ends with one final (the plugin turns the partial final)', () async {
    final r = make();
    await r.init();
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    await hear(['hello'], isFinal: false);
    await r.stop();
    await hear(['hello'], isFinal: true);
    expect(got.last, 'hello [final]');
    expect(got.where((g) => g.endsWith('[final]')), hasLength(1));
  });

  test('on-device language error (reported after done, like Android) retries online and reports that result', () async {
    final r = make();
    await r.init();
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    await status('doneNoResult');
    await error('error_language_unavailable');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(got, isEmpty, reason: 'the failed on-device listen must not end the session');
    final l = listens();
    expect(l, hasLength(2));
    expect((l[0].arguments as Map)['onDevice'], isTrue);
    expect((l[1].arguments as Map)['onDevice'], isFalse);
    await hear(['five'], isFinal: true);
    expect(got, ['five [final]']);
  });

  test('a listen call that throws on-device is retried online; a second failure ends the session', () async {
    listenReplies = [PlatformException(code: 'listenFailed'), PlatformException(code: 'listenFailed')];
    final r = make();
    await r.init();
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    expect(listens(), hasLength(2));
    expect((listens()[1].arguments as Map)['onDevice'], isFalse);
    expect(got, [' [final]']);
  });

  test('no_match is the child saying nothing useful: final empty, no online retry', () async {
    final r = make();
    await r.init();
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    await error('error_no_match');
    expect(got, [' [final]']);
    expect(listens(), hasLength(1));
  });

  test('a permission error ends the session and makes the recogniser unavailable', () async {
    final r = make();
    await r.init();
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    await error('error_permission');
    expect(got, [' [final]']);
    expect(r.available, isFalse);
  });

  test('cancel drops the session: no final result follows', () async {
    final r = make();
    await r.init();
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    await r.cancel();
    await hear(['late'], isFinal: true);
    await status('done');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(got, isEmpty);
    expect(calls.map((c) => c.method), contains('cancel'));
  });

  test('a new start replaces the running session', () async {
    final r = make();
    await r.init();
    final first = <bool>[];
    final second = <List<String>>[];
    await r.start(onResult: (_, f) => first.add(f));
    await r.start(onResult: (t, f) => second.add(t));
    await hear(['red']);
    expect(first, isEmpty);
    expect(second, [['red']]);
  });
}
