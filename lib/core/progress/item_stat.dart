import 'dart:math';

enum AnswerOutcome { firstTry, retry, hinted }

class ItemStat {
  const ItemStat({required this.key, this.mastery = 0, this.correct = 0, this.wrong = 0, this.lastSeen});

  final String key;
  final int mastery;
  final int correct;
  final int wrong;
  final DateTime? lastSeen;

  static const maxMastery = 4;

  ItemStat apply(AnswerOutcome outcome, DateTime now) {
    final delta = switch (outcome) {
      AnswerOutcome.firstTry => 1,
      AnswerOutcome.retry => 0,
      AnswerOutcome.hinted => -1,
    };
    final first = outcome == AnswerOutcome.firstTry;
    return ItemStat(
      key: key,
      mastery: max(0, min(maxMastery, mastery + delta)),
      correct: correct + (first ? 1 : 0),
      wrong: wrong + (first ? 0 : 1),
      lastSeen: now,
    );
  }
}
