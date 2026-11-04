import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/talk/talk_logic.dart';

const age = ConversationItem(
  id: 'age',
  question: 'How old are you?',
  model: 'I am five.',
  accept: [
    ['five'],
  ],
);

final items = [
  for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'])
    ConversationItem(id: id, question: 'q $id', model: 'm $id', accept: [
      [id],
    ]),
];

List<ConversationItem> round(Map<String, ItemStat> stats, [int seed = 1]) =>
    buildTalkRound(items: items, stats: stats, picker: QuestionPicker(Random(seed)));

void main() {
  group('buildTalkRound', () {
    test('5 distinct items with conv: keys', () {
      for (var seed = 0; seed < 30; seed++) {
        final r = round(const {}, seed);
        expect(r, hasLength(5));
        expect(r.map((i) => i.id).toSet(), hasLength(5));
      }
      expect(talkKey(items.first), 'conv:a');
    });

    test('at most 3 unseen items in a round', () {
      final stats = {
        for (final id in ['a', 'b', 'c', 'd'])
          'conv:$id': ItemStat(key: 'conv:$id', mastery: 1, correct: 1, lastSeen: DateTime(2026)),
      };
      for (var seed = 0; seed < 30; seed++) {
        final r = round(stats, seed);
        expect(r, hasLength(5));
        final unseen = r.where((i) => !stats.containsKey(talkKey(i))).length;
        expect(unseen, lessThanOrEqualTo(3));
      }
    });

    test('a pool smaller than the count gives each item once', () {
      final r = buildTalkRound(items: items.take(3).toList(), stats: const {}, picker: QuestionPicker(Random(1)));
      expect(r, hasLength(3));
    });
  });

  group('TalkTurn normal', () {
    test('right first time: firstTry', () {
      final t = TalkTurn(age);
      final f = t.submit(['I am five']);
      expect(f.correct, isTrue);
      expect(f.tryAgain, isFalse);
      expect(f.sayAfter, isFalse);
      expect(f.moveOn, isFalse);
      expect(t.isDone, isTrue);
      expect(t.outcome, AnswerOutcome.firstTry);
      expect(t.earnsSnowflake, isTrue);
      expect(t.attempts, 1);
    });

    test('wrong once then right: retry, no snowflake', () {
      final t = TalkTurn(age);
      final f1 = t.submit(['banana']);
      expect((f1.correct, f1.tryAgain, f1.sayAfter, f1.moveOn), (false, true, false, false));
      expect(t.isDone, isFalse);
      expect(t.outcome, isNull);
      final f2 = t.submit(['five']);
      expect(f2.correct, isTrue);
      expect(t.outcome, AnswerOutcome.retry);
      expect(t.earnsSnowflake, isFalse);
    });

    test('wrong twice asks to say after, then right: hinted', () {
      final t = TalkTurn(age);
      t.submit(['x']);
      final f2 = t.submit(['y']);
      expect((f2.correct, f2.tryAgain, f2.sayAfter, f2.moveOn), (false, false, true, false));
      expect(t.isDone, isFalse);
      final f3 = t.submit(['five']);
      expect(f3.correct, isTrue);
      expect(f3.moveOn, isFalse);
      expect(t.isDone, isTrue);
      expect(t.outcome, AnswerOutcome.hinted);
    });

    test('a third miss ends the turn without passing it, even if empty', () {
      final t = TalkTurn(age);
      t.submit(['x']);
      t.submit(['y']);
      final f3 = t.submit(const []);
      expect((f3.correct, f3.tryAgain, f3.sayAfter, f3.moveOn), (false, false, false, true));
      expect(f3.correct, isFalse);
      expect(t.isDone, isTrue);
      expect(t.outcome, AnswerOutcome.hinted);
      expect(t.earnsSnowflake, isFalse);
      expect(t.attempts, 3);
    });

    test('submit after done is ignored', () {
      final t = TalkTurn(age);
      t.submit(['five']);
      final f = t.submit(['x']);
      expect((f.correct, f.tryAgain, f.sayAfter, f.moveOn), (false, false, false, false));
      expect(t.outcome, AnswerOutcome.firstTry);
      expect(t.attempts, 1);
    });

    test('confirm does nothing in normal mode', () {
      final t = TalkTurn(age);
      expect(t.confirm(), isFalse);
      expect(t.isDone, isFalse);
    });

    test('childName is used when matching the name item', () {
      const name = ConversationItem(id: 'name', question: 'q', model: 'm', accept: [
        ['an'],
      ]);
      expect(TalkTurn(name, childName: 'Lily').submit(['Lily']).correct, isTrue);
      expect(TalkTurn(name).submit(['Lily']).correct, isFalse);
    });
  });

  group('TalkTurn followAlong', () {
    test('starts needing the model, confirm finishes with no mastery change but a snowflake', () {
      final t = TalkTurn(age, mode: TalkMode.followAlong);
      expect(t.isDone, isFalse);
      expect(t.outcome, isNull);
      expect(t.confirm(), isTrue);
      expect(t.isDone, isTrue);
      expect(t.outcome, isNull);
      expect(t.earnsSnowflake, isTrue);
      expect(t.confirm(), isFalse);
    });

    test('submit is ignored', () {
      final t = TalkTurn(age, mode: TalkMode.followAlong);
      final f = t.submit(['five']);
      expect(f.correct, isFalse);
      expect(t.isDone, isFalse);
    });

    test('not done is not rewarded', () {
      expect(TalkTurn(age, mode: TalkMode.followAlong).earnsSnowflake, isFalse);
    });
  });

  group('passUnheard', () {
    test('ends the turn as hinted without a snowflake', () {
      final t = TalkTurn(age);
      expect(t.passUnheard(), isTrue);
      expect(t.isDone, isTrue);
      expect(t.outcome, AnswerOutcome.hinted);
      expect(t.earnsSnowflake, isFalse);
      expect(t.passUnheard(), isFalse);
    });
  });
}
