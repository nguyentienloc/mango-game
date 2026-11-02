import 'dart:math';

class TracePoint {
  const TracePoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(TracePoint o) => sqrt(pow(x - o.x, 2) + pow(y - o.y, 2));
}

sealed class StrokeSegment {
  const StrokeSegment();

  /// Points along the segment, about [step] apart, both ends included.
  List<TracePoint> sample(double step);

  static StrokeSegment fromJson(Map<String, dynamic> json) {
    final line = json['line'];
    if (line != null) {
      return LineSegment([
        for (final p in line as List) TracePoint(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
      ]);
    }
    final a = (json['arc'] as List).map((v) => (v as num).toDouble()).toList();
    return ArcSegment(a[0], a[1], a[2], a[3], a[4], a[5]);
  }
}

class LineSegment extends StrokeSegment {
  const LineSegment(this.points);

  final List<TracePoint> points;

  @override
  List<TracePoint> sample(double step) {
    final out = <TracePoint>[points.first];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final n = max(1, (a.distanceTo(b) / step).ceil());
      for (var k = 1; k <= n; k++) {
        out.add(TracePoint(a.x + (b.x - a.x) * k / n, a.y + (b.y - a.y) * k / n));
      }
    }
    return out;
  }
}

/// Elliptical arc. Angles in degrees; 0° points right and positive sweep is
/// clockwise on screen (y grows downwards).
class ArcSegment extends StrokeSegment {
  const ArcSegment(this.cx, this.cy, this.rx, this.ry, this.startDeg, this.sweepDeg);

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double startDeg;
  final double sweepDeg;

  @override
  List<TracePoint> sample(double step) {
    final sweep = sweepDeg * pi / 180;
    final n = max(2, (sweep.abs() * max(rx, ry) / step).ceil());
    final start = startDeg * pi / 180;
    return [
      for (var k = 0; k <= n; k++)
        TracePoint(cx + rx * cos(start + sweep * k / n), cy + ry * sin(start + sweep * k / n)),
    ];
  }
}

class Stroke {
  const Stroke(this.segments);

  factory Stroke.fromJson(List<dynamic> json) =>
      Stroke([for (final s in json) StrokeSegment.fromJson(s as Map<String, dynamic>)]);

  final List<StrokeSegment> segments;

  List<TracePoint> sample({double step = 0.02}) {
    final out = <TracePoint>[];
    for (final seg in segments) {
      final pts = seg.sample(step);
      out.addAll(out.isNotEmpty && out.last.distanceTo(pts.first) < 1e-6 ? pts.skip(1) : pts);
    }
    return out;
  }
}
