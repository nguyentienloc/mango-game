import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/app/theme.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';
import 'package:xoai_castle/features/games/trace/trace_pad.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

final _prompt = RegExp(r"^Let's write (\w)!$");

List<String> asked(FakeTts tts) => [
  for (final t in tts.texts)
    if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!,
];

Future<void> drawPoints(WidgetTester tester, List<TracePoint> pts) async {
  final rect = tester.getRect(find.byKey(const Key('trace-pad')));
  Offset at(TracePoint p) =>
      rect.topLeft + Offset(p.x * rect.width, p.y * rect.height);
  final g = await tester.startGesture(at(pts.first));
  for (final p in pts.skip(1)) {
    await g.moveTo(at(p));
  }
  await g.up();
  await tester.pump();
}

void main() {
  late ContentBundle content;
  setUpAll(
    () async =>
        content = await ContentRepository(FileContentSource('content')).load(),
  );

  LetterItem letter(String c) =>
      content.lettersEn.firstWhere((l) => l.char == c);

  testWidgets(
    'tracing every stroke of ten letters ends on the reward screen',
    (tester) async {
      final tts = FakeTts();
      final rewards = MemoryRewardStore();
      final sessions = MemorySessionStore();
      await tester.pumpWidget(
        testApp(
          content: content,
          tts: tts,
          home: const TraceScreen(),
          rewards: rewards,
          sessions: sessions,
        ),
      );
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        final c = asked(tts);
        expect(c, hasLength(i + 1), reason: 'letter ${i + 1}');
        for (final s in letter(c.last).strokes) {
          await drawPoints(tester, s.sample(step: 0.05));
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(RewardScreen), findsOneWidget);
      expect(find.text('+15 ❄️'), findsOneWidget);
      expect(sessions.records.single.game, 'trace');
    },
  );

  group('progress dots', () {
    // The dots in order, as (fill, ring colour or null).
    List<(Color?, Color?)> dots(WidgetTester tester) => [
      for (final d in tester.widgetList<Container>(find.byKey(const Key('trace-progress-dot'))))
        (
          (d.decoration! as BoxDecoration).color,
          ((d.decoration! as BoxDecoration).border as Border?)?.top.color,
        ),
    ];

    testWidgets('ten dots under the top bar: current has an orange ring, done are deep blue, the rest faint', (tester) async {
      final tts = FakeTts();
      await tester.pumpWidget(testApp(content: content, tts: tts, home: const TraceScreen()));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('trace-progress-dot')), findsNWidgets(10));
      final first = dots(tester);
      expect(first[0], (Colors.white, const Color(0xFFFFB74D)));
      for (final d in first.skip(1)) {
        expect(d.$1, Colors.white.withValues(alpha: 0.7));
        expect(d.$2, isNull);
      }
      final size = tester.getSize(find.byKey(const Key('trace-progress-dot')).first);
      expect(size, const Size(22, 22));
      expect(tester.getRect(find.byKey(const Key('trace-progress-dot')).at(1)).left - tester.getRect(find.byKey(const Key('trace-progress-dot')).first).right, 6);
      final ring = tester.widget<Container>(find.byKey(const Key('trace-progress-dot')).first).decoration! as BoxDecoration;
      expect((ring.border! as Border).top.width, 3);
      // under the top bar, above the writing pad
      expect(tester.getRect(find.byKey(const Key('trace-progress-dot')).first).top, greaterThan(tester.getRect(find.text('🏠')).bottom - 1));
      expect(tester.getRect(find.byKey(const Key('trace-progress-dot')).first).bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const Key('trace-pad'))).top));

      for (final s in letter(asked(tts).last).strokes) {
        await drawPoints(tester, s.sample(step: 0.05));
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      final second = dots(tester);
      expect(second[0], (IceColors.deep, null));
      expect(second[1], (Colors.white, const Color(0xFFFFB74D)));
      for (final d in second.skip(2)) {
        expect(d.$1, Colors.white.withValues(alpha: 0.7));
      }
      expect(find.text('2/10'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('a stroke drawn in the wrong place says try again and stays', (
    tester,
  ) async {
    final tts = FakeTts();
    await tester.pumpWidget(
      testApp(content: content, tts: tts, home: const TraceScreen()),
    );
    await tester.pump();
    await tester.pump();
    await drawPoints(tester, [
      for (var i = 0; i <= 20; i++) TracePoint(0.02 + i * 0.0125, 0.98),
    ]);
    expect(
      tts.texts.where((t) => t == 'Try again!' || t == 'Thử lại nha con!'),
      hasLength(1),
    );
    expect(asked(tts), hasLength(1));
  });

  testWidgets('a jittery tap is not a stroke: no try again and no failure', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const TraceScreen()));
    await tester.pump();
    await tester.pump();
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    for (var i = 0; i < 4; i++) {
      final g = await tester.startGesture(rect.center);
      await g.moveBy(const Offset(2, 1));
      await g.up();
      await tester.pump();
    }
    expect(tts.texts.where((t) => t == 'Try again!' || t == 'Thử lại nha con!'), isEmpty);
    expect(asked(tts), hasLength(1));
  });

  padTests();

  testWidgets('keeps clear of the Android back-gesture zone at the screen edges', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        content: content,
        tts: FakeTts(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(systemGestureInsets: const EdgeInsets.symmetric(horizontal: 40)),
            child: const TraceScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final pad = tester.getRect(find.byKey(const Key('trace-pad')));
    expect(pad.left, greaterThanOrEqualTo(48));
    expect(360 - pad.right, greaterThanOrEqualTo(48));
  });

  testWidgets('after five failures the next drawing completes the stroke without try again', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const TraceScreen()));
    await tester.pump();
    await tester.pump();
    bool isTryAgain(String t) => t == 'Try again!' || t == 'Thử lại nha con!';
    final wrong = [for (var i = 0; i <= 20; i++) TracePoint(0.02 + i * 0.0125, 0.98)];
    for (var i = 0; i < 5; i++) {
      await drawPoints(tester, wrong);
      expect(tts.texts.where(isTryAgain), hasLength(i + 1));
    }
    await drawPoints(tester, wrong);
    expect(tts.texts.where(isTryAgain), hasLength(5));
    // The helped stroke counted: either the next stroke is current or the letter is done.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tts.texts.where(isTryAgain), hasLength(5));
  });

  testWidgets('fits a 360x640 phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(content: content, tts: FakeTts(), home: const TraceScreen()),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final pad = tester.getRect(find.byKey(const Key('trace-pad')));
    expect(pad.width, greaterThanOrEqualTo(280));
  });
}

Future<void> pumpPad(WidgetTester tester, ValueChanged<List<TracePoint>> onStroke) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 300,
          child: TracePad(strokes: const [], current: 0, onStrokeDrawn: onStroke),
        ),
      ),
    ),
  ),
);

void padTests() {
  testWidgets(
    'the first recorded point is the touch-down point, not the slop-shifted one',
    (tester) async {
      List<TracePoint>? got;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 300,
                child: TracePad(
                  strokes: const [],
                  current: 0,
                  onStrokeDrawn: (d) => got = d,
                ),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const Key('trace-pad')));
      final start = rect.topLeft + Offset(rect.width * 0.2, rect.height * 0.3);
      final g = await tester.startGesture(start);
      await g.moveTo(start + Offset(rect.width * 0.3, 0));
      await g.moveTo(start + Offset(rect.width * 0.5, 0));
      await g.up();
      await tester.pump();
      expect(got, isNotNull);
      expect(got!.first.x, closeTo(0.2, 0.005));
      expect(got!.first.y, closeTo(0.3, 0.005));
    },
  );

  testWidgets('a second finger is ignored while one is drawing', (
    tester,
  ) async {
    final strokes = <List<TracePoint>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 300,
              child: TracePad(
                strokes: const [],
                current: 0,
                onStrokeDrawn: strokes.add,
              ),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    final g1 = await tester.startGesture(
      rect.topLeft + const Offset(30, 30),
      pointer: 1,
    );
    await g1.moveTo(rect.topLeft + const Offset(60, 30)); // clearly drawing
    final g2 = await tester.startGesture(
      rect.topLeft + const Offset(250, 250),
      pointer: 2,
    );
    await g2.moveTo(rect.topLeft + const Offset(250, 100));
    await g2.up();
    await g1.moveTo(rect.topLeft + const Offset(100, 30));
    await g1.up();
    await tester.pump();
    expect(strokes, hasLength(1));
    expect(strokes.single.last.x, closeTo(100 / 300, 0.005));
  });

  testWidgets('a resting palm that has barely moved hands the stroke to the next finger', (tester) async {
    final strokes = <List<TracePoint>>[];
    await pumpPad(tester, strokes.add);
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    final palm = await tester.startGesture(rect.topLeft + const Offset(250, 250), pointer: 1);
    await palm.moveBy(const Offset(2, 1)); // well under 0.04 of the side
    final finger = await tester.startGesture(rect.topLeft + const Offset(30, 30), pointer: 2);
    await finger.moveTo(rect.topLeft + const Offset(150, 30));
    await finger.up();
    await palm.up();
    await tester.pump();
    expect(strokes, hasLength(1));
    expect(strokes.single.first.x, closeTo(30 / 300, 0.005));
    expect(strokes.single.last.x, closeTo(150 / 300, 0.005));
  });

  testWidgets('the guide layer does not repaint while the finger moves; the ink layer does', (tester) async {
    await pumpPad(tester, (_) {});
    await tester.pump();
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    final guide = tester.renderObject(find.byKey(const Key('trace-guide')));
    final ink = tester.renderObject(find.byKey(const Key('trace-ink')));
    expect(guide.debugNeedsPaint, isFalse);
    expect(ink.debugNeedsPaint, isFalse);
    final g = await tester.startGesture(rect.topLeft + const Offset(30, 30));
    await g.moveTo(rect.topLeft + const Offset(80, 30));
    expect(ink.debugNeedsPaint, isTrue);
    expect(guide.debugNeedsPaint, isFalse);
    await g.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a finished stroke fades out over about 300 ms and never blocks a new touch', (tester) async {
    final strokes = <List<TracePoint>>[];
    await pumpPad(tester, strokes.add);
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    TraceInkPainter painter() => tester
        .widget<CustomPaint>(find.descendant(of: find.byKey(const Key('trace-ink')), matching: find.byType(CustomPaint)))
        .painter! as TraceInkPainter;

    final g = await tester.startGesture(rect.topLeft + const Offset(30, 30));
    await g.moveTo(rect.topLeft + const Offset(150, 30));
    await g.up();
    await tester.pump();
    expect(painter().fadeOpacity, 1.0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(painter().fadeOpacity, allOf(greaterThan(0.0), lessThan(1.0)));

    // A new touch right now starts a new stroke immediately.
    final g2 = await tester.startGesture(rect.topLeft + const Offset(30, 90));
    await g2.moveTo(rect.topLeft + const Offset(150, 90));
    await g2.up();
    await tester.pump();
    expect(strokes, hasLength(2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(painter().fadeOpacity, 0.0);
  });

  testWidgets('the live ink is a deep saturated blue (not the pale ice) with a lighter glow under it', (tester) async {
    await pumpPad(tester, (_) {});
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    final ink = find.descendant(of: find.byKey(const Key('trace-ink')), matching: find.byType(CustomPaint));
    final g = await tester.startGesture(rect.topLeft + const Offset(30, 30));
    await g.moveTo(rect.topLeft + const Offset(150, 30));
    await tester.pump();
    final side = rect.width;
    expect(
      tester.renderObject(ink),
      paints
        ..path(color: IceColors.ice.withValues(alpha: 0.7)) // soft glow, lighter than the ink
        ..path(color: const Color(0xFF1565C0), strokeWidth: 0.075 * side),
    );
    await g.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('completed strokes are drawn in a navy darker than the live ink', (tester) async {
    const doneInk = Color(0xFF0D2B5C);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 300,
              child: TracePad(
                strokes: const [
                  [TracePoint(0.2, 0.2), TracePoint(0.2, 0.8)],
                  [TracePoint(0.5, 0.2), TracePoint(0.8, 0.8)],
                ],
                current: 1,
                onStrokeDrawn: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final guide = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_GuidePainter');
    expect(tester.renderObject(guide), paints..path(color: doneInk));
    expect(doneInk.computeLuminance(), lessThan(const Color(0xFF1565C0).computeLuminance()));
  });

  testWidgets('the fading ink keeps the live colour, which differs from the navy of completed strokes', (tester) async {
    await pumpPad(tester, (_) {});
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    final ink = find.descendant(of: find.byKey(const Key('trace-ink')), matching: find.byType(CustomPaint));
    final g = await tester.startGesture(rect.topLeft + const Offset(30, 30));
    await g.moveTo(rect.topLeft + const Offset(150, 30));
    await g.up();
    await tester.pump();
    expect(tester.renderObject(ink), paints..path()..path(color: const Color(0xFF1565C0), strokeWidth: 0.075 * rect.width));
    expect(const Color(0xFF1565C0), isNot(IceColors.deep));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a tap with a tiny jitter does not report a stroke', (tester) async {
    final strokes = <List<TracePoint>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 300,
            child: TracePad(strokes: const [], current: 0, onStrokeDrawn: strokes.add),
          ),
        ),
      ),
    ));
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    final g = await tester.startGesture(rect.center);
    await g.moveBy(const Offset(1, 2));
    await g.up();
    await tester.pump();
    expect(strokes, isEmpty);
  });

  testWidgets('a cancelled pointer reports nothing and the next stroke works', (tester) async {
    final strokes = <List<TracePoint>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 300,
            child: TracePad(strokes: const [], current: 0, onStrokeDrawn: strokes.add),
          ),
        ),
      ),
    ));
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    final g = await tester.startGesture(rect.topLeft + const Offset(30, 30));
    await g.moveTo(rect.topLeft + const Offset(150, 30));
    await g.cancel();
    await tester.pump();
    expect(strokes, isEmpty);
    final g2 = await tester.startGesture(rect.topLeft + const Offset(30, 60));
    await g2.moveTo(rect.topLeft + const Offset(150, 60));
    await g2.up();
    await tester.pump();
    expect(strokes, hasLength(1));
  });
}
