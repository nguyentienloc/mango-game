import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/features/games/compare/compare_cards.dart';
import 'package:xoai_castle/features/games/compare/compare_logic.dart';
import 'package:xoai_castle/features/games/compare/compare_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

const _levelUp = 'Lên cấp rồi! Giỏi quá!';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  MemoryItemStatsStore statsAt(int level) {
    final s = MemoryItemStatsStore();
    if (level > 1) s.stats[compareLevelKey] = ItemStat(key: compareLevelKey, mastery: level - 1);
    return s;
  }

  Future<void> settle(WidgetTester tester, [int steps = 10]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpGame(WidgetTester tester, FakeTts tts,
      {MemoryItemStatsStore? stats, MemorySessionStore? sessions, MemoryRewardStore? rewards}) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const CompareScreen(),
      itemStats: stats,
      sessions: sessions,
      rewards: rewards,
    ));
    await tester.pump();
    await settle(tester, 5);
  }

  /// The question on screen, read from the cards.
  ({int left, int right}) shown(WidgetTester tester) {
    final pics = find.byType(PictureCard);
    if (pics.evaluate().isNotEmpty) {
      return (left: tester.widget<PictureCard>(pics.at(0)).count, right: tester.widget<PictureCard>(pics.at(1)).count);
    }
    final nums = find.byType(NumberCard);
    return (left: tester.widget<NumberCard>(nums.at(0)).value, right: tester.widget<NumberCard>(nums.at(1)).value);
  }

  /// Level 1: which side is right for the question Elsa just asked.
  String rightSide(WidgetTester tester, FakeTts tts) {
    final q = shown(tester);
    final more = tts.texts.lastWhere((t) => t == 'Bên nào nhiều hơn?' || t == 'Bên nào ít hơn?') == 'Bên nào nhiều hơn?';
    return (q.left > q.right) == more ? 'left' : 'right';
  }

  String rightSign(WidgetTester tester) {
    final q = shown(tester);
    return q.left > q.right ? 'gt' : (q.left < q.right ? 'lt' : 'eq');
  }

  Future<void> answerRight(WidgetTester tester, FakeTts tts) async {
    if (find.byType(PictureCard).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(Key('compare-side-${rightSide(tester, tts)}')));
    } else {
      await tester.tap(find.byKey(Key('compare-sign-${rightSign(tester)}')));
    }
    await settle(tester, 25);
  }

  Future<void> answerWrong(WidgetTester tester, FakeTts tts) async {
    if (find.byType(PictureCard).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(Key('compare-side-${rightSide(tester, tts) == 'left' ? 'right' : 'left'}')));
    } else {
      final wrong = ['gt', 'lt', 'eq'].firstWhere((s) => s != rightSign(tester));
      await tester.tap(find.byKey(Key('compare-sign-$wrong')));
    }
    await settle(tester, 6);
  }

  testWidgets('level 1 asks which side has more or fewer, and a right tap says the numbers', (tester) async {
    final tts = FakeTts();
    await pumpGame(tester, tts);
    expect(find.byType(PictureCard), findsNWidgets(2));
    expect(find.byType(SignButton), findsNothing);
    var sawMore = false;
    for (var i = 0; i < 10 && !sawMore; i++) {
      final asked = tts.texts.last;
      expect(asked, anyOf('Bên nào nhiều hơn?', 'Bên nào ít hơn?'));
      // The question is written above the cards too.
      expect(find.text(asked), findsOneWidget);
      final q = shown(tester);
      final side = rightSide(tester, tts);
      final more = asked == 'Bên nào nhiều hơn?';
      // No numbers before the answer: the child counts.
      expect(find.byKey(const Key('compare-count-left')), findsNothing);
      tts.spoken.clear();
      await tester.tap(find.byKey(Key('compare-side-$side')));
      await settle(tester, 6);
      final picked = side == 'left' ? q.left : q.right;
      final other = side == 'left' ? q.right : q.left;
      expect(tts.texts.take(4).toList(), ['Đúng rồi!', '$picked', more ? 'nhiều hơn' : 'ít hơn', '$other']);
      // The numbers come up under each card, the right card glows, +1 for a first try.
      expect(find.descendant(of: find.byKey(const Key('compare-count-left')), matching: find.text('${q.left}')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('compare-count-right')), matching: find.text('${q.right}')), findsOneWidget);
      expect(find.byKey(Key('compare-win-$side')), findsOneWidget);
      expect(find.text('+1 ❄️'), findsOneWidget);
      sawMore = more;
      await settle(tester, 20);
    }
    expect(sawMore, isTrue);
  });

  testWidgets('a wrong tap shakes and says "Thử lại nha!"; a second one lights up the answer', (tester) async {
    final tts = FakeTts();
    await pumpGame(tester, tts);
    final side = rightSide(tester, tts);
    expect(find.byKey(const Key('compare-hint')), findsNothing);
    await answerWrong(tester, tts);
    expect(tts.texts.last, 'Thử lại nha!');
    expect(find.byKey(const Key('compare-hint')), findsNothing);
    await answerWrong(tester, tts);
    expect(find.byKey(const Key('compare-hint')), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key('compare-side-$side')), matching: find.byKey(const Key('compare-hint'))), findsOneWidget);
    await tester.tap(find.byKey(Key('compare-side-$side')));
    await settle(tester, 6);
    // A hinted answer earns no snowflake.
    expect(find.text('+1 ❄️'), findsNothing);
    expect(tts.texts, contains('Đúng rồi!'));
    await settle(tester, 20);
  });

  testWidgets('level 2 shows counting dots and the signs; "<" is right for a smaller left number', (tester) async {
    final tts = FakeTts();
    await pumpGame(tester, tts, stats: statsAt(2));
    expect(find.byType(PictureCard), findsNothing);
    expect(find.byType(SignButton), findsNWidgets(3));
    expect(find.text('lớn hơn'), findsOneWidget);
    expect(find.text('bé hơn'), findsOneWidget);
    expect(find.text('bằng'), findsOneWidget);
    var sawLt = false;
    for (var i = 0; i < 10 && !sawLt; i++) {
      final q = shown(tester);
      expect(q.left, inInclusiveRange(0, 10));
      expect(find.byKey(const Key('compare-dot')), findsNWidgets(q.left + q.right));
      expect(tts.texts.skip(tts.texts.length - 4).toList(), ['${q.left}', 'và', '${q.right}', 'Chọn dấu nào nhỉ?']);
      if (q.left < q.right) {
        tts.spoken.clear();
        await tester.tap(find.byKey(const Key('compare-sign-lt')));
        await settle(tester, 6);
        expect(tts.texts.take(4).toList(), ['Đúng rồi!', '${q.left}', 'bé hơn', '${q.right}']);
        expect(find.text('${q.left} bé hơn ${q.right}'), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('compare-box')), matching: find.text('<')), findsOneWidget);
        expect(find.byKey(const Key('compare-croc')), findsOneWidget);
        expect(find.byKey(const Key('compare-win-right')), findsOneWidget);
        expect(find.text('+1 ❄️'), findsOneWidget);
        sawLt = true;
      } else {
        await answerRight(tester, tts);
        continue;
      }
      await settle(tester, 20);
    }
    expect(sawLt, isTrue);
  });

  testWidgets('levels 3 and 4: numbers without dots in their range', (tester) async {
    for (final (level, max) in [(3, 20), (4, 99)]) {
      final tts = FakeTts();
      await pumpGame(tester, tts, stats: statsAt(level));
      expect(find.byKey(const Key('compare-dot')), findsNothing);
      final q = shown(tester);
      expect(q.left, inInclusiveRange(0, max));
      expect(q.right, inInclusiveRange(0, max));
      await answerRight(tester, tts);
      expect(tts.texts, contains('Đúng rồi!'));
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a round of 10 all right first time: +15 ❄️, level up said before the reward screen', (tester) async {
    final tts = FakeTts();
    final stats = statsAt(1);
    final sessions = MemorySessionStore();
    final rewards = MemoryRewardStore();
    await pumpGame(tester, tts, stats: stats, sessions: sessions, rewards: rewards);
    for (var i = 0; i < 10; i++) {
      expect(find.text('${i + 1}/10'), findsOneWidget);
      await answerRight(tester, tts);
    }
    await settle(tester, 40);
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+15 ❄️'), findsOneWidget);
    expect(tts.texts.where((t) => t == _levelUp), hasLength(1));
    // Said before the reward screen starts talking.
    expect(tts.texts.indexOf(_levelUp), greaterThan(tts.texts.lastIndexOf('Đúng rồi!')));
    expect(tts.texts.indexOf(_levelUp), lessThan(tts.texts.indexOf('Hoàn thành rồi! Xoài giỏi quá!')));
    expect(sessions.records.single.game, 'compare');
    expect(sessions.records.single.correct, 10);
    expect(sessions.records.single.total, 10);
    expect(stats.stats[compareLevelKey]!.mastery, 1);
    expect(stats.stats.keys, [compareLevelKey]);
  });

  testWidgets('fewer than 8 first tries: no level up', (tester) async {
    final tts = FakeTts();
    final stats = statsAt(2);
    await pumpGame(tester, tts, stats: stats);
    for (var i = 0; i < 10; i++) {
      if (i < 3) await answerWrong(tester, tts);
      await answerRight(tester, tts);
    }
    await settle(tester, 40);
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+12 ❄️'), findsOneWidget);
    expect(tts.texts, isNot(contains(_levelUp)));
    expect(stats.stats[compareLevelKey]!.mastery, 1);
  });

  testWidgets('level 4 is the top: a perfect round stays there and says no level up', (tester) async {
    final tts = FakeTts();
    final stats = statsAt(4);
    await pumpGame(tester, tts, stats: stats);
    for (var i = 0; i < 10; i++) {
      await answerRight(tester, tts);
    }
    await settle(tester, 40);
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(tts.texts, isNot(contains(_levelUp)));
    expect(stats.stats[compareLevelKey]!.mastery, 3);
  });

  testWidgets('level 1: both cards draw their pictures at the same size, even with 2 vs 9', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tts = FakeTts();
    await pumpGame(tester, tts);
    double emojiWidth(String side) {
      final emoji = tester.widget<PictureCard>(find.byType(PictureCard).at(side == 'left' ? 0 : 1)).emoji;
      final f = find.descendant(of: find.byKey(Key('compare-side-$side')), matching: find.text(emoji)).first;
      // getTopLeft/getBottomRight include the FittedBox scale, getSize does not.
      return tester.getBottomRight(f).dx - tester.getTopLeft(f).dx;
    }

    var sawBig = false;
    for (var i = 0; i < 10; i++) {
      final q = shown(tester);
      if (q.left > q.right ? q.left >= 8 : q.right >= 8) sawBig = true;
      expect(emojiWidth('left'), closeTo(emojiWidth('right'), 0.01), reason: '${q.left} vs ${q.right}');
      await answerRight(tester, tts);
      if (find.byType(PictureCard).evaluate().isEmpty) break;
    }
    expect(sawBig, isTrue);
  });

  testWidgets('picture cards and sign buttons answer on tap, not on touch down', (tester) async {
    final tts = FakeTts();
    await pumpGame(tester, tts);
    tts.spoken.clear();
    // A resting palm / the start of a swipe: down, drag away, up. No answer.
    final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('compare-side-left'))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tts.texts, isEmpty);
    await g.moveBy(const Offset(0, 120));
    await g.up();
    await settle(tester, 6);
    expect(tts.texts, isEmpty);
    expect(find.byKey(const Key('compare-count-left')), findsNothing);
    // A real tap still answers.
    await tester.tap(find.byKey(const Key('compare-side-left')));
    await settle(tester, 6);
    expect(tts.texts, isNotEmpty);
    await settle(tester, 20);
  });

  testWidgets('sign buttons answer on tap, not on touch down', (tester) async {
    final tts = FakeTts();
    await pumpGame(tester, tts, stats: statsAt(2));
    tts.spoken.clear();
    final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('compare-sign-gt'))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tts.texts, isEmpty);
    await g.moveBy(const Offset(0, -150));
    await g.up();
    await settle(tester, 6);
    expect(tts.texts, isEmpty);
    await tester.tap(find.byKey(const Key('compare-sign-gt')));
    await settle(tester, 6);
    expect(tts.texts, isNotEmpty);
    await settle(tester, 20);
  });

  group('the winner/hint border does not shrink the content', () {
    Future<void> pumpCard(WidgetTester tester, Widget card) => tester.pumpWidget(MaterialApp(
          home: Center(child: SizedBox(width: 170, height: 300, child: card)),
        ));

    for (final variant in [(name: 'winner', mark: CardMark.winner, hint: false), (name: 'hint', mark: CardMark.none, hint: true)]) {
      testWidgets('picture card: ${variant.name}', (tester) async {
        PictureCard card({required bool on}) => PictureCard(
              side: 'left',
              count: 9,
              emoji: '🍎',
              onTap: () {},
              mark: on ? variant.mark : CardMark.none,
              revealed: on && variant.mark == CardMark.winner,
              hint: on && variant.hint,
            );
        Rect emoji() {
          final f = find.text('🍎').first;
          return Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));
        }

        await pumpCard(tester, card(on: false));
        final before = emoji();
        final cardBefore = tester.getSize(find.byType(PictureCard));
        await pumpCard(tester, card(on: true));
        expect(tester.getSize(find.byType(PictureCard)), cardBefore);
        expect(emoji().width, closeTo(before.width, 0.01));
        expect(emoji().height, closeTo(before.height, 0.01));
        expect(emoji().topLeft.dx, closeTo(before.topLeft.dx, 0.01));
        expect(emoji().topLeft.dy, closeTo(before.topLeft.dy, 0.01));
      });
    }

    testWidgets('number card: winner', (tester) async {
      Rect number() {
        final f = find.text('7');
        return Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));
      }

      await tester.pumpWidget(const MaterialApp(home: Center(child: NumberCard(side: 'left', value: 7, dots: true))));
      final before = number();
      await tester.pumpWidget(const MaterialApp(home: Center(child: NumberCard(side: 'left', value: 7, dots: true, mark: CardMark.winner))));
      expect(number().width, closeTo(before.width, 0.01));
      expect(number().topLeft.dx, closeTo(before.topLeft.dx, 0.01));
      expect(number().topLeft.dy, closeTo(before.topLeft.dy, 0.01));
    });

    testWidgets('sign button: hint', (tester) async {
      Rect symbol() {
        final f = find.text('>');
        return Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));
      }

      Widget button(bool hint) => MaterialApp(
            home: Center(child: SizedBox(width: 100, child: SignButton(sign: CompareSign.gt, onTap: () {}, hint: hint))),
          );
      await tester.pumpWidget(button(false));
      final before = symbol();
      await tester.pumpWidget(button(true));
      expect(symbol().width, closeTo(before.width, 0.01));
      expect(symbol().topLeft.dx, closeTo(before.topLeft.dx, 0.01));
      expect(symbol().topLeft.dy, closeTo(before.topLeft.dy, 0.01));
    });
  });

  testWidgets('tapping Elsa repeats the question', (tester) async {
    final tts = FakeTts();
    await pumpGame(tester, tts);
    final asked = tts.texts.last;
    tts.spoken.clear();
    await tester.tap(find.byKey(const Key('compare-elsa')));
    await settle(tester, 3);
    expect(tts.texts, [asked]);
  });

  for (final level in [1, 2, 3, 4]) {
    testWidgets('level $level fits a 360x640 phone, before and after the answer', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tts = FakeTts();
      await pumpGame(tester, tts, stats: statsAt(level));
      expect(tester.takeException(), isNull);

      void onScreen(Finder f) {
        for (final e in f.evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget).first);
          expect(r.left, greaterThanOrEqualTo(0), reason: '$f');
          expect(r.top, greaterThanOrEqualTo(0), reason: '$f');
          expect(r.right, lessThanOrEqualTo(360), reason: '$f');
          expect(r.bottom, lessThanOrEqualTo(640), reason: '$f');
        }
      }

      onScreen(find.byKey(const Key('compare-elsa')));
      onScreen(find.text('1/10'));
      if (level == 1) {
        onScreen(find.byType(PictureCard));
      } else {
        onScreen(find.byType(NumberCard));
        onScreen(find.byType(SignButton));
        onScreen(find.byKey(const Key('compare-box')));
      }
      if (level == 1) {
        await tester.tap(find.byKey(Key('compare-side-${rightSide(tester, tts)}')));
      } else {
        await tester.tap(find.byKey(Key('compare-sign-${rightSign(tester)}')));
      }
      await settle(tester, 6);
      expect(tester.takeException(), isNull);
      onScreen(find.text('+1 ❄️'));
      if (level == 1) {
        onScreen(find.byKey(const Key('compare-count-left')));
        onScreen(find.byKey(const Key('compare-count-right')));
      } else {
        onScreen(find.byKey(const Key('compare-sentence')));
        onScreen(find.byKey(const Key('compare-croc')));
      }
      await settle(tester, 20);
    });
  }

  Widget launcher() => Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CompareScreen())),
          child: const Text('go'),
        ),
      );

  testWidgets('the system back gesture says go_home and leaves the game', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: launcher()));
    await tester.tap(find.text('go'));
    await tester.pump();
    await settle(tester, 5);
    expect(find.byType(CompareScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester, 10);
    expect(find.byType(CompareScreen), findsNothing);
    expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1));
  });

  testWidgets('the home button says go_home once and leaves the game', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: launcher()));
    await tester.tap(find.text('go'));
    await tester.pump();
    await settle(tester, 5);
    await tester.tap(find.text('🏠'));
    await settle(tester, 10);
    expect(find.byType(CompareScreen), findsNothing);
    expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1));
  });
}
