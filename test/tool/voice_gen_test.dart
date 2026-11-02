import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/voice_gen.dart';

void main() {
  group('voiceFor', () {
    test('picks the voice by language', () {
      expect(voiceFor('vi'), 'hn_female_ngochuyen_full_48k-fhg');
      expect(voiceFor('en'), 'af_heart');
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

  group('index config', () {
    test('indexMeta lists provider, voices and speed', () {
      expect(indexMeta(), {
        'provider': 'vbee',
        'voices': {'vi': voiceFor('vi'), 'en': voiceFor('en')},
        'speed': 0.9,
      });
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
      expect(
        classifyVbeeError(401, 'UNAUTHORIZED', 'bad token'),
        VbeeErrorAction.fail,
      );
    });
  });
}
