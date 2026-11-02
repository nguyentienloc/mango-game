import 'dart:math';

import '../../../core/content/models.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../pick_session.dart';

export '../pick_session.dart' show PickSession, TapResult;

enum FindLetterMode { upper, lower, match }

const kUnlockCount = 20;
const kUnlockMastery = 2;

String findLetterKey(FindLetterMode mode, LetterItem item) => switch (mode) {
      FindLetterMode.upper => 'letter_en_upper:${item.char}',
      FindLetterMode.lower => 'letter_en_lower:${item.lower}',
      FindLetterMode.match => 'letter_en_match:${item.char}',
    };

FindLetterMode highestUnlockedMode(List<LetterItem> letters, Map<String, ItemStat> stats) {
  int mastered(FindLetterMode m) =>
      letters.where((l) => (stats[findLetterKey(m, l)]?.mastery ?? 0) >= kUnlockMastery).length;
  if (mastered(FindLetterMode.upper) < kUnlockCount) return FindLetterMode.upper;
  if (mastered(FindLetterMode.lower) < kUnlockCount) return FindLetterMode.lower;
  return FindLetterMode.match;
}

class FindLetterQuestion implements PickQuestion {
  const FindLetterQuestion({required this.mode, required this.item, required this.options});

  final FindLetterMode mode;
  final LetterItem item;

  /// Letters written on the falling snowflakes, answer included.
  final List<String> options;

  @override
  String get key => findLetterKey(mode, item);
  @override
  String get answer => mode == FindLetterMode.upper ? item.char : item.lower;

  /// Big capital shown on screen in match mode.
  String? get shownLetter => mode == FindLetterMode.match ? item.char : null;

  String get promptPhraseId => mode == FindLetterMode.match ? 'find_letter_small_prompt' : 'find_letter_prompt';
  Map<String, String> get promptVars => {'letter': answer};
}

List<FindLetterQuestion> buildFindLetterRound({
  required List<LetterItem> letters,
  required Map<String, ItemStat> stats,
  required QuestionPicker picker,
  required Random random,
  int count = 8,
  int reviewCount = 2,
}) {
  final mode = highestUnlockedMode(letters, stats);
  final review = mode == FindLetterMode.upper ? 0 : reviewCount;
  final previous = mode == FindLetterMode.match ? FindLetterMode.lower : FindLetterMode.upper;

  List<FindLetterQuestion> make(FindLetterMode m, int n) {
    final byKey = {for (final l in letters) findLetterKey(m, l): l};
    final keys = picker.pick(candidates: byKey.keys.toList(), stats: stats, count: n);
    final optionCount = m == FindLetterMode.match ? 4 : 3;
    return [for (final k in keys) _question(m, byKey[k]!, letters, optionCount, random)];
  }

  final questions = make(mode, count - review);
  for (final q in make(previous, review)) {
    questions.insert(random.nextInt(questions.length + 1), q);
  }
  return questions;
}

FindLetterQuestion _question(
  FindLetterMode mode,
  LetterItem item,
  List<LetterItem> letters,
  int optionCount,
  Random random,
) {
  String show(LetterItem l) => mode == FindLetterMode.upper ? l.char : l.lower;
  final others = letters.where((l) => l.char != item.char).toList()..shuffle(random);
  final options = [show(item), ...others.take(optionCount - 1).map(show)]..shuffle(random);
  return FindLetterQuestion(mode: mode, item: item, options: options);
}

typedef FindLetterSession = PickSession<FindLetterQuestion>;
