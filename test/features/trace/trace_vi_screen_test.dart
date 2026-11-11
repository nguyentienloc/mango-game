import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/core/content/strokes.dart';
import 'package:xoai_castle/features/games/vi_letters/vi_letters_screen.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import 'trace_screen_test.dart' show drawPoints;

final _prompt = RegExp(r'^Mình cùng viết chữ (.+) nào!$');

void main() {
  late ContentBundle content;
  setUpAll(() async => content = await ContentRepository(FileContentSource('content')).load());

  LetterItem bySpoken(String spoken) => content.lettersVi.firstWhere((l) => l.spoken == spoken);

  List<String> asked(FakeTts tts) => [for (final t in tts.texts) if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!];

  Future<void> open(WidgetTester tester, FakeTts tts, {MemorySessionStore? sessions, MemoryItemStatsStore? stats, int voiceSeed = 1}) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const TraceScreen(spec: LetterGameSpec.traceVi),
      rewards: MemoryRewardStore(),
      sessions: sessions,
      itemStats: stats,
      voiceSeed: voiceSeed,
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('tracing ten Vietnamese letters (accents included) ends on the reward screen', (tester) async {
    final tts = FakeTts();
    final sessions = MemorySessionStore();
    final stats = MemoryItemStatsStore();
    await open(tester, tts, sessions: sessions, stats: stats);
    for (var i = 0; i < 10; i++) {
      final c = asked(tts);
      expect(c, hasLength(i + 1), reason: 'letter ${i + 1}');
      final letter = bySpoken(c.last);
      for (final s in letter.strokes) {
        await drawPoints(tester, s.sample(step: 0.05));
      }
      // Done: no example card, a big letter and the spoken name instead.
      expect(find.byKey(const Key('trace-done-letter')), findsOneWidget);
      expect(find.text(letter.char), findsWidgets);
      expect(tts.texts.last, 'Giỏi quá! Chữ ${letter.spoken}!');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+15 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'trace_vi');
    expect(stats.stats, hasLength(10));
    expect(stats.stats.keys.every((k) => k.startsWith('trace_vi_upper:')), isTrue);
  });

  testWidgets('a wrong stroke always says the Vietnamese try-again, never the English one', (tester) async {
    // Several voice seeds, so a random pick from the whole try_again group would show up.
    for (var seed = 1; seed <= 8; seed++) {
      final tts = FakeTts();
      await open(tester, tts, voiceSeed: seed);
      for (var i = 0; i < 2; i++) {
        await drawPoints(tester, [for (var k = 0; k <= 20; k++) TracePoint(0.02 + k * 0.0125, 0.98)]);
        expect(tts.texts.last, 'Thử lại nha con!', reason: 'seed $seed attempt ${i + 1}');
      }
      expect(tts.texts.where((t) => t == 'Try again!'), isEmpty, reason: 'seed $seed');
      expect(tts.texts.where((t) => t == 'Thử lại nha con!'), hasLength(2), reason: 'seed $seed');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('the reward ✅ after a Vietnamese round goes home, not back to the chooser', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const HomeScreen(), rewards: MemoryRewardStore()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('🇻🇳'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('✏️'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 10; i++) {
      final letter = bySpoken(asked(tts).last);
      for (final s in letter.strokes) {
        await drawPoints(tester, s.sample(step: 0.05));
      }
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
    expect(find.byType(VietnameseLettersScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('every Vietnamese letter, accented ones included, can be traced along its own strokes', (tester) async {
    for (final letter in content.lettersVi) {
      final tts = FakeTts();
      await tester.pumpWidget(testApp(
        content: content,
        tts: tts,
        home: _Single(letter),
        rewards: MemoryRewardStore(),
      ));
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < letter.strokes.length; i++) {
        await drawPoints(tester, letter.strokes[i].sample(step: 0.05));
      }
      expect(tts.texts.where((t) => t == 'Thử lại nha con!'), isEmpty, reason: letter.char);
      expect(tts.texts.last, 'Giỏi quá! Chữ ${letter.spoken}!', reason: letter.char);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }
  });
}

/// A trace screen whose round is one given letter: a bundle whose Vietnamese pack has only it.
class _Single extends StatelessWidget {
  const _Single(this.letter);

  final LetterItem letter;

  @override
  Widget build(BuildContext context) => TraceScreen(
        spec: LetterGameSpec(
          letters: (_) => [letter],
          keyPrefix: 'trace_vi_upper',
          sessionGame: 'trace_vi',
          promptId: 'vi_trace_prompt',
          doneId: 'vi_trace_done',
          vars: LetterGameSpec.traceVi.vars,
          showExampleCard: false,
        ),
      );
}
