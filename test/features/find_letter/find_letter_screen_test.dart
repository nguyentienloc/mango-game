import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/find_letter/find_letter_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

final _prompt = RegExp(r'^Find the letter (\w)!$');

List<String> prompts(FakeTts tts) => [
      for (final t in tts.texts)
        if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!,
    ];

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  testWidgets('a full round of correct taps saves progress and shows the reward', (tester) async {
    final tts = FakeTts();
    final stats = MemoryItemStatsStore();
    final sessions = MemorySessionStore();
    final rewards = MemoryRewardStore();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const FindLetterScreen(),
      itemStats: stats,
      sessions: sessions,
      rewards: rewards,
    ));
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 8; i++) {
      final asked = prompts(tts);
      expect(asked, hasLength(i + 1), reason: 'question ${i + 1} should have been asked');
      await tester.tap(find.text(asked.last));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+13 ❄️'), findsOneWidget);
    expect(rewards.state.snowflakesTotal, 13);
    expect(sessions.records.single.correct, 8);
    expect(sessions.records.single.game, 'find_letter');
    expect(stats.stats.values.fold<int>(0, (sum, s) => sum + s.correct), 8);
    expect(stats.stats.values.every((s) => s.mastery >= 1 && s.wrong == 0), isTrue);
    expect(tts.texts, contains('Hoàn thành rồi! Xoài giỏi quá!'));

    await tester.tap(find.text('✅'));
    await tester.pump();
    expect(tts.texts, contains('Về lâu đài nào!'));
  });

  testWidgets('a wrong tap says try again and lowers nothing yet', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const FindLetterScreen()));
    await tester.pump();
    await tester.pump();

    final answer = prompts(tts).single;
    final wrong = tester
        .widgetList<Text>(find.byKey(const Key('flake-letter')))
        .map((t) => t.data!)
        .firstWhere((l) => l != answer);
    await tester.tap(find.text(wrong));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tts.texts.where((t) => t == 'Try again!' || t == 'Thử lại nha con!'), hasLength(1));
    expect(prompts(tts), hasLength(1));
  });

  testWidgets('a storage failure sends the child back home', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      itemStats: FailingItemStatsStore(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FindLetterScreen())),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tts.texts, contains('Mình về lâu đài nha!'));
    expect(find.byType(FindLetterScreen), findsNothing);
  });
}
