import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/app/theme.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/games/trace/tone_face.dart';
import 'package:xoai_castle/features/games/trace/tone_trace.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import 'trace_screen_test.dart' show drawPoints;

final _prompt = RegExp(r'^Mình cùng tô dấu (.+) nào!$');
final _done = RegExp(r'^Giỏi quá! (.), (.+), (.)!$');

void main() {
  late ContentBundle content;
  setUpAll(() async => content = await ContentRepository(FileContentSource('content')).load());

  ToneItem byName(String name) => content.tones.firstWhere((t) => t.name == name);

  /// The tone names asked so far, in order.
  List<String> asked(FakeTts tts) => [for (final t in tts.texts) if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!];

  Future<void> open(WidgetTester tester, FakeTts tts, {MemorySessionStore? sessions, MemoryItemStatsStore? stats}) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const TraceScreen(spec: LetterGameSpec.traceTones),
      rewards: MemoryRewardStore(),
      sessions: sessions,
      itemStats: stats,
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> trace(WidgetTester tester, ToneItem tone) async {
    for (final s in tone.strokes) {
      await drawPoints(tester, s.sample(step: 0.05));
    }
  }

  Color? tileColor(WidgetTester tester, String id) {
    final box = tester.widget<Container>(find.byKey(Key('tone-tile-$id')));
    return (box.decoration! as BoxDecoration).color;
  }

  testWidgets('a round: ten tones (each twice, never in a row), bases A E O U I, the card, then the reward', (tester) async {
    final tts = FakeTts();
    final sessions = MemorySessionStore();
    final stats = MemoryItemStatsStore();
    await open(tester, tts, sessions: sessions, stats: stats);
    const bases = ['a', 'e', 'o', 'u', 'i'];
    for (var i = 0; i < 10; i++) {
      final names = asked(tts);
      expect(names, hasLength(i + 1), reason: 'tone ${i + 1}');
      final tone = byName(names.last);
      expect(tts.texts.last, 'Mình cùng tô dấu ${tone.name} nào!');
      // The row of five marks shows the one being traced filled in.
      for (final t in content.tones) {
        expect(tileColor(tester, t.id), t.id == tone.id ? IceColors.deep : Colors.white.withValues(alpha: 0.7), reason: '${t.id} at ${i + 1}');
      }
      await trace(tester, tone);
      final base = bases[i % 5];
      final item = ToneTraceItem(tone, base: base);
      expect(tts.texts.last, 'Giỏi quá! $base, ${tone.name}, ${item.combined}!');
      // The card: "A + ´ = Á" and "dấu sắc" under it, no row of every combined letter.
      expect(find.byKey(const Key('tone-face')), findsOneWidget);
      final card = find.byKey(const Key('tone-face'));
      expect(find.descendant(of: card, matching: find.text(base.toUpperCase())), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(tone.mark)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(item.combinedUpper)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('dấu ${tone.name}')), findsOneWidget);
      for (final other in content.tones.where((t) => t.id != tone.id)) {
        expect(find.text(ToneTraceItem(other, base: base).combinedUpper), findsNothing, reason: 'no hint row');
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    final names = asked(tts);
    for (final t in content.tones) {
      expect(names.where((n) => n == t.name), hasLength(2), reason: t.name);
    }
    for (var i = 1; i < names.length; i++) {
      expect(names[i], isNot(names[i - 1]), reason: '$names');
    }
    final doneBases = [for (final t in tts.texts) if (_done.hasMatch(t)) _done.firstMatch(t)![1]!];
    expect(doneBases, ['a', 'e', 'o', 'u', 'i', 'a', 'e', 'o', 'u', 'i']);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+15 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'trace_tone');
    expect(sessions.records.single.total, 10);
    expect(stats.stats.keys.toSet(), {for (final t in content.tones) 'trace_tone:${t.id}'});
  });

  testWidgets('the start dot carries no stroke number (each mark is one stroke)', (tester) async {
    await open(tester, FakeTts());
    final guide = tester.renderObject(
      find.descendant(of: find.byKey(const Key('trace-guide')), matching: find.byType(CustomPaint)),
    );
    expect(guide, paints..circle());
    expect(guide, isNot(paints..paragraph()));
    expect(LetterGameSpec.traceTones.strokeNumbers, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a wrong stroke says the Vietnamese try-again line', (tester) async {
    final tts = FakeTts();
    await open(tester, tts);
    final rect = tester.getRect(find.byKey(const Key('trace-pad')));
    final g = await tester.startGesture(rect.topLeft + Offset(rect.width * 0.05, rect.height * 0.05));
    await g.moveTo(rect.topLeft + Offset(rect.width * 0.3, rect.height * 0.05));
    await g.up();
    await tester.pump();
    expect(tts.texts.last, 'Thử lại nha con!');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('fits a 360x640 phone: tiles, pad and card on screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tts = FakeTts();
    await open(tester, tts);
    expect(tester.takeException(), isNull);
    const screen = Rect.fromLTWH(0, 0, 360, 640);
    for (final t in content.tones) {
      final tile = tester.getRect(find.byKey(Key('tone-tile-${t.id}')));
      expect(screen.intersect(tile), tile, reason: t.id);
      expect(tile.width, closeTo(50, 0.01));
    }
    final pad = tester.getRect(find.byKey(const Key('trace-pad')));
    expect(pad.width, greaterThanOrEqualTo(280));
    expect(screen.intersect(pad), pad);
    await trace(tester, byName(asked(tts).last));
    expect(tts.texts, isNot(contains('Thử lại nha con!')));
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byKey(const Key('tone-face')));
    expect(screen.intersect(card), card);
    await tester.pump(const Duration(seconds: 2));
  });

  group('ToneFace', () {
    testWidgets('A + ´ = Á with "dấu sắc" under it', (tester) async {
      final sac = content.tones.first;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ToneFace(ToneTraceItem(sac, base: 'a'))))));
      await tester.pump(const Duration(milliseconds: 400));
      for (final s in ['A', '+', '´', '=', 'Á', 'dấu sắc']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
    });

    testWidgets('Ị for nặng on i', (tester) async {
      final nang = content.tones.last;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ToneFace(ToneTraceItem(nang, base: 'i'))))));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('I'), findsOneWidget);
      expect(find.text('Ị'), findsOneWidget);
      expect(find.text('dấu nặng'), findsOneWidget);
    });
  });
}
