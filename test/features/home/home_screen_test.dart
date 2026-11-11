import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/features/castle/castle_screen.dart';
import 'package:xoai_castle/features/games/balloon/balloon_screen.dart';
import 'package:xoai_castle/features/games/compare/compare_screen.dart';
import 'package:xoai_castle/features/games/talk/talk_screen.dart';
import 'package:xoai_castle/features/games/trace/trace_chooser_screen.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/games/vocab/vocab_screen.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/story/math_gate_screen.dart';
import 'package:xoai_castle/shared/big_button.dart';
import 'package:xoai_castle/shared/castle_view.dart';
import 'package:xoai_castle/shared/character_view.dart';

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

  testWidgets('the pencil button opens the letters/numbers tracing chooser', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('✏️'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Tô chữ'));
    expect(find.byType(TraceChooserScreen), findsOneWidget);
    expect(find.byType(TraceScreen), findsNothing);
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

  testWidgets('the scales button says "So sánh" and opens the compare game', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('⚖️'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('So sánh'));
    expect(find.byType(CompareScreen), findsOneWidget);
    // Named before the game's first question.
    expect(tts.texts.indexOf('So sánh'), lessThan(tts.texts.indexWhere((t) => t.startsWith('Bên nào'))));
  });

  testWidgets('the scales button comes right before the moon', (tester) async {
    await pumpHome(tester);
    final emojis = [for (final b in tester.widgetList<BigButton>(find.byType(BigButton))) b.emoji];
    expect(emojis, ['🐾', '🎈', '✏️', '🗣️', '🇻🇳', '⚖️', '🌙']);
  });

  testWidgets('fits a 360x640 phone with all seven game buttons', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpHome(tester);
    expect(tester.takeException(), isNull);
    final buttons = find.byType(BigButton);
    expect(buttons, findsNWidgets(7));
    for (var i = 0; i < 7; i++) {
      final r = tester.getRect(buttons.at(i));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(360));
      expect(r.bottom, lessThanOrEqualTo(640));
    }
    final lock = tester.getRect(find.byKey(const Key('parent-lock')));
    expect(lock.bottom, lessThanOrEqualTo(640));
  });

  // Seven buttons: 4 + 3 rows, and the castle + Elsa scale down instead of clipping.
  for (final c in [
    (name: '360x640', w: 360.0, h: 640.0, top: 0.0, bottom: 0.0),
    (name: '360x640 with status and navigation bars', w: 360.0, h: 640.0, top: 24.0, bottom: 48.0),
    (name: '393x873', w: 393.0, h: 873.0, top: 0.0, bottom: 0.0),
  ]) {
    testWidgets('home at ${c.name}: no overflow, 7 hittable buttons in rows of 4+3, Elsa and castle fully visible', (tester) async {
      tester.view.physicalSize = Size(c.w, c.h);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: c.top, bottom: c.bottom);
      tester.view.viewPadding = FakeViewPadding(top: c.top, bottom: c.bottom);
      addTearDown(tester.view.reset);
      await pumpHome(tester);
      expect(tester.takeException(), isNull);
      final screen = Offset.zero & Size(c.w, c.h);
      final buttons = find.byType(BigButton);
      expect(buttons, findsNWidgets(7));
      final rows = <double>{};
      for (var i = 0; i < 7; i++) {
        final r = tester.getRect(buttons.at(i));
        expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight), isTrue, reason: 'button $i $r');
        rows.add(r.top);
        // Hit-testable: the tap lands on this very button.
        final hits = tester.hitTestOnBinding(r.center).path.map((e) => e.target).whereType<RenderObject>();
        expect(hits.any((t) => t == tester.renderObject(buttons.at(i))), isTrue, reason: 'button $i not hittable');
      }
      expect(rows.length, 2, reason: 'rows of 4+3');
      final firstRow = [for (var i = 0; i < 7; i++) tester.getRect(buttons.at(i))].where((r) => r.top == rows.reduce((a, b) => a < b ? a : b));
      expect(firstRow.length, 4);
      final elsa = tester.getRect(find.byWidgetPredicate((w) => w is CharacterView && w.id == 'elsa'));
      expect(screen.contains(elsa.topLeft) && screen.contains(elsa.bottomRight), isTrue, reason: 'Elsa $elsa');
      expect(elsa.top, greaterThanOrEqualTo(c.top));
      final castle = tester.getRect(find.byType(CastleView));
      expect(screen.contains(castle.topLeft) && screen.contains(castle.bottomRight), isTrue, reason: 'castle $castle');
      expect(castle.height, greaterThan(60));
      final lock = tester.getRect(find.byKey(const Key('parent-lock')));
      expect(lock.bottom, lessThanOrEqualTo(c.h - c.bottom));
      // The castle is still tappable.
      final hit = tester.hitTestOnBinding(castle.center).path.map((e) => e.target).whereType<RenderObject>();
      expect(hit.any((t) => t == tester.renderObject(find.byKey(const Key('home-castle')))), isTrue);
    });
  }
}
