import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/balloon/balloon_screen.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/games/vi_letters/vi_letters_screen.dart';
import 'package:xoai_castle/features/home/home_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

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
    nav.push(MaterialPageRoute<void>(builder: (_) => const VietnameseLettersScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return tts;
  }

  testWidgets('the balloon button names the game and opens the Vietnamese balloon game', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.tap(find.text('🎈'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Đập bong bóng'));
    expect(tester.widget<BalloonScreen>(find.byType(BalloonScreen)).spec, same(LetterGameSpec.balloonVi));
  });

  testWidgets('the pencil button names the game and opens the Vietnamese tracing game', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.tap(find.text('✏️'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Tô chữ'));
    expect(tester.widget<TraceScreen>(find.byType(TraceScreen)).spec, same(LetterGameSpec.traceVi));
  });

  testWidgets('the á button names the game and opens tone-mark tracing', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.tap(find.text('á'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Tô dấu'));
    expect(tester.widget<TraceScreen>(find.byType(TraceScreen)).spec, same(LetterGameSpec.traceTones));
  });

  testWidgets('the á button shows a bold deep-blue letter, not an emoji', (tester) async {
    await pumpChooser(tester);
    final text = tester.widget<Text>(find.text('á'));
    expect(text.style?.color, const Color(0xFF1E5AA8));
    expect(text.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('a double tap opens only one game', (tester) async {
    final tts = GatedTts();
    await pumpChooser(tester, ttsOverride: tts);
    tts.release();
    // The game name is still being spoken, so the first tap has not pushed yet.
    await tester.tap(find.text('🎈'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('✏️'), warnIfMissed: false);
    await tester.tap(find.text('🎈'), warnIfMissed: false);
    for (var i = 0; i < 3; i++) {
      tts.release();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(BalloonScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(TraceScreen, skipOffstage: false), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BalloonScreen, skipOffstage: false), findsNothing);
    expect(find.byType(VietnameseLettersScreen), findsOneWidget);
  });

  testWidgets('the house button says go_home and returns', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.tap(find.text('🏠'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Về lâu đài nào!'));
    expect(find.byType(VietnameseLettersScreen), findsNothing);
  });

  testWidgets('the back gesture says go_home', (tester) async {
    final tts = await pumpChooser(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Về lâu đài nào!'));
    expect(find.byType(VietnameseLettersScreen), findsNothing);
  });

  testWidgets('the home button inside a game returns to the home screen, skipping the chooser', (tester) async {
    for (final button in ['🎈', '✏️', 'á']) {
      final tts = FakeTts();
      await tester.pumpWidget(testApp(content: content, tts: tts, home: const HomeScreen()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('🇻🇳'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.tap(find.text('🏠'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BalloonScreen), findsNothing, reason: button);
      expect(find.byType(TraceScreen), findsNothing, reason: button);
      expect(find.byType(VietnameseLettersScreen), findsNothing, reason: button);
      expect(find.byType(HomeScreen), findsOneWidget, reason: button);
      expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1), reason: button);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('the back gesture inside a game also returns to the home screen', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const HomeScreen()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('🇻🇳'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('🎈'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VietnameseLettersScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1));
  });

  testWidgets('home 🇻🇳 names the topic and opens the chooser', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const HomeScreen()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('🇻🇳'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Chữ cái tiếng Việt'));
    expect(find.byType(VietnameseLettersScreen), findsOneWidget);
  });

  testWidgets('fits a 360x640 phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpChooser(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('🎈'), findsOneWidget);
    expect(find.text('✏️'), findsOneWidget);
    expect(find.text('á'), findsOneWidget);
    for (final b in ['🎈', '✏️', 'á']) {
      final r = tester.getRect(find.text(b));
      expect(const Rect.fromLTWH(0, 0, 360, 640).intersect(r), r, reason: b);
      expect(r.center.dy, closeTo(tester.getCenter(find.text('🎈')).dy, 0.5), reason: '$b on the same row');
    }
  });
}
