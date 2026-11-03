import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/balloon/balloon_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

const _promptLead = 'Xoài tìm chữ';
const _wrongLead = 'Chưa đúng rồi, đây là chữ';
final _balloonKey = RegExp(r'^balloon-[A-Z]$');

/// The letter of the latest prompt ("Xoài tìm chữ", "B", "nào!").
String? target(FakeTts tts) {
  final t = tts.texts;
  final i = t.lastIndexOf(_promptLead);
  return i < 0 || i + 1 >= t.length ? null : t[i + 1];
}

int prompts(FakeTts tts) => tts.texts.where((t) => t == _promptLead).length;

/// Letters of the balloons currently in the tree (not popping ones).
List<String> letters(WidgetTester tester) => [
      for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && _balloonKey.hasMatch((w.key! as ValueKey<String>).value)).evaluate())
        (e.widget.key! as ValueKey<String>).value.substring(8),
    ];

/// Taps the balloon of [letter] at a spot where it is the topmost thing, once
/// it has risen into view. Returns false if it never showed up.
Future<bool> tapBalloon(WidgetTester tester, String letter, {int steps = 150}) async {
  final finder = find.byKey(Key('balloon-$letter'));
  for (var step = 0; step < steps; step++) {
    if (finder.evaluate().isNotEmpty) {
      final rect = tester.getRect(finder);
      final render = tester.renderObject(finder);
      final viewH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      for (final f in [0.3, 0.4, 0.2, 0.5]) {
        final p = Offset(rect.center.dx, rect.top + rect.height * f);
        if (p.dy < 0 || p.dy > viewH - 4) continue;
        final hit = tester.hitTestOnBinding(p);
        if (hit.path.any((e) => e.target == render)) {
          await tester.tapAt(p);
          await tester.pump();
          return true;
        }
      }
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return false;
}

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<void> start(WidgetTester tester, FakeTts tts, {MemorySessionStore? sessions, MemoryRewardStore? rewards, MemoryItemStatsStore? stats}) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const BalloonScreen(),
      sessions: sessions,
      rewards: rewards,
      itemStats: stats,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a full round of correct pops ends on the reward screen', (tester) async {
    final tts = FakeTts();
    final sessions = MemorySessionStore();
    final stats = MemoryItemStatsStore();
    await start(tester, tts, sessions: sessions, rewards: MemoryRewardStore(), stats: stats);

    for (var i = 0; i < 5; i++) {
      expect(prompts(tts), i + 1, reason: 'question ${i + 1}');
      final letter = target(tts)!;
      expect(await tapBalloon(tester, letter), isTrue, reason: 'balloon $letter');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+10 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'balloon');
    expect(sessions.records.single.correct, 5);
    expect(stats.stats, hasLength(5));
    expect(stats.stats.keys.every((k) => k.startsWith('balloon_en_upper:')), isTrue);
  });

  testWidgets('a wrong pop names the tapped letter, pops it and asks again', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    final goal = target(tts)!;
    await tester.pump(const Duration(seconds: 2)); // let a few balloons rise into view
    final wrong = letters(tester).firstWhere((l) => l != goal);
    expect(await tapBalloon(tester, wrong), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(Key('balloon-$wrong')), findsNothing);
    expect(find.byKey(Key('balloon-pop-$wrong')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tts.texts, containsAllInOrder([_wrongLead, wrong, 'Tìm chữ', goal, 'nha!']));
    expect(find.byKey(Key('balloon-glow-$goal')), findsNothing);
    expect(prompts(tts), 1);
  });

  testWidgets('a balloon shows confetti while it pops', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    final goal = target(tts)!;
    expect(await tapBalloon(tester, goal), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(Key('balloon-pop-$goal')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(Key('balloon-pop-$goal')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('two wrong pops make the target balloon glow', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    final goal = target(tts)!;
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 2; i++) {
      final wrong = letters(tester).firstWhere((l) => l != goal);
      expect(await tapBalloon(tester, wrong), isTrue);
      await tester.pump(const Duration(seconds: 4)); // Elsa finishes the sentence
    }
    expect(find.byKey(Key('balloon-glow-$goal')), findsOneWidget);
  });

  testWidgets('taps are ignored while Elsa speaks about a wrong pop', (tester) async {
    final tts = GatedTts();
    await start(tester, tts);
    for (var i = 0; i < 3; i++) {
      tts.release(); // let the prompt play through
      await tester.pump(const Duration(milliseconds: 300));
    }
    final goal = target(tts)!;
    await tester.pump(const Duration(seconds: 2));
    final first = letters(tester).firstWhere((l) => l != goal);
    expect(await tapBalloon(tester, first), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    final before = tts.texts.where((t) => t == _wrongLead).length;
    // Try the other balloons once each: one of them is within reach.
    String? tapped;
    for (final l in letters(tester).where((l) => l != goal)) {
      if (await tapBalloon(tester, l, steps: 1)) {
        tapped = l;
        break;
      }
    }
    expect(tapped, isNotNull, reason: 'some balloon in reach');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(Key('balloon-$tapped')), findsOneWidget, reason: 'locked: it did not pop');
    expect(tts.texts.where((t) => t == _wrongLead).length, before);

    for (var i = 0; i < 8; i++) {
      tts.release(); // Elsa finishes the sentence: the same balloon can be popped now
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(await tapBalloon(tester, tapped!, steps: 20), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(Key('balloon-$tapped')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('20 seconds of play: never two balloons with one letter, the target always around', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    final goal = target(tts)!;
    var missingFrames = 0;
    var longestMissing = 0;
    var maxCount = 0;
    var minCount = 99;
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final now = letters(tester);
      expect(now.toSet().length, now.length, reason: 'duplicate letters at frame $i: $now');
      if (i > 20) {
        maxCount = now.length > maxCount ? now.length : maxCount;
        minCount = now.length < minCount ? now.length : minCount;
      }
      missingFrames = now.contains(goal) ? 0 : missingFrames + 1;
      if (missingFrames > longestMissing) longestMissing = missingFrames;
    }
    expect(longestMissing * 50, lessThanOrEqualTo(1500), reason: 'target "$goal" was missing for ${longestMissing * 50} ms');
    expect(maxCount, lessThanOrEqualTo(6));
    expect(minCount, greaterThanOrEqualTo(3));
  });

  testWidgets('the next target is on the field right after a correct pop, without duplicates', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    for (var i = 0; i < 4; i++) {
      final letter = target(tts)!;
      expect(await tapBalloon(tester, letter), isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      // The popped letter is not served again while Elsa celebrates.
      expect(letters(tester), isNot(contains(letter)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 50));
      final next = target(tts)!;
      expect(next, isNot(letter));
      final now = letters(tester);
      expect(now, contains(next));
      expect(now.toSet().length, now.length);
    }
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('fits a 360x640 phone: no overflow and every balloon stays inside', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tts = FakeTts();
    await start(tester, tts);
    var maxCount = 0;
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      for (final l in letters(tester)) {
        final r = tester.getRect(find.byKey(Key('balloon-$l')));
        // 12 dp of tap padding on each side of the body.
        expect(r.left + 12, greaterThanOrEqualTo(-0.01), reason: 'balloon $l at frame $i');
        expect(r.right - 12, lessThanOrEqualTo(360.01), reason: 'balloon $l at frame $i');
      }
      maxCount = letters(tester).length > maxCount ? letters(tester).length : maxCount;
    }
    expect(maxCount, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the system back gesture says go_home and leaves the game', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BalloonScreen())),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(BalloonScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BalloonScreen), findsNothing);
    expect(tts.texts.where((t) => t == 'Về lâu đài nào!'), hasLength(1));
  });

  testWidgets('the home button says go_home only once', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BalloonScreen())),
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
