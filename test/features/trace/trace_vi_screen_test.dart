import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../../support/vi_content.dart';
import 'trace_screen_test.dart' show drawPoints;

final _prompt = RegExp(r'^Mình cùng viết chữ (.+) nào!$');

void main() {
  late ContentBundle content;
  setUpAll(() async => content = withViLetterPhrases(await ContentRepository(FileContentSource('content')).load()));

  LetterItem bySpoken(String spoken) => content.lettersVi.firstWhere((l) => l.spoken == spoken);

  List<String> asked(FakeTts tts) => [for (final t in tts.texts) if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!];

  Future<void> open(WidgetTester tester, FakeTts tts, {MemorySessionStore? sessions, MemoryItemStatsStore? stats}) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const TraceScreen(spec: LetterGameSpec.traceVi),
      rewards: MemoryRewardStore(),
      sessions: sessions,
      itemStats: stats,
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('tracing three Vietnamese letters (accents included) ends on the reward screen', (tester) async {
    final tts = FakeTts();
    final sessions = MemorySessionStore();
    final stats = MemoryItemStatsStore();
    await open(tester, tts, sessions: sessions, stats: stats);
    for (var i = 0; i < 3; i++) {
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
    expect(find.text('+8 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'trace_vi');
    expect(stats.stats, hasLength(3));
    expect(stats.stats.keys.every((k) => k.startsWith('trace_vi_upper:')), isTrue);
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
