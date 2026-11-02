import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';

void main() {
  final now = DateTime(2026, 11, 2, 9);

  test('firstTry raises mastery and counts correct', () {
    final s = const ItemStat(key: 'k', mastery: 1).apply(AnswerOutcome.firstTry, now);
    expect([s.mastery, s.correct, s.wrong], [2, 1, 0]);
    expect(s.lastSeen, now);
    expect(s.key, 'k');
  });

  test('mastery is capped at 4', () {
    expect(const ItemStat(key: 'k', mastery: 4).apply(AnswerOutcome.firstTry, now).mastery, 4);
  });

  test('retry keeps mastery and counts wrong', () {
    final s = const ItemStat(key: 'k', mastery: 2).apply(AnswerOutcome.retry, now);
    expect([s.mastery, s.correct, s.wrong], [2, 0, 1]);
  });

  test('hinted lowers mastery but not below 0', () {
    expect(const ItemStat(key: 'k', mastery: 2).apply(AnswerOutcome.hinted, now).mastery, 1);
    expect(const ItemStat(key: 'k').apply(AnswerOutcome.hinted, now).mastery, 0);
  });
}
