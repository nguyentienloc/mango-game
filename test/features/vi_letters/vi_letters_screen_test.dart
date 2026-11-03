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
  });
}
