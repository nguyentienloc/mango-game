import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/balloon/balloon_field.dart';
import 'package:xoai_castle/features/games/balloon/balloon_screen.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

final _balloonKey = RegExp(r'^balloon-[^-]$');
final _prompt = RegExp(r'^Xoài tìm chữ (.+) nào!$');

late ContentBundle content;

String spokenOf(String char) => content.lettersVi.firstWhere((l) => l.char == char).spoken!;
String charOf(String spoken) => content.lettersVi.firstWhere((l) => l.spoken == spoken).char;

/// The letter (character) of the latest prompt.
String? target(FakeTts tts) {
  final m = tts.texts.map(_prompt.firstMatch).whereType<RegExpMatch>().lastOrNull;
  return m == null ? null : charOf(m[1]!);
}

int prompts(FakeTts tts) => tts.texts.where(_prompt.hasMatch).length;

List<String> letters(WidgetTester tester) => [
      for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && _balloonKey.hasMatch((w.key! as ValueKey<String>).value)).evaluate())
        (e.widget.key! as ValueKey<String>).value.substring(8),
    ];

Future<void> run(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 20).round(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Rect _oval(Rect box) {
  final d = box.width - 24;
  return Rect.fromLTWH(box.left + 12, box.top + 12, d, d * 1.15);
}

Offset? pointFor(WidgetTester tester, String letter) {
  final all = {for (final l in letters(tester)) l: tester.getRect(find.byKey(Key('balloon-$l')))};
  final box = all[letter];
  if (box == null) return null;
  final oval = _oval(box);
  final field = tester.getRect(find.byType(BalloonField)).deflate(6);
  for (final f in [0.5, 0.4, 0.6, 0.3, 0.7]) {
    final p = Offset(oval.center.dx, oval.top + oval.height * f);
    if (!field.contains(p)) continue;
    if (all.entries.any((e) => e.key != letter && e.value.contains(p))) continue;
    return p;
  }
  return null;
}

Future<bool> tapBalloon(WidgetTester tester, String letter, {int steps = 150}) async {
  for (var step = 0; step < steps; step++) {
    final p = pointFor(tester, letter);
    if (p != null) {
      await tester.tapAt(p);
      await tester.pump();
      return true;
    }
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }
  return false;
}

/// Pops some balloon that is not [goal], waiting until one is in reach; returns its letter.
Future<String?> tapAnyWrong(WidgetTester tester, String goal) async {
  for (var step = 0; step < 150; step++) {
    for (final l in letters(tester).where((l) => l != goal)) {
      if (await tapBalloon(tester, l, steps: 1)) return l;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return null;
}

void main() {
  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<void> start(WidgetTester tester, FakeTts tts, {MemorySessionStore? sessions, MemoryItemStatsStore? stats}) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const BalloonScreen(spec: LetterGameSpec.balloonVi),
      sessions: sessions,
      rewards: MemoryRewardStore(),
      itemStats: stats,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a full round of correct pops ends on the reward screen, with Vietnamese keys and session', (tester) async {
    final tts = FakeTts();
    final sessions = MemorySessionStore();
    final stats = MemoryItemStatsStore();
    await start(tester, tts, sessions: sessions, stats: stats);

    for (var i = 0; i < 5; i++) {
      expect(prompts(tts), i + 1, reason: 'question ${i + 1}');
      final letter = target(tts)!;
      expect(await tapBalloon(tester, letter), isTrue, reason: 'balloon $letter');
      await run(tester, 1);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await run(tester, 2);

    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+10 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'balloon_vi');
    expect(sessions.records.single.correct, 5);
    expect(stats.stats, hasLength(5));
    expect(stats.stats.keys.every((k) => k.startsWith('balloon_vi_upper:')), isTrue);
    // Correct cheers use the spoken name, never the bare character.
    expect(tts.texts.where((t) => t.startsWith('Đúng rồi! Chữ ')), hasLength(5));
  });

  testWidgets('phrases use the spoken name; a wrong pop names the tapped letter by its spoken name', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    final goal = target(tts)!;
    expect(tts.texts.first, 'Xoài tìm chữ ${spokenOf(goal)} nào!');
    await run(tester, 2);
    final wrong = await tapAnyWrong(tester, goal);
    expect(wrong, isNotNull);
    await run(tester, 4);
    expect(tts.texts, containsAllInOrder(['Chưa đúng rồi, đây là chữ ${spokenOf(wrong!)}.', 'Tìm chữ ${spokenOf(goal)} nha!']));
    expect(find.byKey(Key('balloon-$wrong')), findsNothing);
    expect(prompts(tts), 1);
  });

  testWidgets('balloons carry Vietnamese letters, including accented ones, from the 29-letter alphabet', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    final alphabet = [for (final l in content.lettersVi) l.char];
    expect(alphabet, hasLength(29));
    final seen = <String>{};
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      seen.addAll(letters(tester));
    }
    expect(seen, isNotEmpty);
    expect(alphabet, containsAll(seen));
    expect(seen.length, greaterThan(5));
  });

  testWidgets('two wrong pops make the target balloon glow', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    final goal = target(tts)!;
    await run(tester, 2);
    for (var i = 0; i < 2; i++) {
      expect(await tapAnyWrong(tester, goal), isNotNull);
      await run(tester, 4);
    }
    expect(find.byKey(Key('balloon-glow-$goal')), findsOneWidget);
  });

  testWidgets('the home button says go_home and leaves', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BalloonScreen(spec: LetterGameSpec.balloonVi)),
          ),
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
    expect(find.byType(BalloonScreen), findsNothing);
    expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1));
  });
}
