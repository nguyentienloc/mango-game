import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/animation_flags.dart';
import '../app/theme.dart';

/// How much of the Noel scene to draw.
enum NoelScene {
  /// The home screen: aurora, moon, mountains, a snowy ridge with pines and two little
  /// houses, and a bright hill in front for the castle to stand on.
  home,

  /// Game screens: the same sky, mountains far away and a low snow hill at the bottom.
  game,
}

/// A game screen's Noel background: [NoelSky] behind [child], which sits in the safe area.
class NoelBackground extends StatelessWidget {
  const NoelBackground({super.key, required this.child, this.scene = NoelScene.game});

  final Widget child;
  final NoelScene scene;

  @override
  Widget build(BuildContext context) => NoelSky(scene: scene, child: SafeArea(child: child));
}

/// The Christmas night sky, filling its box. The scene is painted once (cached in its own
/// layer); only three small gold sparkles twinkle, unless animations are off.
class NoelSky extends ConsumerWidget {
  const NoelSky({super.key, this.scene = NoelScene.game, this.child});

  final NoelScene scene;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twinkle = ref.watch(animationsEnabledProvider) && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        RepaintBoundary(child: CustomPaint(isComplex: true, painter: NoelSkyPainter(scene))),
        RepaintBoundary(child: twinkle ? _Twinkle(scene) : CustomPaint(painter: SparklePainter(scene))),
        ?child,
      ],
    );
  }
}

class _Twinkle extends StatefulWidget {
  const _Twinkle(this.scene);

  final NoelScene scene;

  @override
  State<_Twinkle> createState() => _TwinkleState();
}

class _TwinkleState extends State<_Twinkle> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: SparklePainter(widget.scene, _t));
}

/// Fractions of the box for the parts that differ between the two scenes.
class _Layout {
  const _Layout({
    required this.skyStops,
    required this.aurora,
    required this.moon,
    required this.starsBottom,
  });

  final List<double> skyStops;

  /// Top and bottom of the aurora band, as fractions of the height.
  final (double, double) aurora;

  /// Moon centre, as fractions of the size.
  final (double, double) moon;

  /// Stars stay above this fraction of the height.
  final double starsBottom;

  static const home = _Layout(skyStops: [0, 0.45, 0.8, 1], aurora: (0.15, 0.38), moon: (0.74, 0.16), starsBottom: 0.55);
  static const game = _Layout(skyStops: [0, 0.45, 0.88, 1], aurora: (0.1, 0.26), moon: (0.6, 0.045), starsBottom: 0.75);

  static _Layout of(NoelScene s) => s == NoelScene.home ? home : game;
}

/// Small white stars: (x, y, radius, opacity), y as a fraction of the starry part.
const _stars = [
  (0.06, 0.05, 1.4, 0.9),
  (0.18, 0.14, 1.0, 0.7),
  (0.30, 0.04, 1.6, 0.85),
  (0.41, 0.19, 1.1, 0.6),
  (0.52, 0.09, 1.3, 0.8),
  (0.63, 0.02, 1.0, 0.7),
  (0.92, 0.17, 1.5, 0.85),
  (0.97, 0.05, 1.1, 0.7),
  (0.10, 0.33, 1.2, 0.65),
  (0.25, 0.45, 1.0, 0.6),
  (0.47, 0.38, 1.8, 0.9),
  (0.58, 0.55, 1.1, 0.55),
  (0.72, 0.30, 1.3, 0.75),
  (0.86, 0.42, 1.0, 0.6),
  (0.04, 0.70, 1.2, 0.6),
  (0.35, 0.80, 1.0, 0.5),
  (0.68, 0.75, 1.4, 0.7),
  (0.94, 0.88, 1.1, 0.55),
];

/// The still part of the scene. Never repaints unless its size changes.
class NoelSkyPainter extends CustomPainter {
  const NoelSkyPainter(this.scene);

  final NoelScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final layout = _Layout.of(scene);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [NoelColors.skyTop, NoelColors.skyHigh, NoelColors.skyLow, NoelColors.skyHorizon],
          stops: layout.skyStops,
        ).createShader(rect),
    );
    // Too small for a scene (a test, a collapsing layout): the gradient is enough.
    if (w < 24 || h < 24) return;
    _aurora(canvas, size, layout);
    _starsAndMoon(canvas, size, layout);
    if (scene == NoelScene.home) {
      _homeLand(canvas, size);
    } else {
      _gameLand(canvas, size);
    }
  }

  void _aurora(Canvas canvas, Size size, _Layout layout) {
    final w = size.width;
    final h = size.height;
    final (top, bottom) = layout.aurora;
    final blur = max(1.0, h * 0.015);
    for (final (shift, alpha) in [(0.0, 0.3), (0.35, 0.22)]) {
      final y0 = h * (top + (bottom - top) * shift * 0.5);
      final band = h * (bottom - top) * 0.45;
      final path = Path()..moveTo(0, y0 + band * 0.4);
      const steps = 24;
      for (var i = 1; i <= steps; i++) {
        final x = w * i / steps;
        path.lineTo(x, y0 + band * 0.4 * sin(i / steps * 2 * pi * 1.2 + shift * 5) + band * 0.3 * (i / steps));
      }
      for (var i = steps; i >= 0; i--) {
        final x = w * i / steps;
        path.lineTo(x, y0 + band + band * 0.3 * sin(i / steps * 2 * pi * 0.9 + 1 + shift * 4) + band * 0.3 * (i / steps));
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              NoelColors.auroraGreen.withValues(alpha: alpha),
              NoelColors.auroraPurple.withValues(alpha: alpha),
            ],
          ).createShader(Offset.zero & size)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  void _starsAndMoon(Canvas canvas, Size size, _Layout layout) {
    final w = size.width;
    final h = size.height;
    final star = Paint();
    for (final (x, y, r, a) in _stars) {
      star.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(x * w, y * h * layout.starsBottom), r, star);
    }
    final (mx, my) = layout.moon;
    final r = (min(w, h) * 0.056).clamp(8.0, 26.0);
    final c = Offset(mx * w, max(my * h, r * 1.6));
    canvas.drawCircle(
      c,
      r * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: [NoelColors.moon.withValues(alpha: 0.35), NoelColors.moon.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 2.2)),
    );
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c + Offset(r * 0.5, -r * 0.25), radius: r * 0.85)),
    );
    canvas.drawPath(crescent, Paint()..color = NoelColors.moon);
  }

  /// A mountain range: peaks at (x, y) fractions of [area], filled down to its bottom;
  /// the peaks listed in [capped] get a snow cap.
  void _mountains(Canvas canvas, Rect area, List<(double, double)> peaks, Color color, Set<int> capped) {
    Offset p((double, double) f) => Offset(area.left + f.$1 * area.width, area.top + f.$2 * area.height);
    final path = Path()..moveTo(area.left, area.bottom);
    for (final f in peaks) {
      final o = p(f);
      path.lineTo(o.dx, o.dy);
    }
    path
      ..lineTo(area.right, area.bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    final snow = Paint()..color = Colors.white.withValues(alpha: 0.92);
    for (final i in capped) {
      if (i <= 0 || i >= peaks.length - 1) continue;
      final top = p(peaks[i]);
      final left = Offset.lerp(top, p(peaks[i - 1]), 0.28)!;
      final right = Offset.lerp(top, p(peaks[i + 1]), 0.28)!;
      final dip = (left.dy - top.dy) * 0.25;
      final cap = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(Offset.lerp(top, right, 0.5)!.dx, right.dy - dip)
        ..lineTo(top.dx, left.dy)
        ..lineTo(Offset.lerp(top, left, 0.5)!.dx, left.dy - dip)
        ..lineTo(left.dx, left.dy)
        ..close();
      canvas.drawPath(cap, snow);
    }
  }

  /// A small pine: two stacked triangles standing at [base].
  void _pine(Canvas canvas, Offset base, double height, Paint paint) {
    final half = height * 0.32;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy - height)
        ..lineTo(base.dx + half * 0.75, base.dy - height * 0.45)
        ..lineTo(base.dx - half * 0.75, base.dy - height * 0.45)
        ..close()
        ..moveTo(base.dx, base.dy - height * 0.7)
        ..lineTo(base.dx + half, base.dy)
        ..lineTo(base.dx - half, base.dy)
        ..close(),
      paint,
    );
  }

  void _house(Canvas canvas, Offset base, double width) {
    final hgt = width * 0.62;
    final body = Rect.fromLTWH(base.dx - width / 2, base.dy - hgt, width, hgt);
    canvas.drawRect(body, Paint()..color = const Color(0xFF2A4C74));
    final roof = Path()
      ..moveTo(body.left - width * 0.12, body.top + 1)
      ..lineTo(body.center.dx, body.top - width * 0.45)
      ..lineTo(body.right + width * 0.12, body.top + 1)
      ..close();
    canvas.drawPath(roof, Paint()..color = Colors.white);
    final light = Paint()..color = NoelColors.window;
    final win = width * 0.2;
    canvas
      ..drawRect(Rect.fromLTWH(body.left + width * 0.16, body.top + hgt * 0.3, win, win), light)
      ..drawRect(Rect.fromLTWH(body.right - width * 0.16 - win, body.top + hgt * 0.3, win, win), light)
      ..drawCircle(
        body.center,
        width * 0.7,
        Paint()
          ..color = NoelColors.window.withValues(alpha: 0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.3),
      );
  }

  void _homeLand(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _mountains(
      canvas,
      Rect.fromLTWH(0, h * 0.46, w, h * 0.34),
      const [(0, 0.5), (0.12, 0.22), (0.27, 0.45), (0.42, 0.05), (0.58, 0.4), (0.72, 0.15), (0.88, 0.42), (1, 0.25)],
      NoelColors.mountainFar,
      const {3, 5},
    );
    _mountains(
      canvas,
      Rect.fromLTWH(0, h * 0.58, w, h * 0.24),
      const [(0, 0.3), (0.18, 0.05), (0.35, 0.5), (0.52, 0.2), (0.7, 0.55), (0.85, 0.12), (1, 0.4)],
      NoelColors.mountainNear,
      const {},
    );
    // The snowfield ridge with its pines and two houses.
    double ridgeY(double x) => h * (0.745 + 0.02 * sin(x / w * 2 * pi * 1.3 + 0.6));
    final ridge = Path()..moveTo(0, ridgeY(0));
    for (var x = 0.0; x <= w; x += max(4, w / 60)) {
      ridge.lineTo(x, ridgeY(x));
    }
    ridge
      ..lineTo(w, ridgeY(w))
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ridge, Paint()..color = NoelColors.ridge);
    final pine = Paint()..color = NoelColors.pine;
    for (final (x, s) in const [
      (0.04, 1.0),
      (0.08, 0.75),
      (0.17, 0.9),
      (0.21, 0.7),
      (0.4, 0.8),
      (0.6, 0.75),
      (0.66, 1.0),
      (0.79, 0.85),
      (0.93, 1.0),
      (0.97, 0.7),
    ]) {
      _pine(canvas, Offset(x * w, ridgeY(x * w) + 2), h * 0.05 * s, pine);
    }
    final house = (w * 0.06).clamp(10.0, 30.0);
    _house(canvas, Offset(w * 0.3, ridgeY(w * 0.3) + 2), house);
    _house(canvas, Offset(w * 0.86, ridgeY(w * 0.86) + 2), house * 0.85);
    _hill(canvas, size, crest: h * 0.82, edges: h * 0.87);
  }

  void _gameLand(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hill = (h * 0.06).clamp(18.0, 54.0);
    final range = (h * 0.09).clamp(20.0, 90.0);
    _mountains(
      canvas,
      Rect.fromLTWH(0, h - hill - range, w, range + hill),
      const [(0, 0.45), (0.15, 0.1), (0.3, 0.5), (0.47, 0.0), (0.63, 0.45), (0.8, 0.12), (1, 0.4)],
      NoelColors.mountainFar,
      const {3, 5},
    );
    _hill(canvas, size, crest: h - hill * 1.25, edges: h - hill * 0.8);
  }

  /// The bright snow hill in front, highest in the middle.
  void _hill(Canvas canvas, Size size, {required double crest, required double edges}) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, edges)
      ..quadraticBezierTo(w * 0.5, crest - (edges - crest), w, edges)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [NoelColors.snowLight, NoelColors.snowShade],
        ).createShader(Rect.fromLTRB(0, crest, w, h)),
    );
  }

  @override
  bool shouldRepaint(NoelSkyPainter old) => old.scene != scene;
}

/// Three pale gold four-point stars; with [twinkle] they slowly brighten and fade in turn.
class SparklePainter extends CustomPainter {
  SparklePainter(this.scene, [this.twinkle]) : super(repaint: twinkle);

  final NoelScene scene;
  final Animation<double>? twinkle;

  static const _home = [(0.14, 0.07, 7.0), (0.55, 0.04, 6.0), (0.4, 0.27, 5.0)];
  static const _game = [(0.12, 0.05, 6.0), (0.5, 0.03, 5.0), (0.66, 0.16, 5.0)];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 24 || size.height < 24) return;
    final t = twinkle?.value ?? 0.25;
    final paint = Paint();
    for (final (i, (x, y, r)) in (scene == NoelScene.home ? _home : _game).indexed) {
      final glow = 0.55 + 0.45 * sin(2 * pi * (t + i / 3));
      paint.color = NoelColors.sparkle.withValues(alpha: glow);
      final c = Offset(x * size.width, y * size.height);
      final s = r * (0.85 + 0.15 * glow);
      final k = s * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + k, c.dy - k)
          ..lineTo(c.dx + s, c.dy)
          ..lineTo(c.dx + k, c.dy + k)
          ..lineTo(c.dx, c.dy + s)
          ..lineTo(c.dx - k, c.dy + k)
          ..lineTo(c.dx - s, c.dy)
          ..lineTo(c.dx - k, c.dy - k)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SparklePainter old) => old.scene != scene || old.twinkle != twinkle;
}
