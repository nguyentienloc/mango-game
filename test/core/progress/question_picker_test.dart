import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';

void main() {
  final letters = [for (final c in 'ABCDEFGHIJ'.split('')) 'k:$c'];
  Map<String, ItemStat> seenAll(int mastery) => {for (final k in letters) k: ItemStat(key: k, mastery: mastery)};

  test('returns the requested number of keys from the candidates', () {
    final picked = QuestionPicker(Random(1)).pick(candidates: letters, stats: seenAll(1), count: 8);
    expect(picked, hasLength(8));
    expect(picked.every(letters.contains), isTrue);
  });

  test('never repeats the same key twice in a row', () {
    for (var seed = 0; seed < 50; seed++) {
      final picked = QuestionPicker(Random(seed)).pick(candidates: letters, stats: seenAll(2), count: 8);
      for (var i = 1; i < picked.length; i++) {
        expect(picked[i], isNot(picked[i - 1]));
      }
    }
  });

  test('introduces at most maxNew unseen keys per round', () {
    for (var seed = 0; seed < 50; seed++) {
      final picked = QuestionPicker(Random(seed)).pick(candidates: letters, stats: const {}, count: 8);
      expect(picked.toSet().length, lessThanOrEqualTo(2));
    }
  });

  test('mixes seen keys with at most two new ones', () {
    final stats = {for (final k in letters.take(5)) k: ItemStat(key: k, mastery: 1)};
    final picked = QuestionPicker(Random(3)).pick(candidates: letters, stats: stats, count: 8);
    final fresh = picked.where((k) => !stats.containsKey(k)).toSet();
    expect(fresh.length, lessThanOrEqualTo(2));
  });

  test('prefers keys with low mastery', () {
    final stats = {
      'a': const ItemStat(key: 'a', mastery: 0),
      'b': const ItemStat(key: 'b', mastery: 4),
      'c': const ItemStat(key: 'c', mastery: 4),
    };
    final picked = QuestionPicker(Random(7)).pick(candidates: ['a', 'b', 'c'], stats: stats, count: 3000);
    final a = picked.where((k) => k == 'a').length;
    final b = picked.where((k) => k == 'b').length;
    expect(a, greaterThan(b * 1.4));
  });

  test('a single candidate is repeated', () {
    expect(QuestionPicker(Random(1)).pick(candidates: ['x'], stats: const {}, count: 3), ['x', 'x', 'x']);
  });

  test('no candidates gives an empty list', () {
    expect(QuestionPicker(Random(1)).pick(candidates: const [], stats: const {}, count: 3), isEmpty);
  });
}
