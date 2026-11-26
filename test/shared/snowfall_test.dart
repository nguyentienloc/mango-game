import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/app/animation_flags.dart';
import 'package:xoai_castle/app/app.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/shared/snowfall.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

/// An app like XoaiApp's shell: the snow builder, a first page that pushes a second one.
Widget _app({required bool snow, VoidCallback? onSecondTap}) => ProviderScope(
      overrides: [snowfallEnabledProvider.overrideWithValue(snow)],
      child: MaterialApp(
        builder: noelAppBuilder,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('push'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Center(
                        child: ElevatedButton(key: const Key('second'), onPressed: onSecondTap, child: const Text('second')),
                      ),
                    ),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );

SnowfallPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(of: find.byKey(kSnowfallKey), matching: find.byType(CustomPaint)))
    .painter! as SnowfallPainter;

void main() {
  testWidgets('snow falls over pushed routes, above the navigator, and never takes a tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(snow: true, onSecondTap: () => taps++));
    expect(find.byKey(kSnowfallKey), findsOneWidget);

    await tester.tap(find.byKey(const Key('push')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('second')), findsOneWidget);
    // One snow layer for the whole app, outside (so above) every route.
    expect(find.byKey(kSnowfallKey), findsOneWidget);
    expect(find.descendant(of: find.byType(Navigator), matching: find.byKey(kSnowfallKey)), findsNothing);
    expect(tester.widget(find.byKey(kSnowfallKey)), isA<IgnorePointer>());

    await tester.tap(find.byKey(const Key('second')));
    expect(taps, 1);

    // It moves: the painter's clock advances with the frames.
    final before = _painter(tester).time.value;
    await tester.pump(const Duration(seconds: 1));
    expect(_painter(tester).time.value, greaterThan(before));

    // Dialogs get it too (they live under the same navigator).
    showDialog<void>(context: tester.element(find.byKey(const Key('second'))), builder: (_) => const AlertDialog(content: Text('hi')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('hi'), findsOneWidget);
    expect(find.byKey(kSnowfallKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no snow when the flag is off, and nothing keeps ticking', (tester) async {
    await tester.pumpWidget(_app(snow: false));
    expect(find.byKey(kSnowfallKey), findsNothing);
    await tester.tap(find.byKey(const Key('push')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('second')), findsOneWidget);
    expect(find.byKey(kSnowfallKey), findsNothing);
  });

  testWidgets('no snow when the system asks for no animations', (tester) async {
    Widget overlay(bool disable) => ProviderScope(
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: disable),
            child: const SnowfallOverlay(child: SizedBox.expand()),
          ),
        );
    await tester.pumpWidget(overlay(false));
    expect(find.byKey(kSnowfallKey), findsOneWidget);
    await tester.pumpWidget(overlay(true));
    expect(find.byKey(kSnowfallKey), findsNothing);
  });

  group('the app', () {
    late ContentBundle content;

    setUpAll(() async {
      content = await ContentRepository(FileContentSource('content')).load();
    });

    testWidgets('XoaiApp has the snow when animations are on', (tester) async {
      await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const XoaiApp(), animations: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(kSnowfallKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('testApp turns it off', (tester) async {
      await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const XoaiApp()));
      await tester.pump();
      expect(find.byKey(kSnowfallKey), findsNothing);
    });
  });

  group('the snow clock', () {
    tearDown(() => WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

    Widget overlay(ValueNotifier<bool> paused) => ProviderScope(
          overrides: [
            snowfallEnabledProvider.overrideWithValue(true),
            snowfallPausedProvider.overrideWithValue(paused),
          ],
          child: const MaterialApp(builder: noelAppBuilder, home: SizedBox.expand()),
        );

    testWidgets('moves about 30 times a second, not on every vsync', (tester) async {
      final paused = ValueNotifier(false);
      addTearDown(paused.dispose);
      await tester.pumpWidget(overlay(paused));
      var steps = 0;
      _painter(tester).time.addListener(() => steps++);
      await tester.pump(const Duration(seconds: 1));
      expect(steps, inInclusiveRange(25, 35));
      // Nothing waits for the next vsync between two snow steps.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stops while the app is hidden, goes on when it is back', (tester) async {
      final paused = ValueNotifier(false);
      addTearDown(paused.dispose);
      await tester.pumpWidget(overlay(paused));
      await tester.pump(const Duration(milliseconds: 500));
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      final stopped = _painter(tester).time.value;
      await tester.pump(const Duration(seconds: 2));
      expect(_painter(tester).time.value, stopped);
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).time.value, greaterThan(stopped));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stops while a story plays (the pause flag), goes on after', (tester) async {
      final paused = ValueNotifier(false);
      addTearDown(paused.dispose);
      await tester.pumpWidget(overlay(paused));
      await tester.pump(const Duration(milliseconds: 500));
      paused.value = true;
      final stopped = _painter(tester).time.value;
      await tester.pump(const Duration(seconds: 2));
      expect(_painter(tester).time.value, stopped);
      expect(tester.binding.hasScheduledFrame, isFalse);
      paused.value = false;
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).time.value, greaterThan(stopped));
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('the flakes: 50 by default, a fifth of them six-armed crystals, slow and soft', () {
    final flakes = SnowFlake.generate(50, Random(2026));
    expect(flakes, hasLength(50));
    expect(flakes.where((f) => f.crystal), hasLength(10));
    for (final f in flakes) {
      expect(f.speed, inInclusiveRange(10, 50));
      expect(f.opacity, inInclusiveRange(0.3, 0.95));
      expect(f.x, inInclusiveRange(0, 1));
    }
  });

  test('the painter copes with any size', () {
    final painter = SnowfallPainter(SnowFlake.generate(50, Random(1)), ValueNotifier(12.5));
    for (final size in const [Size.zero, Size(1, 1), Size(10, 4), Size(360, 640), Size(2000, 30)]) {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), size);
      recorder.endRecording().dispose();
    }
  });
}
