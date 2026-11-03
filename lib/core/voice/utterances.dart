import '../content/models.dart';
import '../content/vocab.dart';
import '../profile/names.dart';
import 'utterance.dart';

enum UtteranceKind { fixed, vocab, trace, letters, numbers }

class PlannedUtterance {
  const PlannedUtterance(this.utterance, this.kind);

  final Utterance utterance;
  final UtteranceKind kind;
}

const vocabPhraseIds = ['vocab_prompt', 'vocab_correct', 'vocab_hint'];
const tracePhraseIds = ['trace_prompt'];
/// Spoken for every snowflake total 0..[maxSpokenCount]; bigger totals fall back
/// to device TTS for the number part only.
const numberPhraseIds = ['snowflake_count'];
const maxSpokenCount = 999;
const letterPhraseIds = ['find_letter_prompt', 'find_letter_small_prompt', 'letter_example'];

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
        numberPhraseIds.contains(id)) {
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
  for (final l in content.lettersEn) {
    add('find_letter_prompt', {'letter': l.char}, UtteranceKind.letters);
    add('find_letter_prompt', {'letter': l.lower}, UtteranceKind.letters);
    add('find_letter_small_prompt', {'letter': l.lower}, UtteranceKind.letters);
  }
  for (var n = 0; n <= maxSpokenCount; n++) {
    add('snowflake_count', {'count': '$n'}, UtteranceKind.numbers);
  }
  return out;
}
