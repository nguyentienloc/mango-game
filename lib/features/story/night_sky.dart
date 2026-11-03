import 'dart:math';

import 'package:flutter/material.dart';

class NightColors {
  static const navy = Color(0xFF0B1240);
  static const purple = Color(0xFF3B1E6E);
  static const star = Color(0xFFFFF8D6);
  static const text = Colors.white;
}

/// Bedtime background: a navy → purple sky with a few softly twinkling stars.
/// One slow animation drives a single painter (no rebuilds).
class NightSky extends StatefulWidget {
  const NightSky({super.key, this.child});

  final Widget? child;

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky> with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 4))
    ..repeat();

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NightColors.navy, NightColors.purple],
        ),
      ),
      child: CustomPaint(
        painter: _StarsPainter(_twinkle),
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  /// (x, y, radius, phase) in fractions of the size; fixed so the sky does not jump.
  static const _stars = [
    (0.08, 0.06, 2.2, 0.0),
    (0.27, 0.13, 1.6, 0.35),
    (0.52, 0.05, 2.6, 0.7),
    (0.74, 0.11, 1.8, 0.15),
    (0.92, 0.04, 2.0, 0.55),
    (0.15, 0.30, 1.4, 0.85),
    (0.86, 0.27, 2.4, 0.25),
    (0.40, 0.22, 1.5, 0.6),
    (0.62, 0.36, 1.7, 0.9),
    (0.05, 0.55, 1.9, 0.45),
    (0.95, 0.60, 1.5, 0.05),
    (0.33, 0.70, 1.3, 0.75),
    (0.70, 0.82, 1.8, 0.3),
    (0.12, 0.90, 1.6, 0.65),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = NightColors.star;
    for (final (x, y, r, phase) in _stars) {
      final glow = 0.35 + 0.65 * (0.5 + 0.5 * sin(2 * pi * (t.value + phase)));
      paint.color = NightColors.star.withValues(alpha: glow);
      canvas.drawCircle(Offset(x * size.width, y * size.height), r * (0.8 + 0.3 * glow), paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.t != t;
}
