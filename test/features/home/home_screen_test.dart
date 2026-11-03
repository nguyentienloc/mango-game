import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/features/castle/castle_screen.dart';
import 'package:xoai_castle/features/games/balloon/balloon_screen.dart';
import 'package:xoai_castle/features/games/talk/talk_screen.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/games/vocab/vocab_screen.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/story/math_gate_screen.dart';
import 'package:xoai_castle/shared/big_button.dart';

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

  testWidgets('tapping the snowflake counter says the count, part by part', (tester) async {
    final tts = await pumpHome(tester, rewards: const RewardState(snowflakesTotal: 12));
    tts.spoken.clear();
    await tester.tap(find.text('❄️ 12'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tts.texts, ['Xoài đã kiếm được', '12', 'bông tuyết rồi, giỏi quá nè!']);
  });

  testWidgets('the counter on the castle screen is tappable too', (tester) async {
    final tts = await pumpHome(tester, rewards: const RewardState(snowflakesTotal: 12));
    await tester.tap(find.byKey(const Key('home-castle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CastleScreen), findsOneWidget);
    tts.spoken.clear();
    await tester.tap(find.text('❄️ 12'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tts.texts, ['Xoài đã kiếm được', '12', 'bông tuyết rồi, giỏi quá nè!']);
  });

  testWidgets('the speech button opens the talk game', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('🗣️'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Nói chuyện với Elsa'));
    expect(find.byType(TalkScreen), findsOneWidget);
  });

  testWidgets('the pencil button opens the tracing game', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('✏️'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TraceScreen), findsOneWidget);
  });

  testWidgets('the paw button opens the vocabulary game', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('🐾'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Nhìn hình đoán từ'));
    expect(find.byType(VocabScreen), findsOneWidget);
  });

  testWidgets('the dog button is gone and the balloon game opens', (tester) async {
    final tts = await pumpHome(tester);
    expect(find.text('🐶'), findsNothing);
    await tester.tap(find.text('🎈'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Đập bong bóng'));
    expect(find.byType(BalloonScreen), findsOneWidget);
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

  testWidgets('the moon button says "Nghe chuyện" and opens the math gate', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('🌙'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Nghe chuyện'));
    expect(find.byType(MathGateScreen), findsOneWidget);
  });

  testWidgets('fits a 360x640 phone with all six game buttons', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpHome(tester);
    expect(tester.takeException(), isNull);
    final buttons = find.byType(BigButton);
    expect(buttons, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      final r = tester.getRect(buttons.at(i));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(360));
      expect(r.bottom, lessThanOrEqualTo(640));
    }
    final lock = tester.getRect(find.byKey(const Key('parent-lock')));
    expect(lock.bottom, lessThanOrEqualTo(640));
  });
}
