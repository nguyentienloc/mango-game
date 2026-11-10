import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/trace/number_trace.dart';
import 'package:xoai_castle/features/games/trace/trace_logic.dart';
import 'package:xoai_castle/features/games/trace/trace_pad.dart';

// Synthetic digits: digit d is a line at x = 0.3 + d/50 plus an arc, so the
// transform of both segment kinds can be checked exactly.
final _fakeDigits = [
  for (var d = 0; d < 10; d++)
    LetterItem(char: '$d', strokes: [
      Stroke([LineSegment([TracePoint(0.3 + d / 50, 0.1), TracePoint(0.3 + d / 50, 0.9)])]),
      Stroke([ArcSegment(0.5, 0.4 + d / 100, 0.2, 0.3, -90, 180.0 + d)]),
    ]),
];

String _n(double x) => (x * 1e6).round() == 0 ? '0.0' : double.parse(x.toStringAsFixed(6)).toString();

String _stroke(Stroke s) => [
      for (final g in s.segments)
        switch (g) {
          LineSegment() => 'line ${g.points.map((p) => '${_n(p.x)},${_n(p.y)}').join(' ')}',
          ArcSegment() => 'arc ${_n(g.cx)} ${_n(g.cy)} ${_n(g.rx)} ${_n(g.ry)} ${_n(g.startDeg)} ${_n(g.sweepDeg)}',
        },
    ].join('; ');

String _strokes(LetterItem l) => l.strokes.map(_stroke).join(' | ');

Map<String, ItemStat> _mastered(Iterable<int> numbers, {int mastery = 1}) => {
      for (final n in numbers) numberTraceKey(n): ItemStat(key: numberTraceKey(n), mastery: mastery),
    };

Iterable<int> _range(int from, int to) => [for (var n = from; n <= to; n++) n];

double _length(List<TracePoint> pts) {
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    total += pts[i - 1].distanceTo(pts[i]);
  }
  return total;
}

void main() {
  group('buildNumberItems', () {
    final numbers = buildNumberItems(_fakeDigits);

    test('builds 100 items "0".."99" in order, without examples', () {
      expect(numbers.map((l) => l.char), [for (var n = 0; n < 100; n++) '$n']);
      for (final l in numbers) {
        expect(l.exampleWord, isEmpty);
        expect(l.exampleEmoji, isNull);
      }
    });

    test('0-9 keep the digit strokes untouched', () {
      for (var d = 0; d < 10; d++) {
        expect(_strokes(numbers[d]), _strokes(_fakeDigits[d]), reason: '$d');
      }
    });

    test('37 is the 3 moved to (0.28, 0.5) then the 7 moved to (0.72, 0.5), scaled 0.75', () {
      expect(numbers[37].strokes, hasLength(4));
      // 3: line x 0.36 -> 0.28 + (0.36 - 0.5) * 0.75 = 0.175; y 0.1 -> 0.2, 0.9 -> 0.8.
      // 3: arc centre (0.5, 0.43) -> (0.28, 0.4475), radii 0.15 x 0.225, angles unchanged.
      // 7: line x 0.44 -> 0.72 - 0.045 = 0.675; arc centre (0.5, 0.47) -> (0.72, 0.4775).
      expect(
        _strokes(numbers[37]),
        'line 0.175,0.2 0.175,0.8 | arc 0.28 0.4475 0.15 0.225 -90.0 183.0 | '
        'line 0.675,0.2 0.675,0.8 | arc 0.72 0.4775 0.15 0.225 -90.0 187.0',
      );
    });

    test('10 is the 1 then the 0', () {
      expect(numbers[10].strokes, hasLength(4));
      expect(_stroke(numbers[10].strokes[0]), 'line 0.145,0.2 0.145,0.8');
      expect(_stroke(numbers[10].strokes[2]), 'line 0.57,0.2 0.57,0.8');
    });
  });

  group('number levels', () {
    test('numberLevels and keys', () {
      expect(numberLevels, [(0, 9), (10, 19), (20, 39), (40, 69), (70, 99)]);
      expect(numberTraceKey(23), 'trace_num:23');
    });

    test('no stats: level 1', () {
      expect(unlockedNumberLevel({}), 1);
    });

    test('every 0-9 mastered at least once: level 2', () {
      expect(unlockedNumberLevel(_mastered(_range(0, 9))), 2);
    });

    test('one of 0-9 missing or at mastery 0: still level 1', () {
      expect(unlockedNumberLevel(_mastered(_range(0, 8))), 1);
      expect(
        unlockedNumberLevel({..._mastered(_range(0, 9)), ..._mastered([5], mastery: 0)}),
        1,
      );
    });

    test('levels do not skip: level 3 needs level 2 done too', () {
      expect(unlockedNumberLevel(_mastered([..._range(0, 9), ..._range(20, 39)])), 2);
      expect(unlockedNumberLevel(_mastered([..._range(10, 99)])), 1);
      expect(unlockedNumberLevel(_mastered(_range(0, 19))), 3);
      expect(unlockedNumberLevel(_mastered(_range(0, 39))), 4);
      expect(unlockedNumberLevel(_mastered(_range(0, 69))), 5);
      expect(unlockedNumberLevel(_mastered(_range(0, 99), mastery: ItemStat.maxMastery)), 5);
    });

    test('unlockedNumbers holds every number of the unlocked levels', () {
      final numbers = buildNumberItems(_fakeDigits);
      List<String> chars(Map<String, ItemStat> stats) => unlockedNumbers(numbers, stats).map((l) => l.char).toList();
      expect(chars({}), [for (var n = 0; n <= 9; n++) '$n']);
      expect(chars(_mastered(_range(0, 9))), [for (var n = 0; n <= 19; n++) '$n']);
      expect(chars(_mastered(_range(0, 19))), [for (var n = 0; n <= 39; n++) '$n']);
      expect(chars(_mastered(_range(0, 69))), [for (var n = 0; n <= 99; n++) '$n']);
    });

    test('unlocked numbers feed buildTraceRound with the trace_num prefix', () {
      final numbers = unlockedNumbers(buildNumberItems(_fakeDigits), {});
      final round = buildTraceRound(
        letters: numbers,
        stats: const {},
        picker: QuestionPicker(Random(1)),
        keyPrefix: 'trace_num',
      );
      expect(round, hasLength(3));
      expect(round.map((l) => l.char).toSet(), hasLength(3));
      for (final l in round) {
        expect(int.parse(l.char), inInclusiveRange(0, 9));
        expect(traceKey(l, 'trace_num'), numberTraceKey(int.parse(l.char)));
      }
    });
  });

  group('shipped digits', () {
    late List<LetterItem> numbers;

    setUpAll(() async {
      final bundle = await ContentRepository(FileContentSource('content')).load();
      numbers = buildNumberItems(bundle.digits);
    });

    test('every point of every number is inside the box', () {
      for (final l in numbers) {
        for (final s in l.strokes) {
          for (final p in s.sample(step: 0.002)) {
            expect(p.x, inInclusiveRange(0, 1), reason: l.char);
            expect(p.y, inInclusiveRange(0, 1), reason: l.char);
          }
        }
      }
    });

    test('in 10-99 the tens stay left of 0.5 and the units right of it, arcs included', () {
      for (var n = 10; n < 100; n++) {
        final tensStrokes = numbers[n ~/ 10].strokes.length;
        for (final (i, s) in numbers[n].strokes.indexed) {
          final tens = i < tensStrokes;
          for (final p in s.sample(step: 0.002)) {
            expect(tens ? p.x < 0.5 : p.x > 0.5, isTrue, reason: '$n stroke $i x=${p.x}');
          }
        }
      }
    });

    test('every stroke is long enough to get a direction arrow', () {
      for (final l in numbers) {
        for (final (i, s) in l.strokes.indexed) {
          expect(shouldDrawArrow(_length(s.sample())), isTrue, reason: '${l.char} stroke $i');
        }
      }
    });

    void expectTraceable(LetterItem l, List<TracePoint> Function(List<TracePoint> guide) drawFrom, String how) {
      final session = TraceLetterSession(l);
      for (final (i, target) in session.targets.indexed) {
        final drawn = drawFrom(target);
        expect(scoreStroke(target, drawn).passed, isTrue, reason: '${l.char} stroke $i ($how)');
        expect(session.submit(drawn), isTrue, reason: '${l.char} stroke $i ($how)');
      }
      expect(session.isDone, isTrue);
      expect(session.outcome, AnswerOutcome.firstTry);
    }

    final traced = [for (var d = 0; d < 10; d++) d, 10, 23, 88];

    test('tracing right along each guide scores correct (0-9, 10, 23, 88)', () {
      for (final n in traced) {
        expectTraceable(numbers[n], (guide) => guide, 'on the guide');
      }
    });

    test('a slightly shifted, coarse finger trace still scores correct', () {
      for (final n in traced) {
        expectTraceable(
          numbers[n],
          (guide) => [
            for (var i = 0; i < guide.length; i += 3) TracePoint(guide[i].x + 0.04, guide[i].y - 0.03),
            TracePoint(guide.last.x + 0.04, guide.last.y - 0.03),
          ],
          'shifted',
        );
      }
    });
  });
}
