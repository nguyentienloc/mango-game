import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/features/games/compare/compare_logic.dart';
import 'package:xoai_castle/features/games/pick_session.dart';

import '../../support/fakes.dart';

void main() {
  group('level 1: pictures, more or fewer', () {
    test('ten questions, two different counts in 1..10, more or fewer, emojis rotating', () {
      var asksMore = 0;
      var asksFewer = 0;
      for (var seed = 0; seed < 50; seed++) {
        final qs = buildCompareRound(level: 1, random: Random(seed));
        expect(qs, hasLength(compareRoundLength));
        final start = compareEmojis.indexOf(qs.first.emoji);
        expect(start, isNonNegative);
        for (final (i, q) in qs.indexed) {
          expect(q.level, 1);
          expect(q.isPicture, isTrue);
          expect(q.left, inInclusiveRange(1, 10));
          expect(q.right, inInclusiveRange(1, 10));
          expect(q.left, isNot(q.right));
          expect(q.emoji, compareEmojis[(start + i) % compareEmojis.length]);
          q.askMore ? asksMore++ : asksFewer++;
        }
        // No question is asked twice in a round.
        expect(qs.map((q) => '${q.left}-${q.right}').toSet(), hasLength(compareRoundLength));
      }
      expect(asksMore, greaterThan(150));
      expect(asksFewer, greaterThan(150));
    });

    test('the answer is the side with more, or with fewer', () {
      const more = CompareQuestion.picture(left: 7, right: 3, askMore: true, emoji: '🍎');
      expect(more.answer, 'left');
      const fewer = CompareQuestion.picture(left: 7, right: 3, askMore: false, emoji: '🍎');
      expect(fewer.answer, 'right');
      const fewerLeft = CompareQuestion.picture(left: 2, right: 9, askMore: false, emoji: '🍎');
      expect(fewerLeft.answer, 'left');
    });

    test('Elsa asks "more?" or "fewer?" and names the picked side first when right', () {
      const more = CompareQuestion.picture(left: 7, right: 3, askMore: true, emoji: '🍎');
      expect(more.promptId, 'compare_more');
      expect(more.promptVars, isEmpty);
      expect(more.rightId, 'compare_right_more');
      expect(more.rightVars, {'a': '7', 'b': '3'});
      const fewer = CompareQuestion.picture(left: 7, right: 3, askMore: false, emoji: '🍎');
      expect(fewer.promptId, 'compare_fewer');
      expect(fewer.rightId, 'compare_right_fewer');
      expect(fewer.rightVars, {'a': '3', 'b': '7'});
    });
  });

  group('levels 2-4: numbers and > < =', () {
    test('numbers stay in the level range: 0..10, 0..20, 0..99', () {
      for (final (level, max) in [(2, 10), (3, 20), (4, 99)]) {
        expect(compareMaxNumber(level), max);
        final seen = <int>{};
        for (var seed = 0; seed < 50; seed++) {
          final qs = buildCompareRound(level: level, random: Random(seed));
          expect(qs, hasLength(compareRoundLength));
          for (final q in qs) {
            expect(q.level, level);
            expect(q.isPicture, isFalse);
            expect(q.left, inInclusiveRange(0, max));
            expect(q.right, inInclusiveRange(0, max));
            seen..add(q.left)..add(q.right);
          }
          expect(qs.map((q) => '${q.left}-${q.right}').toSet(), hasLength(compareRoundLength), reason: 'no repeats');
        }
        // The range is really used, not just a corner of it.
        expect(seen.reduce((a, b) => a > b ? a : b), greaterThan(max * 3 ~/ 4));
      }
    });

    test('about one question in five is two equal numbers', () {
      for (final level in [2, 3, 4]) {
        var equal = 0;
        var total = 0;
        for (var seed = 0; seed < 100; seed++) {
          final qs = buildCompareRound(level: level, random: Random(seed));
          final e = qs.where((q) => q.left == q.right).length;
          expect(e, inInclusiveRange(1, 3), reason: 'level $level seed $seed');
          equal += e;
          total += qs.length;
        }
        expect(equal / total, closeTo(0.2, 0.05), reason: 'level $level');
      }
    });

    test('both > and < come up, and equal questions are not always in the same place', () {
      for (final level in [2, 3, 4]) {
        final positions = <int>{};
        var gt = 0;
        var lt = 0;
        for (var seed = 0; seed < 40; seed++) {
          final qs = buildCompareRound(level: level, random: Random(seed));
          for (final (i, q) in qs.indexed) {
            if (q.sign == CompareSign.eq) positions.add(i);
            if (q.sign == CompareSign.gt) gt++;
            if (q.sign == CompareSign.lt) lt++;
          }
        }
        expect(positions.length, greaterThan(5));
        expect(gt, greaterThan(80));
        expect(lt, greaterThan(80));
      }
    });

    test('level 4 has at least two swapped-digit pairs (ab vs ba, both >= 10, a != b)', () {
      bool swapped(CompareQuestion q) =>
          q.left >= 10 && q.right >= 10 && q.left != q.right && q.left ~/ 10 == q.right % 10 && q.left % 10 == q.right ~/ 10;
      for (var seed = 0; seed < 100; seed++) {
        final qs = buildCompareRound(level: 4, random: Random(seed));
        expect(qs.where(swapped).length, greaterThanOrEqualTo(2), reason: 'seed $seed');
      }
    });

    test('the answer is the sign, and the sentences say the numbers left to right', () {
      const gt = CompareQuestion.numbers(level: 2, left: 5, right: 3);
      expect(gt.sign, CompareSign.gt);
      expect(gt.answer, '>');
      expect(gt.rightId, 'compare_right_gt');
      expect(gt.sentence, '5 lớn hơn 3');
      const lt = CompareQuestion.numbers(level: 3, left: 3, right: 15);
      expect(lt.sign, CompareSign.lt);
      expect(lt.answer, '<');
      expect(lt.rightId, 'compare_right_lt');
      expect(lt.sentence, '3 bé hơn 15');
      const eq = CompareQuestion.numbers(level: 4, left: 47, right: 47);
      expect(eq.sign, CompareSign.eq);
      expect(eq.answer, '=');
      expect(eq.rightId, 'compare_right_eq');
      expect(eq.sentence, '47 bằng 47');
      expect(lt.promptId, 'compare_ask');
      expect(lt.promptVars, {'a': '3', 'b': '15'});
      expect(lt.rightVars, {'a': '3', 'b': '15'});
      expect(compareShowsDots(2), isTrue);
      expect(compareShowsDots(3), isFalse);
      expect(compareShowsDots(4), isFalse);
    });

    test('works with PickSession: wrong, wrong, right gives a hinted outcome', () {
      final s = PickSession(const [CompareQuestion.numbers(level: 2, left: 3, right: 5)]);
      expect(s.tap('>'), TapResult.wrong);
      expect(s.tap('='), TapResult.wrong);
      expect(s.showHint, isTrue);
      expect(s.tap('<'), TapResult.correct);
      expect(s.outcomes.single, AnswerOutcome.hinted);
    });
  });

  group('levels', () {
    test('a round with 8 or more first tries goes up one level, at most to 4', () {
      expect(nextCompareLevel(1, 8), 2);
      expect(nextCompareLevel(1, 10), 2);
      expect(nextCompareLevel(1, 7), 1);
      expect(nextCompareLevel(3, 9), 4);
      expect(nextCompareLevel(4, 10), 4);
      expect(nextCompareLevel(2, 0), 2);
    });

    test('the level is read and written as the mastery (0..3) of compare:level', () async {
      final store = MemoryItemStatsStore();
      expect(compareLevelKey, 'compare:level');
      expect(await loadCompareLevel(store), 1);
      await saveCompareLevel(store, 3, DateTime(2026, 11, 11));
      expect(store.stats['compare:level']!.mastery, 2);
      expect(await loadCompareLevel(store), 3);
      await saveCompareLevel(store, 4, DateTime(2026, 11, 11));
      expect(store.stats['compare:level']!.mastery, 3);
      expect(await loadCompareLevel(store), 4);
      // Out-of-range values (e.g. from an ItemStat.apply) still give a valid level.
      store.stats['compare:level'] = const ItemStat(key: 'compare:level', mastery: 4);
      expect(await loadCompareLevel(store), 4);
      // Reset progress wipes item stats: back to level 1.
      store.stats.clear();
      expect(await loadCompareLevel(store), 1);
    });
  });
}
