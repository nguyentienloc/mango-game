import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/features/castle/castle_screen.dart';
import 'package:xoai_castle/features/games/find_letter/find_letter_screen.dart';
import 'package:xoai_castle/features/home/home_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<FakeTts> pumpHome(WidgetTester tester, {RewardState rewards = const RewardState(), UpdateCheck update = const UpToDate()}) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const HomeScreen(),
      rewards: MemoryRewardStore(rewards),
      update: update,
    ));
    await tester.pump();
    await tester.pump();
    return tts;
  }

  testWidgets('shows snowflakes and greets the child', (tester) async {
    final tts = await pumpHome(tester, rewards: const RewardState(snowflakesTotal: 12));
    expect(find.text('❄️ 12'), findsOneWidget);
    expect(tts.texts, contains('Chào Xoài! Hôm nay mình chơi gì nào?'));
    expect(find.byKey(const Key('update-dot')), findsNothing);
  });

  testWidgets('a coming-soon game says its name and stays on home', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('✏️'));
    await tester.pump();
    await tester.pump();
    expect(tts.texts, containsAllInOrder(['Tô chữ', 'Trò này sắp có rồi nha!']));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the balloon button opens the find-letter game', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('🎈'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Tìm chữ cái'));
    expect(find.byType(FindLetterScreen), findsOneWidget);
  });

  testWidgets('tapping the castle opens the castle screen', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-castle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CastleScreen), findsOneWidget);
  });

  testWidgets('shows a red dot on the lock when an update is available', (tester) async {
    await pumpHome(
      tester,
      update: const UpdateAvailable(ReleaseInfo(version: '0.2.0', apkUrl: 'https://x/a.apk', sizeBytes: 1)),
    );
    expect(find.byKey(const Key('update-dot')), findsOneWidget);
  });
}
