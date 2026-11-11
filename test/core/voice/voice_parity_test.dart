import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/vocab.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/clip_library.dart';
import 'package:xoai_castle/core/voice/utterances.dart';
import 'package:xoai_castle/core/voice/voice_service.dart';
import 'package:xoai_castle/features/games/compare/compare_logic.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/games/trace/number_trace.dart';
import 'package:xoai_castle/features/games/trace/tone_trace.dart';

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
      if (vocabPhraseIds.contains(id) || letterPhraseIds.contains(id) || balloonPhraseIds.contains(id) || tracePhraseIds.contains(id) ||
          viLetterPhraseIds.contains(id) || talkPhraseIds.contains(id) || traceNumberPhraseIds.contains(id) ||
          viTonePhraseIds.contains(id) || comparePhraseIds.contains(id)) {
        continue;
      }
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
      // Exactly as the balloon screen says them: prompt/correct with {letter};
      // a wrong tap says the tapped letter, then (not awaited) asks for the target.
      await check('balloon_prompt', 'balloon_prompt', {'letter': l.char});
      await check('balloon_correct', 'balloon_correct', {'letter': l.char});
      final other = content.lettersEn[(content.lettersEn.indexOf(l) + 7) % content.lettersEn.length];
      await check('balloon_wrong_this', 'balloon_wrong_this', {'tapped': l.char});
      await check('balloon_wrong_find', 'balloon_wrong_find', {'letter': other.char});
      await check('letter_example', 'letter_example', {'letter': l.char, 'word': l.exampleWord});
    }
    // Vietnamese letters, with the vars the games build from their specs.
    const bv = LetterGameSpec.balloonVi;
    const tv = LetterGameSpec.traceVi;
    for (final l in content.lettersVi) {
      final other = content.lettersVi[(content.lettersVi.indexOf(l) + 7) % content.lettersVi.length];
      await check(bv.promptId, bv.promptId, bv.vars(l));
      await check(bv.correctId, bv.correctId, bv.vars(l));
      await check(bv.wrongThisId, bv.wrongThisId, bv.vars(other, tapped: l));
      await check(bv.wrongFindId, bv.wrongFindId, bv.vars(other));
      await check(tv.promptId, tv.promptId, tv.vars(l));
      await check(tv.doneId, tv.doneId, tv.vars(l));
    }

    // Number tracing 0..99, with the items and vars the numbers game builds from its spec.
    // Three parts each with gaps in between make say() slow, so like the counts they are
    // checked by key, and one number of each kind goes through say().
    const tn = LetterGameSpec.traceNumbers;
    final numbers = buildNumberItems(content.digits);
    expect(numbers, hasLength(100));
    for (final item in numbers) {
      for (final id in [tn.promptId, tn.doneId]) {
        for (final part in voice.utterance(id, vars: tn.vars(item)).parts) {
          if (clips.assetFor(part) == null) missing.add(part.key);
        }
      }
    }
    for (final n in [7, 23]) {
      await check(tn.promptId, tn.promptId, tn.vars(numbers[n]));
      await check(tn.doneId, tn.doneId, tn.vars(numbers[n]));
    }
    await check(tn.levelUpId, tn.levelUpId);

    // Tone marks: every tone on every base, with the items a round places and the spec's vars.
    const tt = LetterGameSpec.traceTones;
    final toneItems = tt.letters(content);
    expect(toneItems, hasLength(5));
    for (final item in toneItems) {
      for (final placed in tt.prepareRound!([for (var i = 0; i < toneBases.length; i++) item])) {
        await check(tt.promptId, tt.promptId, tt.vars(placed));
        await check(tt.doneId, tt.doneId, tt.vars(placed));
      }
    }

    // Compare: every question the game can build, with the question's own phrase ids and vars.
    // There are 10 000 number pairs, so they are checked by key; a few go through say().
    final compareQs = [
      for (var a = 1; a <= 10; a++)
        for (var b = 1; b <= 10; b++)
          if (a != b)
            for (final more in [true, false]) CompareQuestion.picture(left: a, right: b, askMore: more, emoji: '🍎'),
      for (var a = 0; a <= 99; a++)
        for (var b = 0; b <= 99; b++) CompareQuestion.numbers(level: 4, left: a, right: b),
    ];
    for (final q in compareQs) {
      for (final (id, vars) in [(q.promptId, q.promptVars), (q.rightId, q.rightVars)]) {
        for (final part in voice.utterance(id, vars: vars).parts) {
          if (clips.assetFor(part) == null) missing.add(part.key);
        }
      }
    }
    for (final q in const [
      CompareQuestion.picture(left: 7, right: 3, askMore: true, emoji: '🍎'),
      CompareQuestion.picture(left: 7, right: 3, askMore: false, emoji: '🍎'),
      CompareQuestion.numbers(level: 2, left: 3, right: 5),
      CompareQuestion.numbers(level: 3, left: 18, right: 6),
      CompareQuestion.numbers(level: 4, left: 47, right: 47),
    ]) {
      await check(q.promptId, q.promptId, q.promptVars);
      await check(q.rightId, q.rightId, q.rightVars);
    }

    // Talk: exactly as the talk screen says them, with the item's text rendered first.
    final names = Names(en: defaults.nameEn, vi: defaults.nameVi);
    for (final item in content.conversation) {
      await check('talk_question', 'talk_question', talkQuestionVars(item, names));
      await check('talk_say_after', 'talk_say_after', talkModelVars(item, names));
    }
    expect(content.conversation, isNotEmpty);

    expect(missing, isEmpty, reason: 'Run: dart run tool/gen_voice.dart');
    expect(tts.spoken, isEmpty);
    expect(player.played, isNotEmpty);
  });
}
