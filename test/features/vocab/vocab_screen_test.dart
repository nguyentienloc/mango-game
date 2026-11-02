import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/vocab/vocab_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

final _prompt = RegExp(r'^Find the (.+)!$');

List<String> asked(FakeTts tts) => [
      for (final t in tts.texts)
        if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!,
    ];

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  String idFor(String word) => content.vocab.firstWhere((w) => w.word == word).id;

  testWidgets('a full round of correct taps ends on the reward screen', (tester) async {
    final tts = FakeTts();
    final sessions = MemorySessionStore();
    final rewards = MemoryRewardStore();
    final stats = MemoryItemStatsStore();
    await tester.pumpWidget(testApp(
        content: content, tts: tts, home: const VocabScreen(), sessions: sessions, rewards: rewards, itemStats: stats));
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 8; i++) {
      final words = asked(tts);
      expect(words, hasLength(i + 1), reason: 'question ${i + 1}');
      await tester.tap(find.byKey(Key('card-${idFor(words.last)}')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+13 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'vocab');
    expect(stats.stats, isNotEmpty);
    expect(stats.stats.keys.every((k) => k.startsWith('word:')), isTrue);
  });

  testWidgets('a correct tap says the English word then the Vietnamese meaning', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const VocabScreen()));
    await tester.pump();
    await tester.pump();
    final word = asked(tts).single;
    final item = content.vocab.firstWhere((w) => w.word == word);
    await tester.tap(find.byKey(Key('card-${item.id}')));
    await tester.pump();
    final capital = word[0].toUpperCase() + word.substring(1);
    final vi = item.vi[0].toUpperCase() + item.vi.substring(1);
    expect(tts.spoken, containsAllInOrder([(text: '$capital!', lang: 'en'), (text: '$vi!', lang: 'vi')]));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('two wrong taps light up the right card and give the hint', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const VocabScreen()));
    await tester.pump();
    await tester.pump();
    final word = asked(tts).single;
    final item = content.vocab.firstWhere((w) => w.word == word);
    final wrongCard = find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('card-') && (w.key! as ValueKey<String>).value != 'card-${item.id}');
    await tester.tap(wrongCard.first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(wrongCard.first);
    await tester.pump(const Duration(milliseconds: 500));
    final vi = item.vi[0].toUpperCase() + item.vi.substring(1);
    expect(tts.texts, contains('$vi ở đây nè!'));
    expect(find.byKey(Key('glow-${item.id}')), findsOneWidget);
  });

  testWidgets('fits a 360x640 phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const VocabScreen()));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the system back gesture says go_home and leaves the game', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VocabScreen())),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(VocabScreen), findsOneWidget);
    expect(tts.texts, isNot(contains('Về lâu đài nào!')));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VocabScreen), findsNothing);
    expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1));
  });

  testWidgets('the home button says go_home only once', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VocabScreen())),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('🏠'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VocabScreen), findsNothing);
    expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1));
  });
}
