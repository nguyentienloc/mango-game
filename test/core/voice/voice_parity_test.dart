import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/vocab.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/clip_library.dart';
import 'package:xoai_castle/core/voice/utterances.dart';
import 'package:xoai_castle/core/voice/voice_service.dart';
import 'package:xoai_castle/features/games/find_letter/find_letter_logic.dart';

import '../../support/fakes.dart';

/// The runtime (VoiceService) and the generator (enumerateUtterances) must build
/// the same keys: every call the screens make has to find its pre-generated clip.
/// Clips bake in the default names from profile_defaults.json.
void main() {
  test('every part of every utterance the screens ask for plays a pre-generated clip, never TTS', () async {
    final content = await ContentRepository(FileContentSource('content')).load();
    final defaults = content.profileDefaults;
    final clips = ClipLibrary.parse(File('content/audio/index.json').readAsStringSync());
    final tts = FakeTts();
    final player = FakeClipPlayer();
    final voice = VoiceService(
      tts: tts,
      phrases: content.phrases,
      names: Names(en: defaults.nameEn, vi: defaults.nameVi),
      clips: clips,
      player: player,
    );

    final missing = <String>[];
    var expected = 0;
    Future<void> check(String label, String phraseId, [Map<String, String> vars = const {}]) async {
      final parts = voice.utterance(phraseId, vars: vars).parts.length;
      expected += parts;
      final spokenBefore = tts.spoken.length;
      await voice.say(phraseId, vars: vars);
      if (player.played.length != expected || tts.spoken.length != spokenBefore) {
        expected = player.played.length;
        missing.add(voice.utterance(phraseId, vars: vars).key);
      }
    }

    for (final id in content.phrases.keys) {
      if (vocabPhraseIds.contains(id) || letterPhraseIds.contains(id) || tracePhraseIds.contains(id)) continue;
      if (numberPhraseIds.contains(id)) continue;
      await check(id, id);
    }
    // Three say() calls per number are slow, so the 1000 counts are checked by
    // key; one real count goes through say().
    for (var n = 0; n <= maxSpokenCount; n++) {
      for (final part in voice.utterance('snowflake_count', vars: {'count': '$n'}).parts) {
        if (clips.assetFor(part) == null) missing.add(part.key);
      }
    }
    await check('snowflake_count', 'snowflake_count', {'count': '125'});
    for (final w in content.vocab) {
      for (final id in vocabPhraseIds) {
        await check(id, id, vocabVars(w));
      }
    }
    for (final l in content.lettersEn) {
      await check('trace_prompt', 'trace_prompt', {'letter': l.char});
      for (final mode in FindLetterMode.values) {
        final q = FindLetterQuestion(mode: mode, item: l, options: const []);
        await check(q.promptPhraseId, q.promptPhraseId, q.promptVars);
      }
      await check('letter_example', 'letter_example', {'letter': l.char, 'word': l.exampleWord});
    }

    expect(missing, isEmpty, reason: 'Run: dart run tool/gen_voice.dart');
    expect(tts.spoken, isEmpty);
    expect(player.played, isNotEmpty);
  });
}
