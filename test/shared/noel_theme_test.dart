import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/app/animation_flags.dart';
import 'package:xoai_castle/app/theme.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/time.dart';
import 'package:xoai_castle/features/games/trace/trace_pad.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';
import 'package:xoai_castle/shared/big_button.dart';
import 'package:xoai_castle/shared/castle_view.dart';
import 'package:xoai_castle/shared/character_view.dart';
import 'package:xoai_castle/shared/noel_background.dart';
import 'package:xoai_castle/shared/quest_dots.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void _paintAt(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

const _sizes = [Size.zero, Size(1, 1), Size(10, 6), Size(23, 40), Size(40, 23), Size(360, 640), Size(360, 200), Size(1200, 60)];

void main() {
  group('painters draw without error at any size', () {
    for (final scene in NoelScene.values) {
      test('sky ${scene.name}', () {
        for (final s in _sizes) {
          _paintAt(NoelSkyPainter(scene), s);
          _paintAt(SparklePainter(scene), s);
        }
      });
    }
    test('castle (every level), Santa hat', () {
      for (final s in _sizes) {
        for (var level = 1; level <= 8; level++) {
          _paintAt(CastlePainter(level), s);
        }
        _paintAt(const SantaHatPainter(), s);
      }
    });
  });

  group('NoelBackground', () {
    Widget sky({required bool animations, required Size size}) => ProviderScope(
          overrides: [animationsEnabledProvider.overrideWithValue(animations)],
          child: MaterialApp(
            home: Center(
              child: SizedBox.fromSize(size: size, child: const NoelBackground(child: Text('hi'))),
            ),
          ),
        );

    for (final size in const [Size(360, 640), Size(20, 20), Size(2, 2), Size(0, 0)]) {
      testWidgets('paints at ${size.width}x${size.height} with the twinkle on', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(sky(animations: true, size: size));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('settles (nothing ticking) with animations off', (tester) async {
      await tester.pumpWidget(sky(animations: false, size: const Size(360, 640)));
      await tester.pumpAndSettle();
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('both scenes at 360x640 with the system bars', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
      addTearDown(tester.view.reset);
      for (final scene in NoelScene.values) {
        await tester.pumpWidget(ProviderScope(child: MaterialApp(home: NoelSky(scene: scene))));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Noel screens at 360x640 with the twinkle running', () {
    late ContentBundle content;

    setUpAll(() async {
      content = await ContentRepository(FileContentSource('content')).load();
    });

    const screen = Rect.fromLTWH(0, 0, 360, 640);

    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    void onScreen(WidgetTester tester, Finder f) {
      final r = tester.getRect(f);
      expect(screen.intersect(r), r, reason: '$f at $r');
    }

    testWidgets('home: night sky over the castle, buttons on the snow with red/green rings, gifts, hatted Elsa', (tester) async {
      phone(tester);
      final rewards = MemoryRewardStore(RewardState(snowflakesTotal: 4, dailyQuestDate: dayKey(DateTime(2026, 11, 2)), dailyRoundsDone: 1));
      await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const HomeScreen(), rewards: rewards, animations: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      final sky = tester.getRect(find.byWidgetPredicate((w) => w is NoelSky && w.scene == NoelScene.home));
      final buttons = find.byType(BigButton);
      expect(buttons, findsNWidgets(7));
      for (var i = 0; i < 7; i++) {
        onScreen(tester, buttons.at(i));
        // Below the sky, on the snow.
        expect(tester.getRect(buttons.at(i)).top, greaterThanOrEqualTo(sky.bottom));
        expect(tester.widget<BigButton>(buttons.at(i)).ring, i.isEven ? NoelColors.red : NoelColors.green);
      }
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, NoelColors.snow);
      onScreen(tester, find.byType(CastleView));
      onScreen(tester, find.byKey(const Key('santa-hat')));
      onScreen(tester, find.byKey(const Key('parent-lock')));

      // Today's quest: three gifts, the played round full, the others faint.
      expect(find.descendant(of: find.byType(QuestDots), matching: find.text('🎁')), findsNWidgets(3));
      expect(tester.widget<Opacity>(find.byKey(const Key('quest-gift-0'))).opacity, 1);
      expect(tester.widget<Opacity>(find.byKey(const Key('quest-gift-1'))).opacity, 0.35);
      expect(tester.widget<Opacity>(find.byKey(const Key('quest-gift-2'))).opacity, 0.35);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reward: gold count, confetti, green-ringed check, all on screen', (tester) async {
      phone(tester);
      const outcome = RewardOutcome(
        earned: 5,
        questCompleted: false,
        previousLevel: 2,
        newLevel: 2,
        friendUnlocked: null,
        state: RewardState(snowflakesTotal: 30, castleLevel: 2),
      );
      await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const RewardScreen(outcome: outcome), animations: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('reward-confetti')), findsOneWidget);
      expect(tester.widget<Text>(find.text('+5 ❄️')).style?.color, NoelColors.gold);
      final check = find.widgetWithText(BigButton, '✅');
      expect(tester.widget<BigButton>(check).ring, NoelColors.green);
      onScreen(tester, check);
      onScreen(tester, find.byType(CastleView));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('trace: the white pad with a red frame, red counter pill, home button with a red ring', (tester) async {
      phone(tester);
      await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const TraceScreen(), animations: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      onScreen(tester, find.byKey(const Key('trace-pad')));
      onScreen(tester, find.text('1/10'));
      expect(tester.widget<Text>(find.text('1/10')).style?.color, NoelColors.deepRed);
      expect(tester.widget<BigButton>(find.widgetWithText(BigButton, '🏠')).ring, NoelColors.red);
      final guide = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_GuidePainter');
      expect(
        tester.renderObject(guide),
        paints
          ..rrect(color: Colors.white)
          ..rrect(color: kTracePadBorder, strokeWidth: kTracePadBorderWidth, style: PaintingStyle.stroke),
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
