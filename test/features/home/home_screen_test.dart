import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/features/castle/castle_screen.dart';
import 'package:xoai_castle/features/games/vocab/vocab_screen.dart';
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

  testWidgets('the paw button opens the vocabulary game', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('🐾'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Nhìn hình đoán từ'));
    expect(find.byType(VocabScreen), findsOneWidget);
  });

  testWidgets('the balloon game is hidden by default and the dog button is gone', (tester) async {
    await pumpHome(tester);
    expect(find.text('🎈'), findsNothing);
    expect(find.text('🐶'), findsNothing);
  });

  testWidgets('the balloon game shows when the parent switch is on', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
        content: content, tts: tts, home: const HomeScreen(), profile: MemoryProfileStore(show: true)));
    await tester.pump();
    await tester.pump();
    expect(find.text('🎈'), findsOneWidget);
  });

  testWidgets('the game opens only after its name has been spoken', (tester) async {
    final tts = GatedTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const HomeScreen()));
    await tester.pump();
    await tester.pump();
    tts.release();
    await tester.tap(find.text('🐾'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts.last, 'Nhìn hình đoán từ');
    expect(find.byType(VocabScreen), findsNothing);

    tts.release();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VocabScreen), findsOneWidget);
  });

  testWidgets('a second tap while the game name is being spoken does not stack another game', (tester) async {
    final tts = GatedTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const HomeScreen()));
    await tester.pump();
    await tester.pump();
    tts.release();
    await tester.tap(find.text('🐾'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('🐾'), warnIfMissed: false);
    await tester.tap(find.byKey(const Key('home-castle')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 3; i++) {
      tts.release();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(VocabScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(CastleScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('a speech that never ends delays the game by at most 3 s', (tester) async {
    final tts = GatedTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const HomeScreen()));
    await tester.pump();
    await tester.pump();
    tts.release();
    await tester.tap(find.text('🐾'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(VocabScreen), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VocabScreen), findsOneWidget);
  });

  testWidgets('the back gesture does not leave the app from home', (tester) async {
    await pumpHome(tester);
    final popped = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(popped, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('tapping the castle opens the castle screen', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-castle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CastleScreen), findsOneWidget);
  });

  testWidgets('castle tap is spoken, and its home button speaks and returns home', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-castle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Lâu đài của Xoài'));
    expect(find.byType(CastleScreen), findsOneWidget);

    await tester.tap(find.text('🏠'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Về lâu đài nào!'));
    expect(find.byType(CastleScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('shows a red dot on the lock when an update is available', (tester) async {
    await pumpHome(
      tester,
      update: const UpdateAvailable(ReleaseInfo(version: '0.2.0', apkUrl: 'https://x/a.apk', sizeBytes: 1)),
    );
    expect(find.byKey(const Key('update-dot')), findsOneWidget);
  });
}
