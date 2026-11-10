import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/games/trace/number_face.dart';
import 'package:xoai_castle/features/games/trace/number_trace.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import 'trace_screen_test.dart' show drawPoints;

const _promptStart = 'Mình cùng viết số';
const _doneStart = 'Giỏi quá! Số';
const _unlock = 'Mở khóa số mới rồi nè!';
const _roundDone = 'Hoàn thành rồi! Xoài giỏi quá!';

/// The numbers asked so far: the part spoken right after each prompt's first part.
List<String> asked(FakeTts tts) => [
  for (var i = 0; i + 1 < tts.spoken.length; i++)
    if (tts.spoken[i].text == _promptStart) tts.spoken[i + 1].text,
];

/// Lets a multi-part line finish: parts are spoken with short gaps in between.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late ContentBundle content;
  late List<LetterItem> numbers;
  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
    numbers = buildNumberItems(content.digits);
  });

  Future<void> open(WidgetTester tester, FakeTts tts, {LetterGameSpec spec = LetterGameSpec.traceNumbers, MemorySessionStore? sessions, MemoryItemStatsStore? stats}) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: TraceScreen(spec: spec),
      rewards: MemoryRewardStore(),
      sessions: sessions,
      itemStats: stats,
    ));
    await tester.pump();
    await tester.pump();
    await settle(tester);
  }

  Future<void> trace(WidgetTester tester, int n) async {
    for (final s in numbers[n].strokes) {
      await drawPoints(tester, s.sample(step: 0.05));
    }
    await settle(tester);
  }

  testWidgets('a first round: three different numbers of 0-9, said in vi then en, ends on the reward with +8 ❄️', (tester) async {
    final tts = FakeTts();
    final sessions = MemorySessionStore();
    final stats = MemoryItemStatsStore();
    await open(tester, tts, sessions: sessions, stats: stats);
    for (var i = 0; i < 3; i++) {
      final c = asked(tts);
      expect(c, hasLength(i + 1), reason: 'number ${i + 1}');
      final n = int.parse(c.last);
      expect(n, inInclusiveRange(0, 9));
      final at = tts.spoken.lastIndexWhere((s) => s.text == _promptStart);
      expect(tts.spoken.sublist(at, at + 3), [
        (text: _promptStart, lang: 'vi'),
        (text: '$n', lang: 'vi'),
        (text: '$n', lang: 'en'),
      ]);
      await trace(tester, n);
      expect(find.byKey(Key('number-face-$n')), findsOneWidget);
      final done = tts.spoken.lastIndexWhere((s) => s.text == _doneStart);
      expect(tts.spoken.sublist(done), [
        (text: _doneStart, lang: 'vi'),
        (text: '$n', lang: 'vi'),
        (text: '$n', lang: 'en'),
      ]);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    expect(asked(tts).toSet(), hasLength(3));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+8 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, numberTracePrefix);
    expect(stats.stats.keys, everyElement(startsWith('$numberTracePrefix:')));
    expect(stats.stats.values.map((s) => s.mastery), everyElement(1));
    expect(tts.texts, isNot(contains(_unlock)));
  });

  testWidgets('after tracing 7 the screen shows 7 butterflies to count', (tester) async {
    await open(tester, FakeTts(), spec: _only(7));
    await trace(tester, 7);
    expect(find.byKey(const Key('number-face-7')), findsOneWidget);
    expect(find.byKey(const Key('number-face-item')), findsNWidgets(7));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('finishing level 1 says the unlock line before the reward screen', (tester) async {
    // Every number of 0-9 already traced right except 9, and the round is just 9:
    // tracing it opens level 2 (the same `level` hook as the real game).
    final tts = FakeTts();
    final stats = MemoryItemStatsStore();
    for (var n = 0; n <= 8; n++) {
      stats.stats[numberTraceKey(n)] = ItemStat(key: numberTraceKey(n), mastery: 2);
    }
    expect(unlockedNumberLevel(stats.stats), 1);
    await open(tester, tts, spec: _onlyMissing(9), stats: stats);
    await trace(tester, 9);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(tts.texts.where((t) => t == _unlock), hasLength(1));
    expect(tts.texts.indexOf(_unlock), lessThan(tts.texts.indexOf(_roundDone)));
    expect(unlockedNumberLevel(stats.stats), 2);
  });

  testWidgets('an unlock line that never ends holds the reward back by at most 3 s', (tester) async {
    final tts = GatedTts();
    final stats = MemoryItemStatsStore();
    for (var n = 0; n <= 8; n++) {
      stats.stats[numberTraceKey(n)] = ItemStat(key: numberTraceKey(n), mastery: 2);
    }
    await open(tester, tts, spec: _onlyMissing(9), stats: stats);
    tts.release();
    for (final s in numbers[9].strokes) {
      await drawPoints(tester, s.sample(step: 0.05));
    }
    // Let the done line finish (each part waits for its release), up to the unlock line.
    for (var i = 0; i < 40 && !tts.texts.contains(_unlock); i++) {
      tts.release();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tts.texts, contains(_unlock), reason: 'the unlock line is started');
    // From here the TTS never completes anything.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(unlockedNumberLevel(stats.stats), 2);
  });

  testWidgets('a round that does not open a new level stays silent about it', (tester) async {
    // 8 and 9 are both still missing, so tracing only 9 leaves level 1 closed.
    final tts = FakeTts();
    final stats = MemoryItemStatsStore();
    for (var n = 0; n <= 7; n++) {
      stats.stats[numberTraceKey(n)] = ItemStat(key: numberTraceKey(n), mastery: 2);
    }
    await open(tester, tts, spec: _onlyMissing(9), stats: stats);
    await trace(tester, 9);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(unlockedNumberLevel(stats.stats), 1);
    expect(tts.texts, isNot(contains(_unlock)));
  });

  testWidgets('with level 1 done a round can reach into 10-19', (tester) async {
    final stats = MemoryItemStatsStore();
    for (var n = 0; n <= 9; n++) {
      stats.stats[numberTraceKey(n)] = ItemStat(key: numberTraceKey(n), mastery: 4);
    }
    final tts = FakeTts();
    await open(tester, tts, stats: stats);
    for (var i = 0; i < 3; i++) {
      await trace(tester, int.parse(asked(tts).last));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    final round = asked(tts).map(int.parse).toList();
    expect(round, hasLength(3));
    expect(round, everyElement(inInclusiveRange(0, 19)));
    // Mastered numbers weigh 1 and unseen ones 5, so the new level shows up.
    expect(round.any((n) => n >= 10), isTrue, reason: '$round');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final n in [7, 23, 88]) {
    testWidgets('fits a 360x640 phone, number $n traced and shown', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final tts = FakeTts();
      await open(tester, tts, spec: _only(n));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('trace-pad'))).width, greaterThanOrEqualTo(280));
      await trace(tester, n);
      expect(tts.texts, isNot(contains('Thử lại nha con!')));
      expect(tester.takeException(), isNull);
      final face = tester.getRect(find.byKey(Key('number-face-$n')));
      expect(const Rect.fromLTWH(0, 0, 360, 640).intersect(face), face);
      await tester.pump(const Duration(seconds: 2));
    });
  }

  group('stroke-order badges', () {
    Future<void> pumpGuide(WidgetTester tester, LetterGameSpec spec) async {
      await open(tester, FakeTts(), spec: spec);
    }

    RenderObject guide(WidgetTester tester) => tester.renderObject(
      find.descendant(of: find.byKey(const Key('trace-guide')), matching: find.byType(CustomPaint)),
    );

    testWidgets('the numbers pad paints the start dot but no numeral on it', (tester) async {
      await pumpGuide(tester, LetterGameSpec.traceNumbers);
      expect(guide(tester), isNot(paints..paragraph()));
      expect(guide(tester), paints..circle());
      expect(LetterGameSpec.traceNumbers.strokeNumbers, isFalse);
    });

    testWidgets('the English letters pad still paints the numeral on the start dot', (tester) async {
      await pumpGuide(tester, LetterGameSpec.traceEn);
      expect(guide(tester), paints..circle()..paragraph());
      expect(LetterGameSpec.traceEn.strokeNumbers, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('the Vietnamese letters pad still paints the numeral on the start dot', (tester) async {
      await pumpGuide(tester, LetterGameSpec.traceVi);
      expect(guide(tester), paints..circle()..paragraph());
      expect(LetterGameSpec.traceVi.strokeNumbers, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('NumberFace', () {
    Future<void> pumpFace(WidgetTester tester, int n) => tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: NumberFace(n)))));

    testWidgets('1-9: the number and that many of its own emoji', (tester) async {
      const emoji = ['🍎', '⭐', '🐟', '🌸', '🎈', '🍓', '🦋', '🍪', '🐥'];
      for (var n = 1; n <= 9; n++) {
        await pumpFace(tester, n);
        expect(find.byKey(Key('number-face-$n')), findsOneWidget);
        expect(find.text('$n'), findsOneWidget);
        expect(find.byKey(const Key('number-face-item')), findsNWidgets(n), reason: '$n');
        expect(find.text(emoji[n - 1]), findsNWidgets(n), reason: '$n');
      }
    });

    testWidgets('0: the number and an empty basket, nothing to count', (tester) async {
      await pumpFace(tester, 0);
      expect(find.byKey(const Key('number-face-0')), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('🧺'), findsOneWidget);
      expect(find.byKey(const Key('number-face-item')), findsNothing);
    });

    testWidgets('10-99: the big sparkling number, nothing to count', (tester) async {
      await pumpFace(tester, 23);
      expect(find.byKey(const Key('number-face-23')), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
      expect(find.text('✨'), findsNWidgets(2));
      expect(find.byKey(const Key('number-face-item')), findsNothing);
    });
  });
}

/// The numbers game, but its round is the single number [n].
LetterGameSpec _only(int n) {
  const s = LetterGameSpec.traceNumbers;
  return LetterGameSpec(
    letters: (c) => [buildNumberItems(c.digits)[n]],
    keyPrefix: s.keyPrefix,
    sessionGame: s.sessionGame,
    promptId: s.promptId,
    doneId: s.doneId,
    vars: s.vars,
    doneView: s.doneView,
    popToRootOnExit: true,
  );
}

/// The numbers game with the real `level` hook, but whose round is only number [n]
/// (as if it were the only one left to learn).
LetterGameSpec _onlyMissing(int n) {
  const s = LetterGameSpec.traceNumbers;
  return LetterGameSpec(
    letters: s.letters,
    available: (all, stats) => [all[n]],
    level: s.level,
    levelUpId: s.levelUpId,
    keyPrefix: s.keyPrefix,
    sessionGame: s.sessionGame,
    promptId: s.promptId,
    doneId: s.doneId,
    vars: s.vars,
    doneView: s.doneView,
    popToRootOnExit: true,
  );
}
