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
}
