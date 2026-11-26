import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/animation_flags.dart';

/// Finds the falling snow layer in tests.
const kSnowfallKey = Key('snowfall');

/// `MaterialApp.builder` for the app: the navigator under [SnowfallOverlay].
Widget noelAppBuilder(BuildContext context, Widget? child) => SnowfallOverlay(child: child ?? const SizedBox.shrink());

/// Puts falling snow over [child] (the app's navigator, so every route and dialog gets it).
/// The snow never takes a touch. Off when [snowfallEnabledProvider] is false or the
/// system asks for no animations.
class SnowfallOverlay extends ConsumerWidget {
  const SnowfallOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(snowfallEnabledProvider) && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        child,
        if (on) const IgnorePointer(key: kSnowfallKey, child: RepaintBoundary(child: Snowfall())),
      ],
    );
  }
}

/// One flake: where it starts and how it moves; all fixed, so the snow is the same every launch.
class SnowFlake {
  const SnowFlake({
    required this.x,
    required this.start,
    required this.speed,
    required this.radius,
    required this.opacity,
    required this.swayAmp,
    required this.swayFreq,
    required this.swayPhase,
    required this.crystal,
  });

  /// Horizontal home, as a fraction of the width.
  final double x;

  /// Where it is at time 0, as a fraction of the fall.
  final double start;

  /// Fall speed in logical pixels per second.
  final double speed;

  /// Dot radius, or arm length for a [crystal].
  final double radius;
  final double opacity;

  /// Sideways sway: amplitude in pixels, angular frequency in radians per second, phase.
  final double swayAmp;
  final double swayFreq;
  final double swayPhase;

  /// A six-armed snowflake instead of a round dot.
  final bool crystal;

  /// [count] flakes, one in five a six-armed crystal. Near flakes (big) fall faster and
  /// are brighter than far ones, which gives a little depth.
  static List<SnowFlake> generate(int count, Random random) => [
        for (var i = 0; i < count; i++)
          () {
            final depth = random.nextDouble();
            final crystal = i % 5 == 4;
            return SnowFlake(
              x: random.nextDouble(),
              start: random.nextDouble(),
              speed: 14 + 30 * depth,
              radius: crystal ? 4 + 3 * depth : 1 + 2.2 * depth,
              opacity: 0.35 + 0.55 * depth,
              swayAmp: 6 + 14 * random.nextDouble(),
              swayFreq: 0.4 + 0.6 * random.nextDouble(),
              swayPhase: random.nextDouble() * 2 * pi,
              crystal: crystal,
            );
          }(),
      ];
}

/// The falling snow: one ticker (about 30 frames a second, plenty for slow snow) drives one painter.
class Snowfall extends StatefulWidget {
  const Snowfall({super.key, this.count = 50});

  final int count;

  @override
  State<Snowfall> createState() => _SnowfallState();
}

class _SnowfallState extends State<Snowfall> with SingleTickerProviderStateMixin {
  /// Seconds since the snow started.
  final _time = ValueNotifier<double>(0);
  late final List<SnowFlake> _flakes = SnowFlake.generate(widget.count, Random(2026));
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
      if (t - _time.value >= 1 / 30) _time.value = t;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(child: CustomPaint(painter: SnowfallPainter(_flakes, _time)));
}

class SnowfallPainter extends CustomPainter {
  SnowfallPainter(this.flakes, this.time) : super(repaint: time);

  final List<SnowFlake> flakes;
  final ValueListenable<double> time;

  static const _margin = 12.0;

  /// A six-armed flake with arms of length 1, each with a little V near its tip.
  static final Path _crystal = () {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      final dir = Offset(cos(a), sin(a));
      p
        ..moveTo(0, 0)
        ..lineTo(dir.dx, dir.dy);
      final at = dir * 0.6;
      for (final side in [-1, 1]) {
        final b = a + side * pi / 4;
        p
          ..moveTo(at.dx, at.dy)
          ..lineTo(at.dx + cos(b) * 0.3, at.dy + sin(b) * 0.3);
      }
    }
    return p;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final t = time.value;
    final travel = size.height + 2 * _margin;
    final dot = Paint()..isAntiAlias = true;
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final f in flakes) {
      final y = (f.start * travel + f.speed * t) % travel - _margin;
      final x = f.x * size.width + f.swayAmp * sin(f.swayFreq * t + f.swayPhase);
      final color = Colors.white.withValues(alpha: f.opacity);
      if (f.crystal) {
        canvas
          ..save()
          ..translate(x, y)
          ..rotate(f.swayPhase + 0.3 * t)
          ..scale(f.radius);
        arm
          ..color = color
          ..strokeWidth = 1.1 / f.radius;
        canvas
          ..drawPath(_crystal, arm)
          ..restore();
      } else {
        dot.color = color;
        canvas.drawCircle(Offset(x, y), f.radius, dot);
      }
    }
  }

  @override
  bool shouldRepaint(SnowfallPainter old) => !identical(old.flakes, flakes) || old.time != time;
}
