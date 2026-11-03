import 'dart:async';
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
  Completer<void>? listenGate; // when set, 'listen' waits for it
  Completer<void>? cancelGate; // when set, 'cancel' waits for it

  setUp(() {
    calls = [];
    initAnswer = true;
    locales = ['en_GB:English (UK)', 'en_US:English (US)', 'vi_VN:Vietnamese'];
    listenReplies = [];
    listenGate = null;
    cancelGate = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return initAnswer;
        case 'locales':
          return locales;
        case 'cancel':
          await cancelGate?.future;
          return null;
        case 'listen':
          await listenGate?.future;
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

  group('after stop (fix round 1)', () {
    test('stop with no partial: doneNoResult comes first, the real final arrives later and is delivered', () async {
      final r = make();
      await r.init();
      final got = <String>[];
      await r.start(onResult: (t, f) => got.add(fmt(t, f)));
      await r.stop();
      await status('notListening');
      await status('doneNoResult');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(got, isEmpty, reason: 'must keep waiting for the final result after stop');
      await hear(['five'], isFinal: true);
      expect(got, ['five [final]']);
    });

    test('a language error while the stop is still pending does not listen again (empty final)', () async {
      // The plugin drops errors that arrive after stop() reached it, so the
      // interesting case is the stop that is still waiting for the listen call.
      listenGate = Completer<void>();
      final r = make();
      await r.init();
      final got = <String>[];
      final started = r.start(onResult: (t, f) => got.add(fmt(t, f)));
      await Future<void>.delayed(Duration.zero);
      await r.stop();
      await error('error_language_unavailable');
      listenGate!.complete();
      await started;
      expect(got, [' [final]']);
      expect(listens(), hasLength(1));
    });

    test('released while listen throws on-device: no online retry, empty final', () async {
      listenGate = Completer<void>();
      listenReplies = [PlatformException(code: 'listenFailed')];
      final r = make();
      await r.init();
      final got = <String>[];
      final started = r.start(onResult: (t, f) => got.add(fmt(t, f)));
      await Future<void>.delayed(Duration.zero);
      await r.stop();
      listenGate!.complete();
      await started;
      expect(listens(), hasLength(1));
      expect(got, [' [final]']);
    });

    test('stop landing during the cancel at the top of start still stops the new listen', () async {
      cancelGate = Completer<void>();
      final r = make();
      await r.init();
      final got = <String>[];
      final started = r.start(onResult: (t, f) => got.add(fmt(t, f)));
      await Future<void>.delayed(Duration.zero);
      final stopped = r.stop();
      cancelGate!.complete();
      await started;
      await stopped;
      final methods = calls.map((c) => c.method).toList();
      expect(methods.lastIndexOf('stop'), greaterThan(methods.lastIndexOf('listen')), reason: 'stop must come after listen: $methods');
      await hear(['red'], isFinal: true);
      expect(got, ['red [final]']);
    });

    test('stop while the listen call is pending is applied once the listen has started', () async {
      listenGate = Completer<void>();
      final r = make();
      await r.init();
      final started = r.start(onResult: (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await r.stop();
      expect(calls.map((c) => c.method), isNot(contains('stop')));
      listenGate!.complete();
      await started;
      final methods = calls.map((c) => c.method).toList();
      expect(methods.last, 'stop');
    });

    test('cancel during the cancel at the top of start: no listen is started', () async {
      cancelGate = Completer<void>();
      final r = make();
      await r.init();
      final started = r.start(onResult: (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final cancelled = r.cancel();
      cancelGate!.complete();
      await started;
      await cancelled;
      expect(listens(), isEmpty);
    });
  });

  test('init reports unavailable after a later permission error', () async {
    final r = make();
    expect(await r.init(), isTrue);
    await r.start(onResult: (_, _) {});
    await error('error_permission');
    expect(r.available, isFalse);
    expect(await r.init(), isFalse);
  });

  test('on-device failure is remembered: the next session goes straight online', () async {
    final r = make();
    await r.init();
    await r.start(onResult: (_, _) {});
    await error('error_language_unavailable');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await hear(['five'], isFinal: true);
    await r.start(onResult: (_, _) {});
    final l = listens();
    expect(l, hasLength(3));
    expect((l[2].arguments as Map)['onDevice'], isFalse);
  });

  test('a thrown on-device listen is remembered too', () async {
    listenReplies = [PlatformException(code: 'listenFailed')];
    final r = make();
    await r.init();
    await r.start(onResult: (_, _) {});
    await r.start(onResult: (_, _) {});
    final l = listens();
    expect(l, hasLength(3));
    expect((l[2].arguments as Map)['onDevice'], isFalse);
  });

  test('done without a final and without stop (plugin timeout) still waits, then ends empty via the error', () async {
    final r = make();
    await r.init();
    await r.start(onResult: (_, _) {});
    await error('error_language_unavailable'); // go online
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final got = <String>[];
    await r.start(onResult: (t, f) => got.add(fmt(t, f)));
    await status('doneNoResult');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(got, isEmpty, reason: 'an online session cannot be sure nothing more follows');
    await hear(['blue'], isFinal: true);
    expect(got, ['blue [final]']);
  });

  test('initialize turns Bluetooth off (no BLUETOOTH_CONNECT permission needed)', () async {
    final r = make();
    await r.init();
    final init = calls.firstWhere((c) => c.method == 'initialize');
    expect(init.arguments.toString(), contains('noBluetooth'));
  });

  group('after stop', () {
    SpeechToTextRecognizer fast() => SpeechToTextRecognizer(
      speech: SpeechToText.withMethodChannel(),
      graceNoPartial: const Duration(milliseconds: 150),
      graceWithPartial: const Duration(milliseconds: 1500),
    );

    test('no partial heard: the short grace ends the session with an empty final', () async {
      final r = fast();
      await r.init();
      final got = <String>[];
      await r.start(onResult: (t, f) => got.add(fmt(t, f)));
      await r.stop();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(got, [' [final]']);
    });

    test('a partial was heard: the long grace is kept', () async {
      final r = fast();
      await r.init();
      final got = <String>[];
      await r.start(onResult: (t, f) => got.add(fmt(t, f)));
      await hear(['hel'], isFinal: false);
      await r.stop();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(got, ['hel']);
    });
  });

  group('on-device sessions that produce nothing', () {
    test('two in a row make later sessions go online', () async {
      final r = make();
      await r.init();
      for (var i = 0; i < 2; i++) {
        await r.start(onResult: (_, _) {});
        await error('error_no_match');
      }
      await r.start(onResult: (_, _) {});
      final l = listens();
      expect(l, hasLength(3));
      expect((l[1].arguments as Map)['onDevice'], isTrue);
      expect((l[2].arguments as Map)['onDevice'], isFalse);
    });

    test('a session with a partial result resets the count', () async {
      final r = make();
      await r.init();
      await r.start(onResult: (_, _) {});
      await error('error_no_match');
      await r.start(onResult: (_, _) {});
      await hear(['five'], isFinal: false);
      await hear(['five'], isFinal: true);
      await r.start(onResult: (_, _) {});
      await error('error_no_match');
      await r.start(onResult: (_, _) {});
      expect(listens().map((c) => (c.arguments as Map)['onDevice']), everyElement(isTrue));
    });
  });
}
