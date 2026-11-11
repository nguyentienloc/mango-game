import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';

const _eps = 1e-6;

double _length(List<TracePoint> pts) {
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    total += pts[i - 1].distanceTo(pts[i]);
  }
  return total;
}

void main() {
  late List<ToneItem> tones;

  setUpAll(() async {
    tones = (await ContentRepository(FileContentSource('content')).load()).tones;
  });

  ToneItem tone(String id) => tones.firstWhere((t) => t.id == id);
  List<TracePoint> pts(ToneItem t) => t.strokes.single.sample(step: 0.005);

  test('five tones sắc, huyền, hỏi, ngã, nặng in order, one stroke each', () {
    expect(tones.map((t) => t.id), ['sac', 'huyen', 'hoi', 'nga', 'nang']);
    expect(tones.map((t) => t.name), ['sắc', 'huyền', 'hỏi', 'ngã', 'nặng']);
    expect(tones.map((t) => t.mark), ['´', '`', 'ˀ', '~', '.']);
    for (final t in tones) {
      expect(t.strokes, hasLength(1), reason: t.id);
    }
  });

  test('every mark stays in the middle of the box (0.2-0.8)', () {
    for (final t in tones) {
      for (final p in pts(t)) {
        expect(p.x, inInclusiveRange(0.2, 0.8), reason: t.id);
        expect(p.y, inInclusiveRange(0.2, 0.8), reason: t.id);
      }
    }
  });

  test('sắc is one slant from bottom-left (0.34, 0.74) up to top-right (0.66, 0.26)', () {
    final s = tone('sac').strokes.single.segments.single as LineSegment;
    expect(s.points, hasLength(2));
    expect([s.points.first.x, s.points.first.y], [closeTo(0.34, _eps), closeTo(0.74, _eps)]);
    expect([s.points.last.x, s.points.last.y], [closeTo(0.66, _eps), closeTo(0.26, _eps)]);
  });

  test('huyền is one slant from top-left (0.34, 0.26) down to bottom-right (0.66, 0.74)', () {
    final s = tone('huyen').strokes.single.segments.single as LineSegment;
    expect(s.points, hasLength(2));
    expect([s.points.first.x, s.points.first.y], [closeTo(0.34, _eps), closeTo(0.26, _eps)]);
    expect([s.points.last.x, s.points.last.y], [closeTo(0.66, _eps), closeTo(0.74, _eps)]);
  });

  test('hỏi starts top-left, curves over to the right, then comes down in the middle; at least 0.5 long', () {
    final p = pts(tone('hoi'));
    final segs = tone('hoi').strokes.single.segments;
    expect(segs.first, isA<ArcSegment>());
    expect((segs.first as ArcSegment).sweepDeg, greaterThan(0), reason: 'clockwise: over the top to the right');
    expect(p.first.x, lessThan(0.4));
    expect(p.first.y, lessThan(0.45));
    final rightmost = p.reduce((a, b) => a.x > b.x ? a : b);
    expect(rightmost.x, greaterThan(0.6));
    expect(p.last.x, closeTo(0.5, 0.02));
    expect(p.last.y, greaterThan(rightmost.y + 0.1), reason: 'ends below the curve');
    expect(p.map((q) => q.y).reduce(min), lessThan(p.first.y), reason: 'goes up over the top first');
    expect(_length(p), greaterThanOrEqualTo(0.5));
    expect(p.last.distanceTo(p.first), greaterThan(0.2), reason: 'an open hook, not a loop');
  });

  test('ngã is a wave of two joined arcs from left to right across the middle', () {
    final segs = tone('nga').strokes.single.segments;
    expect(segs, hasLength(2));
    final [a, b] = segs.cast<ArcSegment>();
    // The first arc humps up (clockwise from the left), the second dips down (counter-clockwise).
    expect(a.sweepDeg, greaterThan(0));
    expect(b.sweepDeg, lessThan(0));
    final p = pts(tone('nga'));
    expect(p.first.x, lessThan(0.3));
    expect(p.last.x, greaterThan(0.7));
    for (var i = 1; i < p.length; i++) {
      expect(p[i].x, greaterThanOrEqualTo(p[i - 1].x - _eps), reason: 'left to right');
    }
    expect((p.first.y + p.last.y) / 2, closeTo(0.5, 0.05));
    final half = p.length ~/ 2;
    expect(p.take(half).map((q) => q.y).reduce(min), lessThan(0.4), reason: 'hump up');
    expect(p.skip(half).map((q) => q.y).reduce(max), greaterThan(0.6), reason: 'dip down');
  });

  test('nặng is a small closed circle (radius about 0.12) around the centre, not a dot', () {
    final arc = tone('nang').strokes.single.segments.single as ArcSegment;
    expect([arc.cx, arc.cy], [closeTo(0.5, _eps), closeTo(0.5, _eps)]);
    expect(arc.rx, closeTo(0.12, 0.015));
    expect(arc.ry, arc.rx);
    expect(arc.sweepDeg.abs(), 360);
    final p = pts(tone('nang'));
    expect(p.last.distanceTo(p.first), lessThan(_eps), reason: 'closed');
  });
}
