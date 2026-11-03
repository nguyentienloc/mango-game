import 'dart:math';

import 'package:flutter/foundation.dart';
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

/// Shortest path (in pad units) that counts as a stroke rather than a tap.
const _kMinStrokeLength = 0.04;

/// How long a finished stroke's ink takes to melt away.
const _kFadeDuration = Duration(milliseconds: 300);

/// The ink under the child's finger: saturated blue so it reads on the white
/// board, yet lighter than the navy ([IceColors.deep]) of completed strokes.
const _kLiveInk = Color(0xFF1565C0);

/// Live ink width as a fraction of the pad's side.
const _kInkWidth = 0.075;

/// Dashed guide paths only depend on the strokes and the pad size, so they are
/// built once instead of on every pointer move.
class _DashCache {
  List<List<TracePoint>>? _strokes;
  double _side = 0;
  final Map<int, Path> _paths = {};

  Path get(
    List<List<TracePoint>> strokes,
    int index,
    double side,
    Path Function() build,
  ) {
    if (!identical(_strokes, strokes) || _side != side) {
      _strokes = strokes;
      _side = side;
      _paths.clear();
    }
    return _paths.putIfAbsent(index, build);
  }
}

class _TracePadState extends State<TracePad> with SingleTickerProviderStateMixin {
  /// Points of the stroke being drawn; only the ink layer listens to it.
  final _drawing = ValueNotifier<List<TracePoint>>(const []);

  /// The last finished stroke, fading out while [_fade] runs (1 -> 0).
  final _fading = ValueNotifier<List<TracePoint>>(const []);
  late final AnimationController _fade = AnimationController(vsync: this, duration: _kFadeDuration);

  /// The pointer currently drawing; other fingers are ignored until it lifts.
  int? _pointer;

  final _dashCache = _DashCache();

  @override
  void dispose() {
    _fade.dispose();
    _drawing.dispose();
    _fading.dispose();
    super.dispose();
  }

  TracePoint _point(Offset local, double side) => TracePoint(
    (local.dx / side).clamp(0.0, 1.0),
    (local.dy / side).clamp(0.0, 1.0),
  );

  static double _length(List<TracePoint> pts) {
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      total += pts[i - 1].distanceTo(pts[i]);
    }
    return total;
  }

  void _down(PointerDownEvent e, double side) {
    if (!widget.enabled) return;
    // A palm or thumb resting first must not own the pad: if the owner has
    // barely moved, the new finger takes over.
    if (_pointer != null && _length(_drawing.value) >= _kMinStrokeLength) return;
    _pointer = e.pointer;
    _drawing.value = [_point(e.localPosition, side)];
  }

  void _end(PointerEvent e, {required bool cancelled}) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final drawn = _drawing.value;
    _drawing.value = const [];
    // A tap or a dab with a little jitter is not a stroke: say nothing.
    if (!cancelled &&
        widget.enabled &&
        drawn.length >= 2 &&
        _length(drawn) >= _kMinStrokeLength) {
      // The ink melts away instead of vanishing; it never blocks a new touch.
      _fading.value = drawn;
      _fade.forward(from: 0);
      widget.onStrokeDrawn(List.of(drawn));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = min(c.maxWidth, c.maxHeight);
        // A Listener (not a pan recognizer) so the very first touch point is
        // recorded: a pan only starts after the touch slop and would drop it.
        return SizedBox.square(
          key: const Key('trace-pad'),
          dimension: side,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _down(e, side),
            onPointerMove: (e) {
              if (e.pointer != _pointer) return;
              _drawing.value = [..._drawing.value, _point(e.localPosition, side)];
            },
            onPointerUp: (e) => _end(e, cancelled: false),
            onPointerCancel: (e) => _end(e, cancelled: true),
            child: Stack(
              children: [
                // Static guide: repaints only when strokes / current / size change.
                RepaintBoundary(
                  key: const Key('trace-guide'),
                  child: CustomPaint(
                    size: Size.square(side),
                    painter: _GuidePainter(widget.strokes, widget.current, _dashCache),
                  ),
                ),
                // Live ink: repaints on every pointer move and fade frame.
                RepaintBoundary(
                  key: const Key('trace-ink'),
                  child: CustomPaint(
                    size: Size.square(side),
                    painter: TraceInkPainter(_drawing, _fading, _fade),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Paint _strokePaint(Color color, double w, {bool dashed = false}) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Path _polyPath(List<TracePoint> pts, double side) {
  final path = Path()..moveTo(pts.first.x * side, pts.first.y * side);
  for (final p in pts.skip(1)) {
    path.lineTo(p.x * side, p.y * side);
  }
  return path;
}

RRect _padShape(Size size) =>
    RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24));

/// The finger's ink: the stroke being drawn at full strength plus the last
/// finished one fading out.
class TraceInkPainter extends CustomPainter {
  TraceInkPainter(this.drawing, this.fading, this.fade)
    : super(repaint: Listenable.merge([drawing, fading, fade]));

  final ValueListenable<List<TracePoint>> drawing;
  final ValueListenable<List<TracePoint>> fading;
  final Animation<double> fade;

  /// 1 right after a stroke ends, 0 once it has faded away (also when idle).
  @visibleForTesting
  double get fadeOpacity => fading.value.isEmpty ? 0.0 : 1.0 - fade.value;

  void _ink(Canvas canvas, List<TracePoint> pts, double side, double opacity) {
    if (pts.length < 2 || opacity <= 0) return;
    final width = _kInkWidth * side;
    final p = _polyPath(pts, side);
    canvas.drawPath(
      p,
      _strokePaint(IceColors.ice.withValues(alpha: 0.7 * opacity), width * 1.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.6),
    );
    canvas.drawPath(p, _strokePaint(_kLiveInk.withValues(alpha: opacity), width));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.clipRRect(_padShape(size));
    _ink(canvas, fading.value, side, fadeOpacity);
    _ink(canvas, drawing.value, side, 1);
  }

  @override
  bool shouldRepaint(TraceInkPainter old) => true;
}

/// The white board, the letter's strokes, the number dot and the arrow.
class _GuidePainter extends CustomPainter {
  _GuidePainter(this.strokes, this.current, this.dashCache);

  final List<List<TracePoint>> strokes;
  final int current;
  final _DashCache dashCache;

  Offset _o(TracePoint p, double side) => Offset(p.x * side, p.y * side);

  /// Dashes measured along the path: [dash] drawn, [gap] skipped (in pad units).
  Path _dashed(
    List<TracePoint> pts,
    double side, {
    double dash = 0.05,
    double gap = 0.04,
  }) {
    final out = Path();
    for (final m in _polyPath(pts, side).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(
          m.extractPath(d, min(d + dash * side, m.length)),
          Offset.zero,
        );
        d += (dash + gap) * side;
      }
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final rrect = _padShape(size);
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    final width = 0.07 * side;
    final stroke = _strokePaint;

    for (var i = 0; i < strokes.length; i++) {
      final pts = strokes[i];
      if (pts.length < 2) continue;
      Path dashed() => dashCache.get(strokes, i, side, () => _dashed(pts, side));
      if (i < current) {
        canvas.drawPath(_polyPath(pts, side), stroke(IceColors.deep, width));
      } else if (i == current) {
        canvas.drawPath(
          dashed(),
          stroke(
            IceColors.frost.withValues(alpha: 0.6),
            width * 1.6,
            dashed: true,
          )..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.5),
        );
        canvas.drawPath(
          dashed(),
          stroke(IceColors.frost, width * 0.8, dashed: true),
        );
        _paintArrow(canvas, pts, side);
        _paintNumber(canvas, pts.first, i + 1, side);
      } else {
        canvas.drawPath(
          dashed(),
          stroke(Colors.grey.shade300, width * 0.8, dashed: true),
        );
      }
    }
  }

  void _paintNumber(Canvas canvas, TracePoint at, int n, double side) {
    final center = _o(at, side);
    canvas.drawCircle(center, 0.045 * side, Paint()..color = IceColors.deep);
    final tp = TextPainter(
      text: TextSpan(
        text: '$n',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 0.06 * side,
        ),
      ),
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
      ..lineTo(
        (a - dir * len * 0.4 + normal * len * 0.7).dx,
        (a - dir * len * 0.4 + normal * len * 0.7).dy,
      )
      ..lineTo(
        (a - dir * len * 0.4 - normal * len * 0.7).dx,
        (a - dir * len * 0.4 - normal * len * 0.7).dy,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = IceColors.deep);
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      !identical(old.strokes, strokes) || old.current != current;
}
