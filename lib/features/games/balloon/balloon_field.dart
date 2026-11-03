import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme.dart';
import 'balloon_logic.dart';

/// The eight bright balloon colours ([kBalloonColors] of them).
const kBalloonPalette = <Color>[
  Color(0xFFFF5A5F),
  Color(0xFFFF9F1C),
  Color(0xFFFFD23F),
  Color(0xFF4CD964),
  Color(0xFF2EC4B6),
  Color(0xFF3A86FF),
  Color(0xFF9B5DE5),
  Color(0xFFFF70A6),
];

const _alphabetAZ = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];

const _popSeconds = 0.25;
const _tapPad = 12.0; // extra tap area around a balloon, dp
const _wobble = 12.0; // horizontal sway, dp
const _stringHeight = 40.0;

/// Colourful letter balloons rising through the field. Tapping one pops it and
/// calls [onPop] with its letter; the field keeps 5 to 6 balloons (6 when at
/// least 360 dp wide) alive, never two with the same letter, and always has a
/// balloon for [target] in the tree.
class BalloonField extends StatefulWidget {
  const BalloonField({
    super.key,
    required this.target,
    required this.onPop,
    required this.random,
    this.hint,
    this.enabled = true,
    this.alphabet = _alphabetAZ,
  });

  final String target;
  final ValueChanged<String> onPop;

  /// The letter whose balloon should glow, if any.
  final String? hint;
  final Random random;
  final bool enabled;
  final List<String> alphabet;

  @override
  State<BalloonField> createState() => _BalloonFieldState();
}

class _Live {
  _Live(this.balloon);

  final Balloon balloon;
  double? poppedAt;
}

double _diameter(Balloon b) => 84 + 12 * (b.wobblePhase / (2 * pi));

class _BalloonFieldState extends State<BalloonField> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final BalloonSpawner _spawner;
  final _live = <_Live>[];
  Size _size = Size.zero;
  double _t = 0;
  int _nextId = 0;
  bool _filled = false;

  /// True after the target's balloon was popped (correctly) until the target
  /// changes, so the popped letter is not spawned again while the screen
  /// celebrates.
  bool _holdTarget = false;

  @override
  void initState() {
    super.initState();
    _spawner = BalloonSpawner(alphabet: widget.alphabet, random: widget.random);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(BalloonField old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) _holdTarget = false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_size.isEmpty) return;
    _live.removeWhere((l) {
      final popped = l.poppedAt;
      return popped != null ? _t - popped > _popSeconds : l.balloon.progress(_t) > 1;
    });
    _refill();
    setState(() {});
  }

  void _refill() {
    final desired = _size.width >= 360 ? 6 : 5;
    final firstFill = !_filled;
    _filled = true;
    for (var guard = 0; guard < 10; guard++) {
      final active = _live.where((l) => !l.balloon.popped).length;
      final targetKnown = _holdTarget || _live.any((l) => l.balloon.letter == widget.target);
      if (active >= desired && targetKnown) break;
      // Letters of ALL balloons in flight count as on screen: visible ones,
      // ones still scheduled to appear (startTime in the future) and ones
      // mid-pop. That is what guarantees no letter ever shows up twice, and
      // it also makes the spawner treat a scheduled target as present.
      final onScreen = {for (final l in _live) l.balloon.letter, if (_holdTarget) widget.target};
      final letter = _spawner.nextLetter(onScreen: onScreen, target: widget.target, targetPending: false);
      _spawn(letter, firstFill);
    }
  }

  void _spawn(String letter, bool firstFill) {
    final r = widget.random;
    final isTarget = letter == widget.target;
    final start = firstFill
        ? _t - r.nextDouble() * (isTarget ? 1 : 4) // spread the first balloons over the field
        : isTarget
            ? _t // the target never waits
            : _t + r.nextDouble() * 0.6;
    // Of a few candidates take the one furthest from balloons still near the bottom.
    final near = [for (final l in _live) if (l.balloon.progress(_t) < 0.3) l.balloon.x];
    Balloon? best;
    var bestGap = -1.0;
    final id = _nextId++;
    for (var i = 0; i < 4; i++) {
      final c = Balloon.random(id: id, letter: letter, startTime: start, random: r);
      final gap = near.isEmpty ? 1.0 : near.map((x) => (x - c.x).abs()).reduce(min);
      if (gap > bestGap) {
        best = c;
        bestGap = gap;
      }
    }
    _live.add(_Live(best!));
  }

  void _tap(_Live l) {
    if (!widget.enabled || l.balloon.popped) return;
    setState(() {
      l.balloon.popped = true;
      l.poppedAt = _t;
      if (l.balloon.letter == widget.target) _holdTarget = true;
    });
    widget.onPop(l.balloon.letter);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _size = Size(c.maxWidth, c.maxHeight);
      final children = <Widget>[];
      for (final l in _live) {
        final b = l.balloon;
        final p = b.progress(_t);
        if (p < 0) continue; // scheduled, not yet released
        final d = _diameter(b);
        final bodyH = d * 1.15;
        final boxW = d + 2 * _tapPad;
        final boxH = bodyH + _stringHeight + 2 * _tapPad;
        // Keep body plus sway inside the field.
        final half = d / 2;
        final cx = (b.x * _size.width).clamp(half + _wobble, max(half + _wobble, _size.width - half - _wobble)) +
            _wobble * sin(2 * pi * (_t - b.startTime) / 3 + b.wobblePhase);
        final top = (_size.height - _tapPad) - p * (_size.height - _tapPad + boxH);
        final poppedAt = l.poppedAt;
        children.add(Positioned(
          key: ValueKey(b.id),
          left: cx - boxW / 2,
          top: top,
          width: boxW,
          height: boxH,
          child: poppedAt != null
              ? _PoppingBalloon(balloon: b, progress: ((_t - poppedAt) / _popSeconds).clamp(0.0, 1.0))
              : _BalloonView(
                  balloon: b,
                  glow: widget.hint == b.letter,
                  pulse: _t,
                  onTapDown: () => _tap(l),
                ),
        ));
      }
      return ClipRect(child: Stack(children: [const SizedBox.expand(), ...children]));
    });
  }
}

class _BalloonView extends StatelessWidget {
  const _BalloonView({required this.balloon, required this.glow, required this.pulse, required this.onTapDown});

  final Balloon balloon;
  final bool glow;
  final double pulse;
  final VoidCallback onTapDown;

  @override
  Widget build(BuildContext context) {
    final d = _diameter(balloon);
    return GestureDetector(
      key: Key('balloon-${balloon.letter}'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTapDown(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (glow)
            Positioned(
              key: Key('balloon-glow-${balloon.letter}'),
              left: _tapPad,
              top: _tapPad,
              width: d,
              height: d * 1.15,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(d / 2, d * 0.575)),
                  boxShadow: [BoxShadow(color: IceColors.glow, blurRadius: 24 + 8 * sin(pulse * 6), spreadRadius: 10)],
                ),
              ),
            ),
          Positioned.fill(child: _BalloonBody(balloon: balloon)),
        ],
      ),
    );
  }
}

/// The balloon drawing: body, string, shine and the letter.
class _BalloonBody extends StatelessWidget {
  const _BalloonBody({required this.balloon, this.withString = true});

  final Balloon balloon;
  final bool withString;

  @override
  Widget build(BuildContext context) {
    final d = _diameter(balloon);
    final style = TextStyle(fontSize: d * 0.5, fontWeight: FontWeight.w900, height: 1);
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _BalloonPainter(colorIndex: balloon.colorIndex, diameter: d, withString: withString))),
        Positioned(
          left: _tapPad,
          top: _tapPad,
          width: d,
          height: d * 1.15,
          child: Center(
            child: Stack(
              children: [
                Text(
                  balloon.letter,
                  style: style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 6
                      ..strokeJoin = StrokeJoin.round
                      ..color = const Color(0xFF14325C),
                  ),
                ),
                Text(balloon.letter, style: style.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BalloonPainter extends CustomPainter {
  const _BalloonPainter({required this.colorIndex, required this.diameter, required this.withString});

  final int colorIndex;
  final double diameter;
  final bool withString;

  @override
  void paint(Canvas canvas, Size size) {
    final color = kBalloonPalette[colorIndex % kBalloonPalette.length];
    final hsl = HSLColor.fromColor(color);
    final body = Rect.fromLTWH(_tapPad, _tapPad, diameter, diameter * 1.15);
    final cx = body.center.dx;
    if (withString) {
      final string = Path()
        ..moveTo(cx, body.bottom + 6)
        ..cubicTo(cx - 8, body.bottom + 16, cx + 8, body.bottom + 28, cx, body.bottom + _stringHeight);
      canvas.drawPath(
        string,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF14325C).withValues(alpha: 0.6),
      );
    }
    final knot = Path()
      ..moveTo(cx, body.bottom - 2)
      ..lineTo(cx - 6, body.bottom + 7)
      ..lineTo(cx + 6, body.bottom + 7)
      ..close();
    canvas.drawPath(knot, Paint()..color = hsl.withLightness((hsl.lightness - 0.12).clamp(0, 1)).toColor());
    canvas.drawOval(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [
            hsl.withLightness((hsl.lightness + 0.18).clamp(0, 1)).toColor(),
            color,
            hsl.withLightness((hsl.lightness - 0.12).clamp(0, 1)).toColor(),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(body),
    );
    canvas.drawOval(
      Rect.fromLTWH(body.left + diameter * 0.2, body.top + diameter * 0.16, diameter * 0.14, diameter * 0.22),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_BalloonPainter old) =>
      old.colorIndex != colorIndex || old.diameter != diameter || old.withString != withString;
}

/// The 250 ms pop: the body swells and fades while 8 confetti pieces fly out.
class _PoppingBalloon extends StatelessWidget {
  const _PoppingBalloon({required this.balloon, required this.progress});

  final Balloon balloon;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final d = _diameter(balloon);
    final center = Offset(_tapPad + d / 2, _tapPad + d * 0.575);
    return IgnorePointer(
      key: Key('balloon-pop-${balloon.letter}'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 1 - progress,
              child: Transform.scale(
                scale: 1 + 0.4 * progress,
                origin: center - Offset((d + 2 * _tapPad) / 2, (d * 1.15 + _stringHeight + 2 * _tapPad) / 2),
                child: _BalloonBody(balloon: balloon, withString: false),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _ConfettiPainter(progress: progress, center: center, colorIndex: balloon.colorIndex),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.center, required this.colorIndex});

  final double progress;
  final Offset center;
  final int colorIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOut.transform(progress);
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4 + 0.3;
      final at = center + Offset(cos(angle), sin(angle)) * (24 + 56 * eased);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(progress * 6 + i);
      canvas.drawRect(
        const Rect.fromLTWH(-5, -3, 10, 6),
        Paint()..color = kBalloonPalette[(colorIndex + i) % kBalloonPalette.length].withValues(alpha: 1 - progress),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
