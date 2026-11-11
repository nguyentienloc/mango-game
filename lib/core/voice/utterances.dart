import '../content/models.dart';
import '../content/vocab.dart';
import '../../features/games/compare/compare_logic.dart';
import '../../features/games/trace/tone_trace.dart';
import '../profile/names.dart';
import 'utterance.dart';

enum UtteranceKind { fixed, vocab, trace, balloon, numbers, viLetters, talk, traceNumbers, viTones, compare }

class PlannedUtterance {
  const PlannedUtterance(this.utterance, this.kind);

  final Utterance utterance;
  final UtteranceKind kind;
}

const vocabPhraseIds = ['vocab_prompt', 'vocab_correct', 'vocab_hint'];
const tracePhraseIds = ['trace_prompt'];
/// Number tracing: the number ({number}, e.g. `23`) said in Vietnamese then English, for 0..[maxTracedNumber].
const traceNumberPhraseIds = ['trace_num_prompt', 'trace_num_done'];
const maxTracedNumber = 99;
/// Spoken for every snowflake total 0..[maxSpokenCount]; bigger totals fall back
/// to device TTS for the number part only.
const numberPhraseIds = ['snowflake_count'];
const maxSpokenCount = 999;
const letterPhraseIds = ['letter_example'];
const balloonPhraseIds = ['balloon_prompt', 'balloon_correct', 'balloon_wrong_this', 'balloon_wrong_find'];
/// The Vietnamese letter games: each is a single `vi` part with the letter's spoken name inside.
const viLetterPhraseIds = [
  'vi_balloon_prompt',
  'vi_balloon_correct',
  'vi_balloon_wrong_this',
  'vi_balloon_wrong_find',
  'vi_trace_prompt',
  'vi_trace_done',
];

/// Tone-mark tracing, each a single `vi` part: the prompt names the tone ({tone}), the done line
/// also the vowel it was put on ({base}) and the two together ({combined}, e.g. `á`).
const viTonePhraseIds = ['vi_tone_prompt', 'vi_tone_done'];

/// Compare game phrases with numbers: {a} and {b} are each a part of their own (`vi|7`), whose clips
/// the snowflake counts already need. Level 1 says picture counts (1..10), levels 2-4 numbers 0..99.
const comparePictureIds = ['compare_right_more', 'compare_right_fewer'];
const compareNumberIds = ['compare_ask', 'compare_right_gt', 'compare_right_lt', 'compare_right_eq'];
const comparePhraseIds = [...comparePictureIds, ...compareNumberIds];

/// Talk-with-Elsa phrases that need an item: `talk_question` ({question}) and
/// `talk_say_after` ({model}). The two other talk phrases (`talk_again`,
/// `talk_hold_hint`) are plain fixed phrases.
const talkPhraseIds = ['talk_question', 'talk_say_after'];

/// Vars the talk screen passes for [item]. The item's own text may hold
/// `{name_en}`, which a var value would not get filled in, so it is rendered here.
Map<String, String> talkQuestionVars(ConversationItem item, Names names) => {'question': renderTemplate(item.question, names, const {})};
Map<String, String> talkModelVars(ConversationItem item, Names names) => {'model': renderTemplate(item.model, names, const {})};

/// Every utterance the app can say, with names and item variables filled in.
/// Used by tool/gen_voice.dart to pre-generate audio and by the voice coverage test.
List<PlannedUtterance> enumerateUtterances(ContentBundle content, Names names) {
  final out = <PlannedUtterance>[];
  final seen = <String>{};

  void add(String phraseId, Map<String, String> vars, UtteranceKind kind) {
    final phrase = content.phrases[phraseId];
    if (phrase == null) return;
    final u = buildUtterance(phrase, names, vars);
    if (seen.add(u.key)) out.add(PlannedUtterance(u, kind));
  }

  for (final id in content.phrases.keys) {
    if (vocabPhraseIds.contains(id) || letterPhraseIds.contains(id) || tracePhraseIds.contains(id) ||
        balloonPhraseIds.contains(id) || numberPhraseIds.contains(id) || viLetterPhraseIds.contains(id) ||
        talkPhraseIds.contains(id) || traceNumberPhraseIds.contains(id) || viTonePhraseIds.contains(id) ||
        comparePhraseIds.contains(id)) {
      continue;
    }
    add(id, const {}, UtteranceKind.fixed);
  }
  for (final w in content.vocab) {
    for (final id in vocabPhraseIds) {
      add(id, vocabVars(w), UtteranceKind.vocab);
    }
  }
  for (final l in content.lettersEn) {
    add('trace_prompt', {'letter': l.char}, UtteranceKind.trace);
    // Tracing reuses letter_example, so it is required rather than optional.
    add('letter_example', {'letter': l.char, 'word': l.exampleWord}, UtteranceKind.trace);
  }
  // Balloon: clips are per PART. The wrong-tap feedback is split in two phrases (the second one
  // is not awaited by the screen), each depending on one letter: {tapped} in _this and {letter}
  // in _find, so A..Z in each covers every pair.
  for (final l in content.lettersEn) {
    add('balloon_prompt', {'letter': l.char}, UtteranceKind.balloon);
    add('balloon_correct', {'letter': l.char}, UtteranceKind.balloon);
    add('balloon_wrong_this', {'tapped': l.char}, UtteranceKind.balloon);
    add('balloon_wrong_find', {'letter': l.char}, UtteranceKind.balloon);
  }
  // Vietnamese letters: every phrase x every letter. wrong_this carries the tapped letter's name;
  // the others the target's. Called with the same vars as LetterGameSpec.balloonVi / traceVi.
  for (final l in content.lettersVi) {
    final spoken = l.spoken ?? l.lower;
    for (final id in viLetterPhraseIds) {
      add(id, id == 'vi_balloon_wrong_this' ? {'tapped': spoken} : {'spoken': spoken}, UtteranceKind.viLetters);
    }
  }
  // Talk: every question and every model answer, as the talk screen says them.
  for (final item in content.conversation) {
    add('talk_question', talkQuestionVars(item, names), UtteranceKind.talk);
    add('talk_say_after', talkModelVars(item, names), UtteranceKind.talk);
  }
  // Number tracing: as LetterGameSpec.traceNumbers says them, {number} being the decimal number.
  for (var n = 0; n <= maxTracedNumber; n++) {
    for (final id in traceNumberPhraseIds) {
      add(id, {'number': '$n'}, UtteranceKind.traceNumbers);
    }
  }
  // Tone marks: a round puts its items on a, e, o, u, i by position, so any tone can land on
  // any base. The vars are LetterGameSpec.traceTones' (toneVars); the prompt only uses {tone}.
  for (final tone in content.tones) {
    add('vi_tone_prompt', toneVars(ToneTraceItem(tone)), UtteranceKind.viTones);
    for (final base in toneBases) {
      add('vi_tone_done', toneVars(ToneTraceItem(tone, base: base)), UtteranceKind.viTones);
    }
  }
  // Compare: clips are per PART and every part depends on at most one of {a} and {b}, so running
  // {a} over the whole range with {b} fixed, then {b} with {a} fixed, covers every part of every
  // pair the game can ask (all 100 x 100 combinations would only repeat the same parts).
  void compareRange(List<String> ids, int lo, int hi) {
    for (final id in ids) {
      for (var n = lo; n <= hi; n++) {
        add(id, {'a': '$n', 'b': '$lo'}, UtteranceKind.compare);
        add(id, {'a': '$lo', 'b': '$n'}, UtteranceKind.compare);
      }
    }
  }
  compareRange(comparePictureIds, 1, compareMaxNumber(1));
  compareRange(compareNumberIds, 0, compareMaxNumber(compareMaxLevel));
  for (var n = 0; n <= maxSpokenCount; n++) {
    add('snowflake_count', {'count': '$n'}, UtteranceKind.numbers);
  }
  return out;
}
