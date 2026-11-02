import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Shows a character: the configured image if any, otherwise a placeholder
/// (a painted ice princess for Elsa, the emoji for everyone else).
class CharacterView extends ConsumerWidget {
  const CharacterView({super.key, required this.id, this.size = 140});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = ref.watch(contentProvider).characters[id];
    final image = def?.image;
    if (image != null) {
      return Image.asset('content/$image', width: size, height: size, fit: BoxFit.contain);
    }
    if (id == 'elsa') {
      return CustomPaint(size: Size.square(size), painter: const PrincessPainter());
    }
    return SizedBox.square(
      dimension: size,
      child: Center(child: Text(def?.emoji ?? '❓', style: TextStyle(fontSize: size * 0.6))),
    );
  }
}

class PrincessPainter extends CustomPainter {
  const PrincessPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dress = Path()
      ..moveTo(w * 0.5, h * 0.42)
      ..lineTo(w * 0.18, h * 0.98)
      ..quadraticBezierTo(w * 0.5, h * 1.02, w * 0.82, h * 0.98)
      ..close();
    canvas.drawPath(
      dress,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB3E5FC), Color(0xFF4FC3F7)],
        ).createShader(Offset.zero & size),
    );
    final hair = Paint()..color = const Color(0xFFFFF3C4);
    canvas.drawOval(Rect.fromLTWH(w * 0.52, h * 0.22, w * 0.16, h * 0.40), hair);
    canvas.drawCircle(Offset(w * 0.5, h * 0.26), w * 0.15, Paint()..color = const Color(0xFFFFE0CC));
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.5, h * 0.24), radius: w * 0.17), pi, pi, true, hair);
    final eye = Paint()..color = const Color(0xFF1E5AA8);
    canvas.drawCircle(Offset(w * 0.45, h * 0.27), w * 0.018, eye);
    canvas.drawCircle(Offset(w * 0.55, h * 0.27), w * 0.018, eye);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.31), width: w * 0.08, height: h * 0.04),
      0,
      pi,
      false,
      Paint()
        ..color = const Color(0xFFE57373)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012,
    );
    final sparkle = Paint()..color = Colors.white;
    for (final p in [
      Offset(w * 0.35, h * 0.75),
      Offset(w * 0.6, h * 0.65),
      Offset(w * 0.5, h * 0.88),
      Offset(w * 0.68, h * 0.85),
    ]) {
      canvas.drawCircle(p, w * 0.015, sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
