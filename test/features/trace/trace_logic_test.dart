import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/trace/trace_logic.dart';

List<TracePoint> line(double x1, double y1, double x2, double y2, [int n = 30]) =>
    [for (var i = 0; i <= n; i++) TracePoint(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n)];

final vertical = const Stroke([LineSegment([TracePoint(0.5, 0.1), TracePoint(0.5, 0.9)])]).sample();

const letterT = LetterItem(char: 'T', exampleWord: 'Tree', exampleEmoji: '🌳', strokes: [
  Stroke([LineSegment([TracePoint(0.15, 0.1), TracePoint(0.85, 0.1)])]),
  Stroke([LineSegment([TracePoint(0.5, 0.1), TracePoint(0.5, 0.9)])]),
]);

void main() {
  group('scoreStroke', () {
    test('tracing right on the stroke passes', () {
      expect(scoreStroke(vertical, line(0.5, 0.1, 0.5, 0.9)).passed, isTrue);
    });

    test('a wobbly trace within tolerance passes', () {
      final wobbly = [for (var i = 0; i <= 40; i++) TracePoint(0.5 + 0.08 * sin(i / 3), 0.1 + 0.8 * i / 40)];
      expect(scoreStroke(vertical, wobbly).passed, isTrue);
    });

    test('tracing only half the stroke fails on coverage', () {
      final s = scoreStroke(vertical, line(0.5, 0.1, 0.5, 0.5));
      expect(s.coverage, lessThan(0.8));
      expect(s.passed, isFalse);
    });

    test('a parallel line too far away fails', () {
      expect(scoreStroke(vertical, line(0.8, 0.1, 0.8, 0.9)).passed, isFalse);
    });

    test('scribbling over the whole box fails on precision', () {
      final scribble = [
        for (var row = 0; row <= 10; row++) ...line(0.05, 0.05 + row * 0.09, 0.95, 0.05 + row * 0.09, 20),
      ];
      final s = scoreStroke(vertical, scribble);
      expect(s.coverage, greaterThanOrEqualTo(0.8));
      expect(s.precision, lessThan(0.7));
      expect(s.passed, isFalse);
    });

    test('fast swipes with few points still count via segment distance', () {
      expect(scoreStroke(vertical, const [TracePoint(0.5, 0.1), TracePoint(0.5, 0.9)]).passed, isTrue);
    });

    test('an empty or single-point drawing fails', () {
      expect(scoreStroke(vertical, const []).passed, isFalse);
      expect(scoreStroke(vertical, const [TracePoint(0.5, 0.5)]).passed, isFalse);
    });

    test('a tap at the middle of a short stroke fails on length', () {
      final crossbar = const Stroke([LineSegment([TracePoint(0.55, 0.57), TracePoint(0.85, 0.57)])]).sample();
      expect(scoreStroke(crossbar, const [TracePoint(0.7, 0.57), TracePoint(0.7, 0.57)]).passed, isFalse);
      expect(scoreStroke(crossbar, line(0.55, 0.57, 0.85, 0.57)).passed, isTrue);
    });

    test('a tap on a very short stroke fails on length', () {
      final dash = const Stroke([LineSegment([TracePoint(0.5, 0.5), TracePoint(0.6, 0.5)])]).sample();
      expect(scoreStroke(dash, const [TracePoint(0.55, 0.5), TracePoint(0.55, 0.5)]).passed, isFalse);
    });
  });

  group('TraceLetterSession', () {
    test('strokes are completed in order and the letter is first-try', () {
      final s = TraceLetterSession(letterT);
      expect(s.targets, hasLength(2));
      expect(s.submit(line(0.15, 0.1, 0.85, 0.1)), isTrue);
      expect(s.strokeIndex, 1);
      expect(s.submit(line(0.5, 0.1, 0.5, 0.9)), isTrue);
      expect(s.isDone, isTrue);
      expect(s.outcome, AnswerOutcome.firstTry);
      expect(() => s.submit(line(0, 0, 1, 1)), throwsStateError);
    });

    test('a failed stroke stays current and counts failures', () {
      final s = TraceLetterSession(letterT);
      expect(s.submit(line(0.15, 0.9, 0.85, 0.9)), isFalse);
      expect(s.strokeIndex, 0);
      expect(s.failuresOn(0), 1);
    });

    test('three failures on one stroke make the letter a retry', () {
      final s = TraceLetterSession(letterT);
      for (var i = 0; i < 3; i++) {
        s.submit(line(0.15, 0.9, 0.85, 0.9));
      }
      s.submit(line(0.15, 0.1, 0.85, 0.1));
      s.submit(line(0.5, 0.1, 0.5, 0.9));
      expect(s.outcome, AnswerOutcome.retry);
    });

    test('after five failures the next drawing completes the stroke, still a retry', () {
      final s = TraceLetterSession(letterT);
      final wrong = line(0.15, 0.9, 0.85, 0.9);
      for (var i = 0; i < 5; i++) {
        expect(s.submit(wrong), isFalse, reason: 'failure ${i + 1}');
      }
      expect(s.strokeIndex, 0);
      expect(s.submit(wrong), isTrue);
      expect(s.strokeIndex, 1);
      // the help is per stroke: the next stroke is scored normally again
      expect(s.submit(line(0.5, 0.9, 0.5, 0.95)), isFalse);
      expect(s.submit(line(0.5, 0.1, 0.5, 0.9)), isTrue);
      expect(s.isDone, isTrue);
      expect(s.outcome, AnswerOutcome.retry);
    });

    test('two failures on one stroke still count as first try', () {
      final s = TraceLetterSession(letterT);
      s.submit(line(0.15, 0.9, 0.85, 0.9));
      s.submit(line(0.15, 0.9, 0.85, 0.9));
      s.submit(line(0.15, 0.1, 0.85, 0.1));
      s.submit(line(0.5, 0.1, 0.5, 0.9));
      expect(s.outcome, AnswerOutcome.firstTry);
    });
  });

  test('buildTraceRound picks 3 different new letters for a fresh player', () {
    final letters = [
      for (final c in 'ABCDEFGHIJ'.split('')) LetterItem(char: c, exampleWord: c, exampleEmoji: '⭐', strokes: letterT.strokes),
    ];
    for (var seed = 0; seed < 20; seed++) {
      final round = buildTraceRound(letters: letters, stats: const <String, ItemStat>{}, picker: QuestionPicker(Random(seed)));
      expect(round, hasLength(3));
      expect(round.map((l) => l.char).toSet(), hasLength(3));
    }
    expect(traceKey(letters.first), 'trace_en_upper:A');
  });
}
