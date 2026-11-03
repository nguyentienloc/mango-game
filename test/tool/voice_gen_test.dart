import 'package:flutter_test/flutter_test.dart';

import 'package:xoai_castle/core/voice/utterance.dart';

import '../../tool/src/voice_gen.dart';

void main() {
  group('voiceFor', () {
    test('picks the voice by language', () {
      expect(voiceFor('vi'), isNotEmpty);
      expect(voiceFor('en'), isNotEmpty);
      expect(voiceFor('en'), isNot(voiceFor('vi')));
    });
    test('unknown language throws', () {
      expect(() => voiceFor('fr'), throwsArgumentError);
    });
  });

  group('partCacheKey', () {
    test('is stable and 40 hex chars', () {
      final k = partCacheKey('en', 'Lion!', 'v', 0.9);
      expect(k, partCacheKey('en', 'Lion!', 'v', 0.9));
      expect(k, matches(RegExp(r'^[0-9a-f]{40}$')));
    });
    test('changes with lang, text, voice or speed', () {
      final base = partCacheKey('en', 'Lion!', 'v', 0.9);
      expect(partCacheKey('vi', 'Lion!', 'v', 0.9), isNot(base));
      expect(partCacheKey('en', 'Lion', 'v', 0.9), isNot(base));
      expect(partCacheKey('en', 'Lion!', 'w', 0.9), isNot(base));
      expect(partCacheKey('en', 'Lion!', 'v', 1.0), isNot(base));
    });
  });

  group('part clips', () {
    test('partFileName is sha1(partKey) first 16 hex + .ogg', () {
      final n = partFileName('en|Lion!');
      expect(n, matches(RegExp(r'^[0-9a-f]{16}\.ogg$')));
      expect(n, partFileName('en|Lion!'));
      expect(partFileName('vi|Lion!'), isNot(n));
    });

    test('distinctParts de-duplicates parts across utterances by lang|text', () {
      const a = Utterance([UtterancePart('en', 'Lion!'), UtterancePart('vi', 'Sư tử!')]);
      const b = Utterance([UtterancePart('en', 'Lion!'), UtterancePart('vi', 'Con sư tử!')]);
      const c = Utterance([UtterancePart('vi', 'Lion!')]);
      final parts = distinctParts([a, b, c]);
      expect(parts.keys, ['en|Lion!', 'vi|Sư tử!', 'vi|Con sư tử!', 'vi|Lion!']);
      expect(parts['en|Lion!']!.lang, 'en');
    });
  });

  group('index config', () {
    test('indexMeta lists provider, voices, speed and granularity', () {
      expect(indexMeta(), {
        'provider': 'vbee',
        'voices': {'vi': voiceFor('vi'), 'en': voiceFor('en')},
        'speed': 0.9,
        'granularity': 'part',
      });
    });
    test('an index without granularity part (per-utterance clips) is stale', () {
      final old = {...indexMeta(), 'clips': <String, String>{}}..remove('granularity');
      expect(indexIsStale(old), isTrue);
      expect(indexIsStale({...old, 'granularity': 'utterance'}), isTrue);
    });
    test('matching index is not stale', () {
      expect(
        indexIsStale({...indexMeta(), 'clips': <String, String>{}}),
        isFalse,
      );
    });
    test('old Gemini index is stale', () {
      expect(
        indexIsStale({
          'voice': 'Leda',
          'model': 'gemini',
          'clips': <String, String>{},
        }),
        isTrue,
      );
    });
    test('different voice or speed is stale', () {
      final m = indexMeta();
      expect(indexIsStale({...m, 'speed': 1.0}), isTrue);
      expect(
        indexIsStale({
          ...m,
          'voices': {'vi': 'x', 'en': voiceFor('en')},
        }),
        isTrue,
      );
      expect(indexIsStale({...m, 'provider': 'other'}), isTrue);
    });
  });

  group('classifyVbeeError', () {
    test('429 is retry', () {
      expect(
        classifyVbeeError(429, 'TTS_CCR_MAX_LIMIT_REACHED', 'too many'),
        VbeeErrorAction.retry,
      );
      expect(classifyVbeeError(429, null, null), VbeeErrorAction.retry);
    });
    test('credit or package BAD_REQUEST stops the run', () {
      expect(
        classifyVbeeError(400, 'BAD_REQUEST', 'Not enough credit'),
        VbeeErrorAction.stopRun,
      );
      expect(
        classifyVbeeError(400, 'BAD_REQUEST', 'Your PACKAGE has expired'),
        VbeeErrorAction.stopRun,
      );
    });
    test('other errors fail the part', () {
      expect(
        classifyVbeeError(400, 'BAD_REQUEST', 'invalid voiceCode'),
        VbeeErrorAction.fail,
      );
      expect(classifyVbeeError(500, null, 'oops'), VbeeErrorAction.fail);
    });
  });

  group('classifyVbeeError auth', () {
    test('401 and 403 stop the run', () {
      expect(
        classifyVbeeError(401, 'UNAUTHORIZED', 'bad token'),
        VbeeErrorAction.stopRun,
      );
      expect(classifyVbeeError(403, null, null), VbeeErrorAction.stopRun);
    });
  });

  group('formatPartFailure', () {
    test('names lang, voice and text', () {
      expect(
        formatPartFailure('en', 'en-GB-Standard-N', 'Lion!', 'Vbee HTTP 400'),
        '[en en-GB-Standard-N "Lion!"] Vbee HTTP 400',
      );
    });
    test('shortens long text', () {
      final out = formatPartFailure('vi', 'v', 'a' * 100, 'x');
      expect(out.length, lessThan(100));
      expect(out, contains('…'));
    });
    test('keeps newlines out of the line', () {
      expect(formatPartFailure('vi', 'v', 'a\nb', 'x'), isNot(contains('\n')));
    });
  });

  group('VoiceCircuitBreaker', () {
    test('trips after N failures in a row for the same voice', () {
      final b = VoiceCircuitBreaker(threshold: 5);
      for (var i = 0; i < 4; i++) {
        expect(b.recordFailure('a'), isFalse);
      }
      expect(b.recordFailure('a'), isTrue);
    });
    test('a success resets the streak', () {
      final b = VoiceCircuitBreaker(threshold: 3);
      b.recordFailure('a');
      b.recordFailure('a');
      b.recordSuccess('a');
      expect(b.recordFailure('a'), isFalse);
    });
    test('voices are counted separately', () {
      final b = VoiceCircuitBreaker(threshold: 2);
      b.recordFailure('a');
      expect(b.recordFailure('b'), isFalse);
      expect(b.recordFailure('a'), isTrue);
    });
    test('tally counts all failures per voice', () {
      final b = VoiceCircuitBreaker(threshold: 5);
      b.recordFailure('a');
      b.recordSuccess('a');
      b.recordFailure('a');
      b.recordFailure('b');
      expect(b.tally, {'a': 2, 'b': 1});
    });
    test('default threshold is 5', () {
      expect(VoiceCircuitBreaker().threshold, 5);
    });
  });

  group('redactSecrets', () {
    test('masks every secret and ignores empty ones', () {
      expect(
        redactSecrets('tok123 and app9 and tok123', ['tok123', 'app9', '']),
        '*** and *** and ***',
      );
    });
  });

  group('parseEnvLine', () {
    test('plain, export, quoted and spaced forms', () {
      expect(
        parseEnvLine('A=1'),
        isA<MapEntry<String, String>>().having(
          (e) => '${e.key}=${e.value}',
          'pair',
          'A=1',
        ),
      );
      expect(
        parseEnvLine('export A=1'),
        isA<MapEntry<String, String>>().having(
          (e) => '${e.key}=${e.value}',
          'pair',
          'A=1',
        ),
      );
      expect(
        parseEnvLine('  export   A = "x y" '),
        isA<MapEntry<String, String>>().having(
          (e) => '${e.key}=${e.value}',
          'pair',
          'A=x y',
        ),
      );
      expect(
        parseEnvLine("A='z'"),
        isA<MapEntry<String, String>>().having(
          (e) => '${e.key}=${e.value}',
          'pair',
          'A=z',
        ),
      );
    });
    test('comments and junk give null', () {
      expect(parseEnvLine('# A=1'), isNull);
      expect(parseEnvLine(''), isNull);
      expect(parseEnvLine('nonsense'), isNull);
    });
  });

  group('parseGenArgs', () {
    test('defaults', () {
      final a = parseGenArgs([]);
      expect(a.limit, isNull);
      expect(a.only, isNull);
      expect(a.prune, isFalse);
      expect(a.dryRun, isFalse);
      expect(a.allowApi, isFalse, reason: 'never calls Vbee unless asked');
    });
    test('parses all options', () {
      final a = parseGenArgs([
        '--limit',
        '2',
        '--only',
        'Lion',
        '--prune',
        '--dry-run',
        '--allow-api',
      ]);
      expect(a.limit, 2);
      expect(a.only, 'Lion');
      expect(a.prune, isTrue);
      expect(a.dryRun, isTrue);
      expect(a.allowApi, isTrue);
    });
    test('rejects bad values', () {
      expect(() => parseGenArgs(['--limit']), throwsFormatException);
      expect(() => parseGenArgs(['--limit', 'x']), throwsFormatException);
      expect(() => parseGenArgs(['--limit', '-1']), throwsFormatException);
      expect(() => parseGenArgs(['--only']), throwsFormatException);
      expect(() => parseGenArgs(['--only', '--prune']), throwsFormatException);
      expect(() => parseGenArgs(['--bogus']), throwsFormatException);
    });
  });

  group('batching', () {
    UtterancePart vi(String t) => UtterancePart('vi', t);
    UtterancePart en(String t) => UtterancePart('en', t);

    test('--batch parses', () {
      expect(parseGenArgs(['--batch']).batch, isTrue);
      expect(parseGenArgs([]).batch, isFalse);
    });

    test('short parts of one language are grouped by 50, in order', () {
      final parts = [for (var i = 0; i < 120; i++) vi('$i')];
      final r = planBatches(parts);
      expect(r.batches.map((b) => b.length), [50, 50, 20]);
      expect(r.batches.expand((b) => b).map((p) => p.text), [for (var i = 0; i < 120; i++) '$i']);
      expect(r.single, isEmpty);
    });

    test('languages are never mixed in one batch', () {
      final r = planBatches([vi('1'), en('One!'), vi('2'), en('Two!')]);
      expect(r.batches, hasLength(2));
      expect(r.batches.map((b) => b.map((p) => p.lang).toSet().single).toSet(), {'vi', 'en'});
    });

    test('long parts stay single unless forced; a lone short part stays single', () {
      final long = vi('bông tuyết rồi, giỏi quá nè!');
      final r = planBatches([long, vi('7')]);
      expect(r.batches, isEmpty);
      expect(r.single, [long, vi('7')].map((p) => p.key));
      final forced = planBatches([long, vi('7')], forceAll: true);
      expect(forced.batches, hasLength(1));
      expect(forced.batches.single, hasLength(2));
    });

    test('text of 12 characters is short, 13 is not', () {
      expect(planBatches([vi('a' * 12), vi('b' * 12)]).batches, hasLength(1));
      expect(planBatches([vi('a' * 13), vi('b' * 13)]).batches, isEmpty);
    });

    test('batchText puts each part on its own line, closed by a full stop', () {
      expect(batchText([vi('1'), vi('22'), vi('333')]), '1.\n22.\n333.');
      expect(batchText([vi('Lion!'), vi('a,')]), 'Lion!\na,');
    });

    test('the request pause settings', () {
      expect(batchPause['paragraphBreak'], closeTo(1.2, 0.01));
      expect(batchPause['sentenceBreak'], closeTo(1.0, 0.01));
    });
  });

  group('silence parsing', () {
    const stderr = '''
  Duration: 00:00:09.50, start: 0.000000, bitrate: 128 kb/s
[silencedetect @ 0x1] silence_start: 0
[silencedetect @ 0x1] silence_end: 0.35 | silence_duration: 0.35
[silencedetect @ 0x1] silence_start: 1.2
[silencedetect @ 0x1] silence_end: 2.5 | silence_duration: 1.3
[silencedetect @ 0x1] silence_start: 3.4
[silencedetect @ 0x1] silence_end: 4.7 | silence_duration: 1.3
[silencedetect @ 0x1] silence_start: 5.6
''';

    test('parses silences and total duration', () {
      final s = parseSilences(stderr);
      expect(s, hasLength(4));
      expect(s.first.start, 0);
      expect(s.first.end, 0.35);
      expect(s.last.start, 5.6);
      expect(s.last.end, isNull);
      expect(parseDuration(stderr), closeTo(9.5, 0.001));
    });

    test('speech segments are the gaps between silences', () {
      final seg = speechSegments(parseSilences(stderr), 9.5);
      expect(seg.map((e) => (e.start, e.end)), [(0.35, 1.2), (2.5, 3.4), (4.7, 5.6)]);
    });

    test('no silence at all is one segment; a silent tail ends the last segment', () {
      expect(speechSegments(const [], 3.0).map((e) => (e.start, e.end)), [(0.0, 3.0)]);
      final seg = speechSegments(parseSilences('[silencedetect @ 1] silence_start: 2'), 4.0);
      expect(seg.map((e) => (e.start, e.end)), [(0.0, 2.0)]);
    });

    test('a few milliseconds of noise at an edge is not an item', () {
      final seg = speechSegments(parseSilences('silence_start: 0.01\nsilence_end: 1.0\nsilence_start: 2.0\nsilence_end: 9.995'), 10.0);
      expect(seg.map((e) => (e.start, e.end)), [(1.0, 2.0)]);
    });

    test('garbage gives nothing', () {
      expect(parseSilences('hello'), isEmpty);
      expect(parseDuration('hello'), isNull);
    });
  });

  group('split decision', () {
    test('splits only when the segment count equals the item count', () {
      final seg = [for (var i = 0; i < 3; i++) Segment(i * 2.0, i * 2.0 + 1)];
      expect(canSplit(3, seg), isTrue);
      expect(canSplit(4, seg), isFalse);
      expect(canSplit(2, seg), isFalse);
      expect(canSplit(0, const []), isFalse);
    });

    test('cut window is padded by 80 ms and clamped to the file', () {
      final w = cutWindow(const Segment(0.05, 1.0), 1.02);
      expect(w.start, 0.0);
      expect(w.end, closeTo(1.02, 1e-9));
      final m = cutWindow(const Segment(2.0, 3.0), 10);
      expect(m.start, closeTo(1.92, 1e-9));
      expect(m.end, closeTo(3.08, 1e-9));
    });

    test('cache key of a batch depends on voice, speed and the exact texts', () {
      final a = batchCacheKey('vi', ['1', '2'], 'v', 0.9);
      expect(a, batchCacheKey('vi', ['1', '2'], 'v', 0.9));
      expect(a, isNot(batchCacheKey('vi', ['2', '1'], 'v', 0.9)));
      expect(a, isNot(batchCacheKey('vi', ['1', '2'], 'w', 0.9)));
    });
  });
}
