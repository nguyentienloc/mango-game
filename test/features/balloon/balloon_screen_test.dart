import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/balloon/balloon_field.dart';
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

/// Pumps [seconds] of 50 ms frames. The field's clock caps one step at 50 ms, so
/// a long wait must be many frames, not one big pump.
Future<void> run(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 20).round(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Bounding boxes (body plus 12 dp of padding, plus the string) of the balloons in the tree.
Map<String, Rect> boxes(WidgetTester tester) => {
      for (final l in letters(tester)) l: tester.getRect(find.byKey(Key('balloon-$l'))),
    };

/// The balloon body inside its [box]: 12 dp padding on the sides and top.
Rect ovalOf(Rect box) {
  final d = box.width - 24;
  return Rect.fromLTWH(box.left + 12, box.top + 12, d, d * 1.15);
}

/// Whether [p] is inside the ellipse of [oval] grown by [pad] on every side.
bool inEllipse(Rect oval, Offset p, double pad) {
  final a = oval.width / 2 + pad;
  final b = oval.height / 2 + pad;
  final dx = (p.dx - oval.center.dx) / a;
  final dy = (p.dy - oval.center.dy) / b;
  return dx * dx + dy * dy <= 1;
}

/// A point on the body of [letter] that no other balloon's bounding box covers
/// and that lies inside the field; null if there is none right now.
Offset? pointFor(WidgetTester tester, String letter) {
  final all = boxes(tester);
  final box = all[letter];
  if (box == null) return null;
  final oval = ovalOf(box);
  final field = tester.getRect(find.byType(BalloonField)).deflate(6);
  for (final f in [0.5, 0.4, 0.6, 0.3, 0.7]) {
    final p = Offset(oval.center.dx, oval.top + oval.height * f);
    if (!field.contains(p)) continue;
    if (all.entries.any((e) => e.key != letter && e.value.contains(p))) continue;
    return p;
  }
  return null;
}

/// Taps the balloon of [letter] once it has risen into view. Returns false if it never showed up.
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
      await run(tester, 1);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await run(tester, 2);

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
    await run(tester, 2); // let a few balloons rise into view
    final wrong = letters(tester).firstWhere((l) => l != goal);
    expect(await tapBalloon(tester, wrong), isTrue);
    await run(tester, 0.4);
    expect(find.byKey(Key('balloon-$wrong')), findsNothing);
    expect(find.byKey(Key('balloon-pop-$wrong')), findsNothing);
    await run(tester, 3);
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
    await run(tester, 0.3);
    expect(find.byKey(Key('balloon-pop-$goal')), findsNothing);
    await run(tester, 2);
  });

  testWidgets('two wrong pops make the target balloon glow', (tester) async {
    final tts = FakeTts();
    await start(tester, tts);
    final goal = target(tts)!;
    await run(tester, 2);
    for (var i = 0; i < 2; i++) {
      final wrong = letters(tester).firstWhere((l) => l != goal);
      expect(await tapBalloon(tester, wrong), isTrue);
      await run(tester, 4); // Elsa finishes the sentence
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
    await run(tester, 2);
    final first = letters(tester).firstWhere((l) => l != goal);
    expect(await tapBalloon(tester, first), isTrue);
    await run(tester, 0.4);
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
    await run(tester, 0.4);
    expect(find.byKey(Key('balloon-$tapped')), findsNothing);
    await run(tester, 5);
  });

  testWidgets('two taps in one frame (a wrong balloon, then the target) never soft-lock the round', (tester) async {
    final tts = GatedTts();
    await start(tester, tts);
    for (var i = 0; i < 3; i++) {
      tts.release();
      await tester.pump(const Duration(milliseconds: 300));
    }
    final goal = target(tts)!;
    Offset? pWrong;
    Offset? pGoal;
    for (var step = 0; step < 300 && (pWrong == null || pGoal == null); step++) {
      await tester.pump(const Duration(milliseconds: 50));
      pGoal = pointFor(tester, goal);
      pWrong = null;
      for (final l in letters(tester).where((l) => l != goal)) {
        pWrong = pointFor(tester, l);
        if (pWrong != null) break;
      }
    }
    expect(pWrong, isNotNull);
    expect(pGoal, isNotNull);
    // No frame between the two taps: the screen cannot have locked the field yet.
    await tester.tapAt(pWrong!);
    await tester.tapAt(pGoal!);
    for (var i = 0; i < 40; i++) {
      tts.release();
      await run(tester, 0.3);
    }
    expect(letters(tester), contains(goal), reason: 'the target balloon is on the field again (or never left)');
    expect(await tapBalloon(tester, goal), isTrue);
    for (var i = 0; i < 20; i++) {
      tts.release();
      await run(tester, 0.3);
    }
    expect(prompts(tts), 2, reason: 'the round moved on to the next letter');
    for (var i = 0; i < 20; i++) {
      tts.release();
      await run(tester, 0.3);
    }
  });

  testWidgets('a tap that lands on a balloon edge pops that balloon, not a newer one whose box covers the spot', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tts = FakeTts();
    await start(tester, tts);
    String? victim;
    String? cover;
    Offset? spot;
    for (var frame = 0; frame < 1200 && spot == null; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      final all = boxes(tester);
      final field = tester.getRect(find.byType(BalloonField)).deflate(6);
      int idOf(String l) {
        final positioned = find.ancestor(of: find.byKey(Key('balloon-$l')), matching: find.byType(Positioned)).first;
        return (tester.widget<Positioned>(positioned).key! as ValueKey<int>).value;
      }

      for (final x in all.keys) {
        final xo = ovalOf(all[x]!);
        for (final y in all.keys.where((y) => y != x && idOf(y) > idOf(x))) {
          for (var k = 0; k < 24 && spot == null; k++) {
            final a = k * pi / 12;
            final p = xo.center + Offset(cos(a) * xo.width / 2 * 0.9, sin(a) * xo.height / 2 * 0.9);
            if (!field.contains(p) || !all[y]!.contains(p)) continue;
            if (inEllipse(ovalOf(all[y]!), p, 12)) continue; // inside the newer balloon's oval: it may rightfully win
            if (all.entries.any((e) => e.key != x && inEllipse(ovalOf(e.value), p, 12))) continue;
            victim = x;
            cover = y;
            spot = p;
          }
        }
      }
    }
    expect(spot, isNotNull, reason: 'no overlapping pair found in 60 s');
    await tester.tapAt(spot!);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(Key('balloon-pop-$victim')), findsOneWidget, reason: 'the balloon under the finger popped');
    expect(find.byKey(Key('balloon-pop-$cover')), findsNothing, reason: '$cover only covers the spot with its string/corner box');
    expect(find.byKey(Key('balloon-$cover')), findsOneWidget);
    await run(tester, 3);
  });

  testWidgets('taps unlock once the tapped letter has been said, not after the whole sentence', (tester) async {
    final tts = GatedTts();
    await start(tester, tts);
    for (var i = 0; i < 3; i++) {
      tts.release();
      await tester.pump(const Duration(milliseconds: 300));
    }
    final goal = target(tts)!;
    await run(tester, 2);
    final first = letters(tester).firstWhere((l) => l != goal);
    expect(await tapBalloon(tester, first), isTrue);
    for (var i = 0; i < 2; i++) {
      tts.release(); // "Chưa đúng rồi, đây là chữ", then the tapped letter
      await run(tester, 0.3);
    }
    expect(tts.texts, containsAllInOrder([_wrongLead, first]));
    final second = letters(tester).firstWhere((l) => l != goal && l != first);
    expect(await tapBalloon(tester, second), isTrue);
    await run(tester, 0.4);
    expect(find.byKey(Key('balloon-$second')), findsNothing, reason: 'unlocked: the second balloon popped while "Tìm chữ ..." is still being said');
    for (var i = 0; i < 30; i++) {
      tts.release();
      await run(tester, 0.3);
    }
  });

  testWidgets('several correct pops: never more than 6 balloons (6 on a 360 dp phone)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tts = FakeTts();
    await start(tester, tts);
    var most = 0;
    for (var i = 0; i < 4; i++) {
      expect(await tapBalloon(tester, target(tts)!), isTrue);
      for (var f = 0; f < 40; f++) {
        await tester.pump(const Duration(milliseconds: 50));
        most = letters(tester).length > most ? letters(tester).length : most;
        expect(letters(tester).length, lessThanOrEqualTo(6), reason: 'pop $i, frame $f: ${letters(tester)}');
      }
    }
    expect(most, greaterThan(0));
    await run(tester, 2);
  });

  testWidgets('several correct pops: never more than 5 balloons on a narrow (320 dp) phone', (tester) async {
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tts = FakeTts();
    await start(tester, tts);
    for (var i = 0; i < 4; i++) {
      expect(await tapBalloon(tester, target(tts)!), isTrue);
      for (var f = 0; f < 40; f++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(letters(tester).length, lessThanOrEqualTo(5), reason: 'pop $i, frame $f: ${letters(tester)}');
      }
    }
    await run(tester, 2);
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
      await run(tester, 0.4);
      // The popped letter is not served again while Elsa celebrates.
      expect(letters(tester), isNot(contains(letter)));
      await run(tester, 1);
      await tester.pump(const Duration(milliseconds: 50));
      final next = target(tts)!;
      expect(next, isNot(letter));
      final now = letters(tester);
      expect(now, contains(next));
      expect(now.toSet().length, now.length);
    }
    await run(tester, 1);
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
