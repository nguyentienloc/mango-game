import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/content/strokes.dart';

/// A square drawing pad: shows the letter's strokes as a guide and reports each
/// finished finger stroke as points normalised to 0..1.
class TracePad extends StatefulWidget {
  const TracePad({
    super.key,
    required this.strokes,
    required this.current,
    required this.onStrokeDrawn,
    this.enabled = true,
  });

  /// Sampled target points of every stroke of the letter.
  final List<List<TracePoint>> strokes;
  final int current;
  final ValueChanged<List<TracePoint>> onStrokeDrawn;
  final bool enabled;

  @override
  State<TracePad> createState() => _TracePadState();
}

class _TracePadState extends State<TracePad> {
  List<TracePoint> _drawing = [];

  TracePoint _point(Offset local, double side) =>
      TracePoint((local.dx / side).clamp(0.0, 1.0), (local.dy / side).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      return SizedBox.square(
        key: const Key('trace-pad'),
        dimension: side,
        child: GestureDetector(
          onPanStart: (d) {
            if (!widget.enabled) return;
            setState(() => _drawing = [_point(d.localPosition, side)]);
          },
          onPanUpdate: (d) {
            if (!widget.enabled) return;
            setState(() => _drawing = [..._drawing, _point(d.localPosition, side)]);
          },
          onPanEnd: (_) {
            final drawn = _drawing;
            setState(() => _drawing = []);
            if (widget.enabled && drawn.length >= 2) widget.onStrokeDrawn(List.of(drawn));
          },
          onPanCancel: () {
            if (_drawing.isNotEmpty) setState(() => _drawing = []);
          },
          child: CustomPaint(
            size: Size.square(side),
            painter: _TracePainter(widget.strokes, widget.current, _drawing),
          ),
        ),
      );
    });
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.strokes, this.current, this.drawing);

  final List<List<TracePoint>> strokes;
  final int current;
  final List<TracePoint> drawing;

  Offset _o(TracePoint p, double side) => Offset(p.x * side, p.y * side);

  Path _path(List<TracePoint> pts, double side) {
    final path = Path()..moveTo(pts.first.x * side, pts.first.y * side);
    for (final p in pts.skip(1)) {
      path.lineTo(p.x * side, p.y * side);
    }
    return path;
  }

  /// Alternating segments: [on] sample points drawn, [off] skipped.
  Path _dashed(List<TracePoint> pts, double side, {int on = 2, int off = 2}) {
    final path = Path();
    var i = 0;
    while (i < pts.length - 1) {
      final end = min(i + on, pts.length - 1);
      path.moveTo(pts[i].x * side, pts[i].y * side);
      for (var k = i + 1; k <= end; k++) {
        path.lineTo(pts[k].x * side, pts[k].y * side);
      }
      i += on + off;
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      Paint()..color = Colors.white,
    );
    final width = 0.07 * side;
    Paint stroke(Color color, double w) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < strokes.length; i++) {
      final pts = strokes[i];
      if (pts.length < 2) continue;
      if (i < current) {
        canvas.drawPath(_path(pts, side), stroke(IceColors.deep, width));
      } else if (i == current) {
        canvas.drawPath(
          _dashed(pts, side),
          stroke(IceColors.frost.withValues(alpha: 0.6), width * 1.6)..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.5),
        );
        canvas.drawPath(_dashed(pts, side), stroke(IceColors.frost, width * 0.8));
        _paintArrow(canvas, pts, side);
        _paintNumber(canvas, pts.first, i + 1, side);
      } else {
        canvas.drawPath(_dashed(pts, side), stroke(Colors.grey.shade300, width * 0.8));
      }
    }

    if (drawing.length >= 2) {
      final p = _path(drawing, side);
      canvas.drawPath(p, stroke(IceColors.ice.withValues(alpha: 0.7), width * 1.8)..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.6));
      canvas.drawPath(p, stroke(const Color(0xFFD6F0FF), width));
    }
  }

  void _paintNumber(Canvas canvas, TracePoint at, int n, double side) {
    final center = _o(at, side);
    canvas.drawCircle(center, 0.045 * side, Paint()..color = IceColors.deep);
    final tp = TextPainter(
      text: TextSpan(text: '$n', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 0.06 * side)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintArrow(Canvas canvas, List<TracePoint> pts, double side) {
    final i = ((pts.length - 1) * 0.25).floor().clamp(0, pts.length - 2);
    final a = _o(pts[i], side);
    final b = _o(pts[i + 1], side);
    final d = b - a;
    if (d.distance == 0) return;
    final dir = d / d.distance;
    final normal = Offset(-dir.dy, dir.dx);
    final len = 0.05 * side;
    final tip = a + dir * len;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((a - dir * len * 0.4 + normal * len * 0.7).dx, (a - dir * len * 0.4 + normal * len * 0.7).dy)
      ..lineTo((a - dir * len * 0.4 - normal * len * 0.7).dx, (a - dir * len * 0.4 - normal * len * 0.7).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = IceColors.deep);
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.strokes != strokes || old.current != current || old.drawing != drawing;
}
