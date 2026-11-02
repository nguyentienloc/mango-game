import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';
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
  Offset at(TracePoint p) => rect.topLeft + Offset(p.x * rect.width, p.y * rect.height);
  final g = await tester.startGesture(at(pts.first));
  for (final p in pts.skip(1)) {
    await g.moveTo(at(p));
  }
  await g.up();
  await tester.pump();
}

void main() {
  late ContentBundle content;
  setUpAll(() async => content = await ContentRepository(FileContentSource('content')).load());

  LetterItem letter(String c) => content.lettersEn.firstWhere((l) => l.char == c);

  testWidgets('tracing every stroke of three letters ends on the reward screen', (tester) async {
    final tts = FakeTts();
    final rewards = MemoryRewardStore();
    final sessions = MemorySessionStore();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const TraceScreen(), rewards: rewards, sessions: sessions));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 3; i++) {
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
    expect(find.text('+8 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'trace');
  });

  testWidgets('a stroke drawn in the wrong place says try again and stays', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const TraceScreen()));
    await tester.pump();
    await tester.pump();
    await drawPoints(tester, [for (var i = 0; i <= 20; i++) TracePoint(0.02 + i * 0.001, 0.02)]);
    expect(tts.texts.where((t) => t == 'Try again!' || t == 'Thử lại nha con!'), hasLength(1));
    expect(asked(tts), hasLength(1));
  });

  testWidgets('fits a 360x640 phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const TraceScreen()));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final pad = tester.getRect(find.byKey(const Key('trace-pad')));
    expect(pad.width, greaterThanOrEqualTo(280));
  });
}
