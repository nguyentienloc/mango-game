import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/games/trace/trace_chooser_screen.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import 'trace_screen_test.dart' show asked, drawPoints;

void main() {
  late ContentBundle content;
  setUpAll(() async => content = await ContentRepository(FileContentSource('content')).load());

  Future<FakeTts> pumpChooser(WidgetTester tester, {FakeTts? ttsOverride}) async {
    final tts = ttsOverride ?? FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const Scaffold(body: Center(child: Text('root'))),
    ));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const TraceChooserScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return tts;
  }

  Future<FakeTts> pumpHomeToChooser(WidgetTester tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const HomeScreen(), rewards: MemoryRewardStore()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('✏️'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return tts;
  }

  testWidgets('the letters button names the game and opens the English tracing game, going home on exit', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.tap(find.text('🔤'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Chữ cái'));
    final spec = tester.widget<TraceScreen>(find.byType(TraceScreen)).spec;
    expect(spec, same(LetterGameSpec.traceEnFromChooser));
    expect(spec.popToRootOnExit, isTrue);
    expect(spec.keyPrefix, LetterGameSpec.traceEn.keyPrefix);
    expect(spec.sessionGame, LetterGameSpec.traceEn.sessionGame);
    expect(spec.promptId, LetterGameSpec.traceEn.promptId);
    expect(spec.doneId, LetterGameSpec.traceEn.doneId);
    expect(spec.showExampleCard, isTrue);
  });

  testWidgets('the numbers button names the game and opens the number tracing game', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.tap(find.text('🔢'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Chữ số'));
    expect(tester.widget<TraceScreen>(find.byType(TraceScreen)).spec, same(LetterGameSpec.traceNumbers));
    expect(tts.texts, contains('Mình cùng viết số'));
  });

  testWidgets('a double tap opens only one game', (tester) async {
    final tts = GatedTts();
    await pumpChooser(tester, ttsOverride: tts);
    tts.release();
    await tester.tap(find.text('🔤'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('🔢'), warnIfMissed: false);
    await tester.tap(find.text('🔤'), warnIfMissed: false);
    for (var i = 0; i < 3; i++) {
      tts.release();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(TraceScreen, skipOffstage: false), findsOneWidget);
    expect(tester.widget<TraceScreen>(find.byType(TraceScreen, skipOffstage: false)).spec, same(LetterGameSpec.traceEnFromChooser));
  });

  testWidgets('the house button says go_home and returns', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.tap(find.text('🏠'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Về lâu đài nào!'));
    expect(find.byType(TraceChooserScreen), findsNothing);
  });

  testWidgets('the back gesture says go_home', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Về lâu đài nào!'));
    expect(find.byType(TraceChooserScreen), findsNothing);
  });

  testWidgets('home ✏️ names the game and opens the chooser', (tester) async {
    final tts = await pumpHomeToChooser(tester);
    expect(tts.texts, contains('Tô chữ'));
    expect(find.byType(TraceChooserScreen), findsOneWidget);
    expect(find.byType(TraceScreen), findsNothing);
  });

  testWidgets('the home button inside either game returns to the home screen, skipping the chooser', (tester) async {
    for (final button in ['🔤', '🔢']) {
      final tts = await pumpHomeToChooser(tester);
      await tester.tap(find.text(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(TraceScreen), findsOneWidget, reason: button);
      await tester.tap(find.text('🏠'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TraceScreen), findsNothing, reason: button);
      expect(find.byType(TraceChooserScreen), findsNothing, reason: button);
      expect(find.byType(HomeScreen), findsOneWidget, reason: button);
      expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1), reason: button);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('the back gesture inside either game also returns to the home screen', (tester) async {
    for (final button in ['🔤', '🔢']) {
      final tts = await pumpHomeToChooser(tester);
      await tester.tap(find.text(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TraceChooserScreen), findsNothing, reason: button);
      expect(find.byType(HomeScreen), findsOneWidget, reason: button);
      expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1), reason: button);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('the reward ✅ after an English letters round goes home, not back to the chooser', (tester) async {
    final tts = await pumpHomeToChooser(tester);
    await tester.tap(find.text('🔤'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      final letter = content.lettersEn.firstWhere((l) => l.char == asked(tts).last);
      for (final s in letter.strokes) {
        await drawPoints(tester, s.sample(step: 0.05));
      }
      // The English game keeps its example card.
      expect(find.text(letter.exampleWord), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    await tester.tap(find.text('✅'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RewardScreen), findsNothing);
    expect(find.byType(TraceChooserScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('fits a 360x640 phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpChooser(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('🔤'), findsOneWidget);
    expect(find.text('🔢'), findsOneWidget);
  });
}
