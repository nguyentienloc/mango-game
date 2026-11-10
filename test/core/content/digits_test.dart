import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';

const _eps = 1e-6;

void main() {
  late List<LetterItem> digits;

  setUpAll(() async {
    digits = (await ContentRepository(FileContentSource('content')).load()).digits;
  });

  LetterItem d(int n) => digits[n];
  List<TracePoint> pts(Stroke s) => s.sample(step: 0.005);
  TracePoint first(LetterItem l) => pts(l.strokes.first).first;
  TracePoint last(Stroke s) => pts(s).last;
  bool horizontal(LineSegment s) => s.points.every((p) => (p.y - s.points.first.y).abs() < _eps);

  test('ten digits "0".."9" in order, no example', () {
    expect(digits.map((l) => l.char), [for (var n = 0; n < 10; n++) '$n']);
    for (final l in digits) {
      expect(l.exampleWord, isEmpty, reason: l.char);
      expect(l.strokes, isNotEmpty, reason: l.char);
    }
  });

  test('every digit stays in x 0.25-0.75, y 0.1-0.9 and reaches top and bottom', () {
    for (final l in digits) {
      final all = [for (final s in l.strokes) ...pts(s)];
      for (final p in all) {
        expect(p.x, inInclusiveRange(0.25 - _eps, 0.75 + _eps), reason: l.char);
        expect(p.y, inInclusiveRange(0.1 - _eps, 0.9 + _eps), reason: l.char);
      }
      expect(all.map((p) => p.y).reduce((a, b) => a < b ? a : b), lessThan(0.13), reason: '${l.char} top');
      expect(all.map((p) => p.y).reduce((a, b) => a > b ? a : b), greaterThan(0.87), reason: '${l.char} bottom');
    }
  });

  test('0 is one closed ellipse from the top, counter-clockwise', () {
    final arc = d(0).strokes.single.segments.single as ArcSegment;
    expect(arc.startDeg, -90);
    expect(arc.sweepDeg, -360);
  });

  test('1 rises from the left-middle to the top, then goes straight down', () {
    final s = d(1).strokes.single.segments.single as LineSegment;
    expect(s.points, hasLength(3));
    final [a, top, bottom] = s.points;
    expect(a.x, lessThan(top.x));
    expect(a.y, greaterThan(top.y));
    expect(top.y, closeTo(0.1, _eps));
    expect(bottom.x, closeTo(top.x, _eps));
    expect(bottom.y, closeTo(0.9, _eps));
  });

  test('2 is a top curve, a slant down-left and a bottom bar, in one stroke', () {
    final segs = d(2).strokes.single.segments;
    expect(segs.first, isA<ArcSegment>());
    final tail = segs.last as LineSegment;
    final n = tail.points.length;
    expect(tail.points[n - 2].x, closeTo(0.25, _eps));
    expect(tail.points[n - 2].y, closeTo(0.9, _eps));
    expect(tail.points[n - 1].x, closeTo(0.75, _eps));
    expect(tail.points[n - 1].y, closeTo(0.9, _eps));
  });

  test('3 is two clockwise curves open to the left (top, then bottom)', () {
    final segs = d(3).strokes.expand((s) => s.segments).toList();
    expect(segs, hasLength(2));
    final [top, bottom] = segs.cast<ArcSegment>();
    expect(top.cy, lessThan(bottom.cy));
    expect(top.sweepDeg, greaterThan(0));
    expect(bottom.sweepDeg, greaterThan(0));
    expect(first(d(3)).x, lessThan(0.4));
    expect(last(d(3).strokes.last).x, lessThan(0.4));
  });

  test('4 is slant + bar first, then a separate vertical from the top down', () {
    expect(d(4).strokes, hasLength(2));
    final slant = d(4).strokes.first.segments.single as LineSegment;
    expect(slant.points.first.y, closeTo(0.1, _eps));
    expect(slant.points[1].x, lessThan(slant.points.first.x));
    expect(horizontal(LineSegment(slant.points.sublist(1))), isTrue);
    final down = d(4).strokes.last.segments.single as LineSegment;
    expect(down.points.first.x, closeTo(down.points.last.x, _eps));
    expect(down.points.first.y, lessThan(down.points.last.y));
    expect(down.points.last.y, closeTo(0.9, _eps));
  });

  test('5 is a short down-stroke + belly in one stroke, then the top bar last', () {
    expect(d(5).strokes, hasLength(2));
    final body = d(5).strokes.first.segments;
    final stem = body.first as LineSegment;
    expect(stem.points.first.y, closeTo(0.1, _eps));
    expect(stem.points.last.y, greaterThan(stem.points.first.y));
    expect(body.last, isA<ArcSegment>());
    expect((body.last as ArcSegment).sweepDeg, greaterThan(0));
    final bar = d(5).strokes.last.segments.single as LineSegment;
    expect(horizontal(bar), isTrue);
    expect(bar.points.first.y, closeTo(0.1, _eps));
    expect(bar.points.first.x, lessThan(bar.points.last.x));
  });

  test('6 curves down the left from the top, then closes a loop at the bottom', () {
    final segs = d(6).strokes.single.segments;
    expect(first(d(6)).y, lessThan(0.2));
    final loop = segs.last as ArcSegment;
    expect(loop.sweepDeg.abs(), 360);
    expect(loop.cy, greaterThan(0.5));
  });

  test('7 is the top bar then a slant down to the bottom', () {
    final s = d(7).strokes.single.segments.single as LineSegment;
    expect(s.points, hasLength(3));
    expect(horizontal(LineSegment(s.points.sublist(0, 2))), isTrue);
    expect(s.points.first.y, closeTo(0.1, _eps));
    expect(s.points.first.x, lessThan(s.points[1].x));
    expect(s.points.last.y, closeTo(0.9, _eps));
  });

  test('8 starts at the top and comes back to where it started', () {
    final l = d(8);
    expect(first(l).y, lessThan(0.2));
    expect(last(l.strokes.last).distanceTo(first(l)), lessThan(0.02));
  });

  test('9 is a counter-clockwise closed top loop, then a stem to the bottom', () {
    final segs = d(9).strokes.single.segments;
    final loop = segs.first as ArcSegment;
    expect(loop.sweepDeg, -360);
    expect(loop.cy, lessThan(0.5));
    expect(last(d(9).strokes.single).y, closeTo(0.9, _eps));
  });
}
