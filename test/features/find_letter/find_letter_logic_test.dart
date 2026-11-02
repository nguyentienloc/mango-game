import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/find_letter/find_letter_logic.dart';

final letters = [
  for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) LetterItem(char: c, exampleWord: 'W$c', exampleEmoji: '⭐'),
];

Map<String, ItemStat> mastered(FindLetterMode mode, int n) => {
      for (final l in letters.take(n)) findLetterKey(mode, l): ItemStat(key: findLetterKey(mode, l), mastery: 2),
    };

List<FindLetterQuestion> round(Map<String, ItemStat> stats, [int seed = 1]) => buildFindLetterRound(
      letters: letters,
      stats: stats,
      picker: QuestionPicker(Random(seed)),
      random: Random(seed),
    );

void main() {
  group('keys and modes', () {
    test('keys per mode', () {
      final b = letters[1];
      expect(findLetterKey(FindLetterMode.upper, b), 'letter_en_upper:B');
      expect(findLetterKey(FindLetterMode.lower, b), 'letter_en_lower:b');
      expect(findLetterKey(FindLetterMode.match, b), 'letter_en_match:B');
    });

    test('unlocks lower case after 20 mastered upper case letters', () {
      expect(highestUnlockedMode(letters, const {}), FindLetterMode.upper);
      expect(highestUnlockedMode(letters, mastered(FindLetterMode.upper, 19)), FindLetterMode.upper);
      expect(highestUnlockedMode(letters, mastered(FindLetterMode.upper, 20)), FindLetterMode.lower);
    });

    test('unlocks matching after 20 mastered lower case letters', () {
      final stats = {...mastered(FindLetterMode.upper, 20), ...mastered(FindLetterMode.lower, 20)};
      expect(highestUnlockedMode(letters, stats), FindLetterMode.match);
    });
  });

  group('round building', () {
    test('fresh player gets 8 upper-case questions with 3 unique options', () {
      final qs = round(const {});
      expect(qs, hasLength(8));
      for (final q in qs) {
        expect(q.mode, FindLetterMode.upper);
        expect(q.options, hasLength(3));
        expect(q.options.toSet(), hasLength(3));
        expect(q.options, contains(q.answer));
        expect(q.answer, q.item.char);
        expect(q.shownLetter, isNull);
        expect(q.promptPhraseId, 'find_letter_prompt');
        expect(q.promptVars, {'letter': q.item.char});
      }
      for (var i = 1; i < qs.length; i++) {
        expect(qs[i].key, isNot(qs[i - 1].key));
      }
    });

    test('lower mode mixes in two upper-case review questions', () {
      final qs = round(mastered(FindLetterMode.upper, 20));
      expect(qs.where((q) => q.mode == FindLetterMode.lower), hasLength(6));
      expect(qs.where((q) => q.mode == FindLetterMode.upper), hasLength(2));
      final lower = qs.firstWhere((q) => q.mode == FindLetterMode.lower);
      expect(lower.answer, lower.item.lower);
      expect(lower.options.every((o) => o == o.toLowerCase()), isTrue);
    });

    test('match mode shows the capital and offers 4 lower-case options', () {
      final stats = {...mastered(FindLetterMode.upper, 20), ...mastered(FindLetterMode.lower, 20)};
      final q = round(stats).firstWhere((q) => q.mode == FindLetterMode.match);
      expect(q.options, hasLength(4));
      expect(q.shownLetter, q.item.char);
      expect(q.answer, q.item.lower);
      expect(q.promptPhraseId, 'find_letter_small_prompt');
      expect(q.promptVars, {'letter': q.item.lower});
    });
  });

  group('session', () {
    FindLetterSession session() => FindLetterSession(round(const {}));

    test('correct first tap is firstTry', () {
      final s = session();
      expect(s.tap(s.current.answer), TapResult.correct);
      expect(s.outcomes, [AnswerOutcome.firstTry]);
    });

    test('one wrong tap then correct is retry', () {
      final s = session();
      final wrong = s.current.options.firstWhere((o) => o != s.current.answer);
      expect(s.tap(wrong), TapResult.wrong);
      expect(s.showHint, isFalse);
      s.tap(s.current.answer);
      expect(s.outcomes, [AnswerOutcome.retry]);
    });

    test('two wrong taps show the hint and the answer counts as hinted', () {
      final s = session();
      final wrong = s.current.options.firstWhere((o) => o != s.current.answer);
      s.tap(wrong);
      s.tap(wrong);
      expect(s.showHint, isTrue);
      s.tap(s.current.answer);
      expect(s.outcomes, [AnswerOutcome.hinted]);
    });

    test('taps after a correct answer are ignored until next()', () {
      final s = session();
      s.tap(s.current.answer);
      expect(s.tap(s.current.answer), TapResult.ignored);
      expect(s.outcomes, hasLength(1));
      s.next();
      expect(s.index, 1);
      expect(s.showHint, isFalse);
    });

    test('finishes after the last question and counts first tries', () {
      final s = session();
      for (var i = 0; i < 8; i++) {
        if (i.isEven) s.tap(s.current.options.firstWhere((o) => o != s.current.answer));
        s.tap(s.current.answer);
        s.next();
      }
      expect(s.isFinished, isTrue);
      expect(s.firstTryCount, 4);
      expect(s.tap('A'), TapResult.ignored);
    });
  });
}
