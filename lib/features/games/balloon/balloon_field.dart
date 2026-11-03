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

const _alphabetAZ = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

const _popSeconds = 0.25;
const _tapPad = 12.0; // extra tap area around a balloon, dp
const _wobble = 12.0; // horizontal sway, dp
const _stringHeight = 40.0;

/// A held target (popped, not yet replaced by the next one) is released after this many
/// field seconds even if the screen never moves on, so a lost round can never lock the field.
const _holdSeconds = 3.0;

/// One animation step never advances the field clock by more than this, so a stall (app
/// resumed, slow frame) does not teleport balloons or respawn a whole bunched wave.
const _maxStep = 0.05;

const _wiggleSeconds = 0.35;

/// Colourful letter balloons rising through the field. A touch pops the balloon whose
/// body (grown by 12 dp) it lands on, the nearest one when several overlap, and the field
/// asks [onPop] first: when that returns false (the screen is busy) the balloon only
/// wiggles. The field keeps 5 to 6 balloons (6 when at least 360 dp wide) alive, never two
/// with the same letter, and always has a balloon for [target] in the tree.
class BalloonField extends StatefulWidget {
  const BalloonField({
    super.key,
    required this.target,
    required this.onPop,
    required this.random,
    this.hint,
    this.alphabet = _alphabetAZ,
  });

  final String target;

  /// Called with the letter of the touched balloon. Returns true when the pop is accepted
  /// (the balloon pops now); false leaves the balloon in place (it wiggles).
  final bool Function(String letter) onPop;

  /// The letter whose balloon should glow, if any.
  final String? hint;
  final Random random;
  final List<String> alphabet;

  @override
  State<BalloonField> createState() => _BalloonFieldState();
}

class _Live {
  _Live(this.balloon) : art = _BalloonArt(balloon);

  final Balloon balloon;
  final _BalloonArt art;
  double? poppedAt;
  double? wiggleAt;
}

double _diameter(Balloon b) => 84 + 12 * (b.wobblePhase / (2 * pi));

/// Where a balloon is on the field right now.
class _Place {
  const _Place({required this.cx, required this.top, required this.boxW, required this.boxH, required this.d});

  /// Horizontal centre of the body and top of the padded box.
  final double cx;
  final double top;
  final double boxW;
  final double boxH;
  final double d;

  double get left => cx - boxW / 2;
  Offset get bodyCenter => Offset(cx, top + _tapPad + d * 0.575);

  /// Whether [p] is inside the body oval grown by [_tapPad] all around.
  bool hits(Offset p) {
    final c = bodyCenter;
    final a = d / 2 + _tapPad;
    final b = d * 0.575 + _tapPad;
    final dx = (p.dx - c.dx) / a;
    final dy = (p.dy - c.dy) / b;
    return dx * dx + dy * dy <= 1;
  }
}

class _BalloonFieldState extends State<BalloonField> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final BalloonSpawner _spawner;
  final _live = <_Live>[];
  Size _size = Size.zero;
  double _t = 0;
  Duration _lastElapsed = Duration.zero;
  int _nextId = 0;
  bool _filled = false;

  /// True after the target's balloon was popped (correctly) until the target
  /// changes, so the popped letter is not spawned again while the screen
  /// celebrates. It also holds one slot of the balloon count.
  bool _holdTarget = false;
  double _holdSince = 0;

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
    final dt = (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    _t += min(max(dt, 0), _maxStep);
    if (_size.isEmpty) return;
    // Safety net: the target never changed (e.g. the screen ignored the pop), so let go.
    if (_holdTarget && _t - _holdSince > _holdSeconds) _holdTarget = false;
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
      // A held target is a reserved slot: its replacement is about to be needed.
      final active = _live.where((l) => !l.balloon.popped).length + (_holdTarget ? 1 : 0);
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
        ? _t -
              r.nextDouble() *
                  (isTarget ? 1 : 4) // spread the first balloons over the field
        : isTarget
        ? _t // the target never waits
        : _t + r.nextDouble() * 0.6;
    // Of a few candidates take the one furthest from balloons still near the bottom.
    final near = [
      for (final l in _live)
        if (l.balloon.progress(_t) < 0.3) l.balloon.x,
    ];
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

  _Place _place(_Live l) {
    final b = l.balloon;
    final p = b.progress(_t);
    final d = _diameter(b);
    final bodyH = d * 1.15;
    final boxW = d + 2 * _tapPad;
    final boxH = bodyH + _stringHeight + 2 * _tapPad;
    // Keep body plus sway inside the field.
    final half = d / 2;
    var cx =
        (b.x * _size.width).clamp(half + _wobble, max(half + _wobble, _size.width - half - _wobble)) +
        _wobble * sin(2 * pi * (_t - b.startTime) / 3 + b.wobblePhase);
    final w = l.wiggleAt;
    if (w != null) {
      final k = (_t - w) / _wiggleSeconds;
      if (k >= 0 && k < 1) cx += 8 * sin(k * 6 * pi) * (1 - k);
    }
    final top = (_size.height - _tapPad) - p * (_size.height - _tapPad + boxH);
    return _Place(cx: cx, top: top, boxW: boxW, boxH: boxH, d: d);
  }

  /// A touch picks, among the balloons whose body (grown by [_tapPad]) contains it, the one
  /// whose centre is nearest; on a tie the topmost (latest) one.
  void _onPointerDown(PointerDownEvent event) {
    final at = event.localPosition;
    _Live? best;
    var bestDist = double.infinity;
    for (final l in _live) {
      if (l.balloon.popped || l.balloon.progress(_t) < 0) continue;
      final place = _place(l);
      if (!place.hits(at)) continue;
      final dist = (place.bodyCenter - at).distance;
      if (dist <= bestDist) {
        best = l;
        bestDist = dist;
      }
    }
    if (best == null) return;
    final l = best;
    final accepted = widget.onPop(l.balloon.letter);
    setState(() {
      if (!accepted) {
        l.wiggleAt = _t;
        return;
      }
      l.balloon.popped = true;
      l.poppedAt = _t;
      if (l.balloon.letter == widget.target) {
        _holdTarget = true;
        _holdSince = _t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        final children = <Widget>[];
        for (final l in _live) {
          final b = l.balloon;
          if (b.progress(_t) < 0) continue; // scheduled, not yet released
          final place = _place(l);
          final poppedAt = l.poppedAt;
          children.add(
            Positioned(
              key: ValueKey(b.id),
              left: place.left,
              top: place.top,
              width: place.boxW,
              height: place.boxH,
              child: poppedAt != null
                  ? _PoppingBalloon(live: l, progress: ((_t - poppedAt) / _popSeconds).clamp(0.0, 1.0))
                  : _BalloonView(live: l, glow: widget.hint == b.letter, pulse: _t),
            ),
          );
        }
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          child: ClipRect(child: Stack(children: [const SizedBox.expand(), ...children])),
        );
      },
    );
  }
}

class _BalloonView extends StatelessWidget {
  _BalloonView({required this.live, required this.glow, required this.pulse})
    : super(key: Key('balloon-${live.balloon.letter}'));

  final _Live live;
  final bool glow;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final d = live.art.d;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (glow)
          Positioned(
            key: Key('balloon-glow-${live.balloon.letter}'),
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
        // The drawing never changes, so it is rasterised once and only moved afterwards.
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: live.art.body)),
        ),
      ],
    );
  }
}

/// Everything about one balloon's drawing that never changes, built once: paints, the
/// string and knot paths and the laid-out letter.
class _BalloonArt {
  _BalloonArt(Balloon b) : d = _diameter(b), letter = b.letter, colorIndex = b.colorIndex {
    final color = kBalloonPalette[colorIndex % kBalloonPalette.length];
    final hsl = HSLColor.fromColor(color);
    final bodyRect = Rect.fromLTWH(_tapPad, _tapPad, d, d * 1.15);
    this.bodyRect = bodyRect;
    final cx = bodyRect.center.dx;
    stringPath = Path()
      ..moveTo(cx, bodyRect.bottom + 6)
      ..cubicTo(cx - 8, bodyRect.bottom + 16, cx + 8, bodyRect.bottom + 28, cx, bodyRect.bottom + _stringHeight);
    stringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF14325C).withValues(alpha: 0.6);
    knotPath = Path()
      ..moveTo(cx, bodyRect.bottom - 2)
      ..lineTo(cx - 6, bodyRect.bottom + 7)
      ..lineTo(cx + 6, bodyRect.bottom + 7)
      ..close();
    knotPaint = Paint()..color = hsl.withLightness((hsl.lightness - 0.12).clamp(0, 1)).toColor();
    bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: [
          hsl.withLightness((hsl.lightness + 0.18).clamp(0, 1)).toColor(),
          color,
          hsl.withLightness((hsl.lightness - 0.12).clamp(0, 1)).toColor(),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(bodyRect);
    shineRect = Rect.fromLTWH(bodyRect.left + d * 0.2, bodyRect.top + d * 0.16, d * 0.14, d * 0.22);
    shinePaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final style = TextStyle(fontSize: d * 0.5, fontWeight: FontWeight.w900, height: 1);
    outline = TextPainter(
      text: TextSpan(
        text: letter,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF14325C),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    fill = TextPainter(
      text: TextSpan(
        text: letter,
        style: style.copyWith(color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letterAt = bodyRect.center - Offset(fill.width / 2, fill.height / 2);
  }

  final double d;
  final String letter;
  final int colorIndex;
  late final Rect bodyRect;
  late final Path stringPath;
  late final Paint stringPaint;
  late final Path knotPath;
  late final Paint knotPaint;
  late final Paint bodyPaint;
  late final Rect shineRect;
  late final Paint shinePaint;
  late final TextPainter outline;
  late final TextPainter fill;
  late final Offset letterAt;

  late final CustomPainter body = _BalloonPainter(this, withString: true);
  late final CustomPainter bodyNoString = _BalloonPainter(this, withString: false);
}

/// The balloon drawing: body, string, shine and the letter. Draws from the cached [_BalloonArt].
class _BalloonPainter extends CustomPainter {
  const _BalloonPainter(this.art, {required this.withString});

  final _BalloonArt art;
  final bool withString;

  @override
  void paint(Canvas canvas, Size size) {
    if (withString) canvas.drawPath(art.stringPath, art.stringPaint);
    canvas.drawPath(art.knotPath, art.knotPaint);
    canvas.drawOval(art.bodyRect, art.bodyPaint);
    canvas.drawOval(art.shineRect, art.shinePaint);
    art.outline.paint(canvas, art.letterAt);
    art.fill.paint(canvas, art.letterAt);
  }

  @override
  bool shouldRepaint(_BalloonPainter old) => old.art != art || old.withString != withString;
}

/// The 250 ms pop: the body swells and fades while 8 confetti pieces fly out.
class _PoppingBalloon extends StatelessWidget {
  const _PoppingBalloon({required this.live, required this.progress});

  final _Live live;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final art = live.art;
    final d = art.d;
    final center = Offset(_tapPad + d / 2, _tapPad + d * 0.575);
    return IgnorePointer(
      key: Key('balloon-pop-${art.letter}'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 1 - progress,
              child: Transform.scale(
                scale: 1 + 0.4 * progress,
                origin: center - Offset((d + 2 * _tapPad) / 2, (d * 1.15 + _stringHeight + 2 * _tapPad) / 2),
                child: RepaintBoundary(child: CustomPaint(painter: art.bodyNoString)),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _ConfettiPainter(progress: progress, center: center, colorIndex: art.colorIndex),
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
