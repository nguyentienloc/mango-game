import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

const _all = RewardOutcome(
  earned: 33,
  questBonus: 20,
  questCompleted: true,
  previousLevel: 1,
  newLevel: 2,
  friendUnlocked: 'olaf',
  state: RewardState(),
);

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Widget launcher(FakeTts tts) => testApp(
        content: content,
        tts: tts,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RewardScreen(outcome: _all))),
            child: const Text('go'),
          ),
        ),
      );

  testWidgets('leaving the reward screen stops the rest of the speech chain', (tester) async {
    final tts = GatedTts();
    await tester.pumpWidget(launcher(tts));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, ['Hoàn thành rồi! Xoài giỏi quá!']);

    await tester.tap(find.text('✅'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tts.release();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(tts.texts, ['Hoàn thành rồi! Xoài giỏi quá!', 'Về lâu đài nào!']);
    expect(find.byType(RewardScreen), findsNothing);
  });

  testWidgets('the whole chain is spoken when the child stays', (tester) async {
    final tts = GatedTts();
    await tester.pumpWidget(launcher(tts));
    await tester.tap(find.text('go'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      tts.release();
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(tts.texts, hasLength(4));
    expect(tts.texts.last, 'Có bạn mới đến chơi với Xoài nè!');
  });

  group('daily quest gift', () {
    const questOnly = RewardOutcome(
      earned: 30,
      questBonus: 20,
      questCompleted: true,
      previousLevel: 1,
      newLevel: 1,
      friendUnlocked: null,
      state: RewardState(),
    );
    const gift = Key('reward-gift');

    Widget open(FakeTts tts, RewardOutcome o) => testApp(content: content, tts: tts, home: RewardScreen(outcome: o));

    testWidgets('the gift holds the quest bonus: tapping it opens it and adds the bonus to the count', (tester) async {
      final tts = FakeTts();
      await tester.pumpWidget(open(tts, questOnly));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(gift), findsOneWidget);
      expect(find.text('+10 ❄️'), findsOneWidget);
      expect(find.text('+20 ❄️'), findsNothing);

      await tester.tap(find.byKey(gift));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('+20 ❄️'), findsOneWidget);
      expect(find.text('+30 ❄️'), findsOneWidget);
      expect(tts.texts.last, 'Oa! Quà là thật nhiều bông tuyết cho Xoài nè!');

      // A second tap does nothing more.
      await tester.tap(find.byKey(gift));
      await tester.pump(const Duration(seconds: 2));
      expect(tts.texts.where((t) => t.startsWith('Oa! Quà')), hasLength(1));
    });

    testWidgets('a gift opened before Elsa asks for it skips "open the gift" and is spoken right after the current line', (tester) async {
      final tts = GatedTts();
      await tester.pumpWidget(open(tts, questOnly));
      await tester.pump();
      expect(tts.texts, ['Hoàn thành rồi! Xoài giỏi quá!']);

      await tester.tap(find.byKey(gift));
      await tester.pump();
      tts.release();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tts.texts, ['Hoàn thành rồi! Xoài giỏi quá!', 'Oa! Quà là thật nhiều bông tuyết cho Xoài nè!']);
      tts.release();
      await tester.pump(const Duration(seconds: 1));
      expect(tts.texts, hasLength(2));
    });

    testWidgets('no quest, no gift, the full count at once', (tester) async {
      const plain = RewardOutcome(
        earned: 8,
        questCompleted: false,
        previousLevel: 1,
        newLevel: 1,
        friendUnlocked: null,
        state: RewardState(),
      );
      await tester.pumpWidget(open(FakeTts(), plain));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(gift), findsNothing);
      expect(find.text('+8 ❄️'), findsOneWidget);
    });
  });

  for (final size in const [Size(1080, 1920), Size(1080, 1704)]) {
    // 360x640 dp, and 360x568 dp (a 640 phone with the system bars showing).
    testWidgets('quest + level-up + friend fit ${size.width / 3}x${size.height / 3} dp and keep the check button reachable', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const RewardScreen(outcome: _all)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      final button = find.text('✅');
      expect(button, findsOneWidget);
      expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(size.height / 3));
      expect(button.hitTestable(), findsOneWidget);
    });
  }
}
