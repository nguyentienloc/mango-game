import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Placeholder ice castle drawn in code; each level adds a part. Dressed for Christmas:
/// fairy lights on the wall (from level 2) and a tree beside it.
class CastleView extends StatelessWidget {
  const CastleView({super.key, required this.level, this.width = 260});

  final int level;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, width * 0.85), painter: CastlePainter(level));
  }
}

class CastlePainter extends CustomPainter {
  CastlePainter(this.level);

  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ice = Paint()..color = const Color(0xFFBFE9FF);
    final iceDark = Paint()..color = const Color(0xFF7CC8F2);

    canvas.drawOval(Rect.fromLTWH(w * 0.05, h * 0.82, w * 0.9, h * 0.16), iceDark);
    if (level >= 2) canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.45, w * 0.5, h * 0.42), ice);
    if (level >= 3) {
      final door = Path()
        ..moveTo(w * 0.43, h * 0.87)
        ..lineTo(w * 0.43, h * 0.70)
        ..arcToPoint(Offset(w * 0.57, h * 0.70), radius: Radius.circular(w * 0.07))
        ..lineTo(w * 0.57, h * 0.87)
        ..close();
      canvas.drawPath(door, iceDark);
    }

    void tower(double x) {
      canvas.drawRect(Rect.fromLTWH(x, h * 0.30, w * 0.16, h * 0.57), ice);
      final roof = Path()
        ..moveTo(x - w * 0.02, h * 0.30)
        ..lineTo(x + w * 0.08, h * 0.08)
        ..lineTo(x + w * 0.18, h * 0.30)
        ..close();
      canvas.drawPath(roof, iceDark);
    }

    if (level >= 4) tower(w * 0.10);
    if (level >= 5) {
      final step = Paint()..color = Colors.white;
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(Rect.fromLTWH(w * (0.38 - i * 0.03), h * (0.87 + i * 0.025), w * (0.24 + i * 0.06), h * 0.025), step);
      }
    }
    if (level >= 6) {
      final light = Paint()..color = const Color(0xFFFFF59D);
      final center = Offset(w * 0.5, h * 0.56);
      canvas.drawCircle(center, w * 0.045, light);
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3;
        canvas.drawCircle(center + Offset(cos(a), sin(a)) * w * 0.07, w * 0.012, light);
      }
    }
    if (level >= 7) tower(w * 0.74);
    if (level >= 8) {
      const colors = [Color(0xFFFF8A80), Color(0xFFFFD180), Color(0xFFB388FF)];
      final centers = [Offset(w * 0.2, h * 0.08), Offset(w * 0.8, h * 0.1), Offset(w * 0.5, h * 0.04)];
      for (var c = 0; c < centers.length; c++) {
        final paint = Paint()
          ..color = colors[c]
          ..strokeWidth = w * 0.01
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          final dir = Offset(cos(a), sin(a));
          canvas.drawLine(centers[c] + dir * w * 0.02, centers[c] + dir * w * 0.06, paint);
        }
      }
    }
    if (level >= 2) _fairyLights(canvas, size);
    _tree(canvas, size);
  }

  static const _bulbs = [NoelColors.lightRed, NoelColors.gold, NoelColors.lightGreen, NoelColors.lightBlue];

  /// A drooping string of coloured bulbs along the top of the wall (from tower to tower once
  /// they are built).
  void _fairyLights(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final from = Offset(w * (level >= 4 ? 0.18 : 0.25), h * (level >= 4 ? 0.36 : 0.46));
    final to = Offset(w * (level >= 7 ? 0.82 : 0.75), h * (level >= 7 ? 0.36 : 0.46));
    final sag = h * 0.07;
    Offset at(double t) {
      final p = Offset.lerp(from, to, t)!;
      return p + Offset(0, sag * 4 * t * (1 - t));
    }

    final wire = Path()..moveTo(from.dx, from.dy);
    for (var i = 1; i <= 20; i++) {
      final p = at(i / 20);
      wire.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      wire,
      Paint()
        ..color = const Color(0xFF1B3A2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, w * 0.006),
    );
    const count = 9;
    final r = w * 0.016;
    for (var i = 0; i < count; i++) {
      final p = at((i + 0.5) / count) + Offset(0, r * 0.8);
      final color = _bulbs[i % _bulbs.length];
      canvas
        ..drawCircle(
          p,
          r * 2.2,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
        )
        ..drawCircle(p, r, Paint()..color = color);
    }
  }

  /// The Christmas tree beside the castle, with a gold star and baubles.
  void _tree(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.92;
    final bottom = h * 0.9;
    final height = h * 0.4;
    final half = w * 0.075;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, bottom - height * 0.04), width: half * 0.4, height: height * 0.1),
      Paint()..color = const Color(0xFF6D4C41),
    );
    final green = Paint()..color = NoelColors.green;
    final dark = Paint()..color = const Color(0xFF1B5E20);
    for (final (top, base, width, paint) in [
      (0.0, 0.45, 0.6, dark),
      (0.22, 0.72, 0.82, green),
      (0.45, 0.92, 1.0, dark),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx, bottom - height * (1 - top))
          ..lineTo(cx + half * width, bottom - height * (1 - base))
          ..lineTo(cx - half * width, bottom - height * (1 - base))
          ..close(),
        paint,
      );
    }
    final r = w * 0.012;
    for (final (dx, dy, color) in [
      (-0.3, 0.42, NoelColors.lightRed),
      (0.35, 0.5, NoelColors.gold),
      (-0.45, 0.68, NoelColors.lightBlue),
      (0.2, 0.72, NoelColors.lightRed),
      (-0.1, 0.86, NoelColors.gold),
      (0.55, 0.88, NoelColors.lightGreen),
    ]) {
      canvas.drawCircle(Offset(cx + dx * half, bottom - height * (1 - dy)), r, Paint()..color = color);
    }
    final star = Offset(cx, bottom - height);
    final s = w * 0.03;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? s : s * 0.45;
      final p = star + Offset(cos(a), sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = NoelColors.gold);
  }

  @override
  bool shouldRepaint(covariant CastlePainter oldDelegate) => oldDelegate.level != level;
}
