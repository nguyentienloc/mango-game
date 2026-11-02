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
  earned: 13,
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
