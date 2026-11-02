import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/strokes.dart';

void main() {
  test('a line is sampled at roughly the step size, ends included', () {
    final pts = const Stroke([LineSegment([TracePoint(0, 0), TracePoint(1, 0)])]).sample(step: 0.1);
    expect(pts.first.x, 0);
    expect(pts.last.x, closeTo(1, 1e-9));
    expect(pts.length, inInclusiveRange(10, 12));
  });

  test('a clockwise quarter arc from the top goes to the right', () {
    final pts = const Stroke([ArcSegment(0.5, 0.5, 0.4, 0.4, -90, 90)]).sample();
    expect(pts.first.x, closeTo(0.5, 1e-9));
    expect(pts.first.y, closeTo(0.1, 1e-9));
    expect(pts.last.x, closeTo(0.9, 1e-9));
    expect(pts.last.y, closeTo(0.5, 1e-9));
  });

  test('segments join without duplicating the joint', () {
    final s = const Stroke([
      LineSegment([TracePoint(0.2, 0.1), TracePoint(0.2, 0.6)]),
      ArcSegment(0.5, 0.6, 0.3, 0.3, 180, -180),
    ]);
    final pts = s.sample(step: 0.05);
    for (var i = 1; i < pts.length; i++) {
      expect(pts[i].distanceTo(pts[i - 1]), greaterThan(0));
      expect(pts[i].distanceTo(pts[i - 1]), lessThan(0.08));
    }
    expect(pts.last.x, closeTo(0.8, 1e-9));
  });

  test('fromJson reads line and arc segments', () {
    final s = Stroke.fromJson([
      {'line': [[0.1, 0.1], [0.1, 0.9]]},
      {'arc': [0.5, 0.5, 0.2, 0.2, 0, 90]},
    ]);
    expect(s.segments, hasLength(2));
    expect(s.segments.first, isA<LineSegment>());
    expect(s.segments.last, isA<ArcSegment>());
  });

  test('every shipped letter has strokes that stay inside the box', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.lettersEn, hasLength(26));
    for (final l in bundle.lettersEn) {
      expect(l.strokes, isNotEmpty, reason: l.char);
      for (final s in l.strokes) {
        for (final p in s.sample()) {
          expect(p.x, inInclusiveRange(-0.01, 1.01), reason: l.char);
          expect(p.y, inInclusiveRange(-0.01, 1.01), reason: l.char);
        }
      }
    }
  });
}
