import 'dart:math';

import 'package:flutter/material.dart';

/// Placeholder ice castle drawn in code; each level adds a part.
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
  }

  @override
  bool shouldRepaint(covariant CastlePainter oldDelegate) => oldDelegate.level != level;
}
