import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/pick_session.dart';
import 'package:xoai_castle/features/games/vocab/vocab_logic.dart';

final words = [
  for (final id in ['cat', 'dog', 'lion', 'duck', 'cow', 'pig', 'apple', 'banana', 'car', 'bus'])
    VocabItem(id: id, word: id, vi: 'vi $id', emoji: '⭐', topic: 't'),
];

List<VocabQuestion> round(Map<String, ItemStat> stats, [int seed = 1]) =>
    buildVocabRound(words: words, stats: stats, picker: QuestionPicker(Random(seed)), random: Random(seed));

void main() {
  test('a round has 8 questions with 4 distinct options including the answer', () {
    for (var seed = 0; seed < 20; seed++) {
      final qs = round(const {}, seed);
      expect(qs, hasLength(8));
      for (final q in qs) {
        expect(q.options, hasLength(4));
        expect(q.options.map((o) => o.id).toSet(), hasLength(4));
        expect(q.options.map((o) => o.id), contains(q.answer));
        expect(q.key, 'word:${q.item.id}');
      }
      for (var i = 1; i < qs.length; i++) {
        expect(qs[i].key, isNot(qs[i - 1].key));
      }
    }
  });

  test('a fresh player meets at most 3 new words per round', () {
    for (var seed = 0; seed < 20; seed++) {
      expect(round(const {}, seed).map((q) => q.item.id).toSet().length, lessThanOrEqualTo(3));
    }
  });

  test('known words are mixed in', () {
    final stats = {for (final w in words.take(6)) 'word:${w.id}': ItemStat(key: 'word:${w.id}', mastery: 1)};
    final ids = round(stats).map((q) => q.item.id).toSet();
    expect(ids.where((id) => !stats.containsKey('word:$id')).length, lessThanOrEqualTo(3));
    expect(ids.length, greaterThan(3));
  });

  test('the shared session scores taps on vocabulary questions', () {
    final s = PickSession(round(const {}));
    final wrong = s.current.options.firstWhere((o) => o.id != s.current.answer).id;
    expect(s.tap(wrong), TapResult.wrong);
    expect(s.tap(wrong), TapResult.wrong);
    expect(s.showHint, isTrue);
    expect(s.tap(s.current.answer), TapResult.correct);
    expect(s.outcomes, [AnswerOutcome.hinted]);
  });
}
