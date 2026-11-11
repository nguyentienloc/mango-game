import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'compare_logic.dart';

const _gold = Color(0xFFFFD54F);
const _goldBg = Color(0xFFFFFDE7);
const _pink = Color(0xFFF06292);
const _green = Color(0xFF66BB6A);
const _greenShadow = Color(0xFF2E7D32);
const _blue = Color(0xFF42A5F5);
const _blueShadow = Color(0xFF1565C0);

const _cell = 58.0;

/// How a card looks once the question is answered.
enum CardMark { none, winner, loser }

final _softShadow = [BoxShadow(color: IceColors.deep.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 5))];
const _glow = [BoxShadow(color: IceColors.glow, blurRadius: 26, spreadRadius: 6)];

/// Shakes sideways once when [shaking] turns true (a wrong tap).
class Shake extends StatelessWidget {
  const Shake({super.key, required this.shaking, required this.child});

  final bool shaking;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(shaking),
        tween: Tween(begin: 0, end: shaking ? 1 : 0),
        duration: const Duration(milliseconds: 400),
        builder: (context, t, child) => Transform.translate(offset: Offset(sin(t * pi * 6) * 8, 0), child: child),
        child: child,
      );
}

BoxDecoration _cardDecoration({required CardMark mark, required bool hint}) => BoxDecoration(
      color: switch (mark) {
        CardMark.winner => _goldBg,
        CardMark.loser => Colors.white.withValues(alpha: 0.55),
        CardMark.none => Colors.white,
      },
      borderRadius: BorderRadius.circular(28),
      // Always 6 dp wide (transparent when inactive) so lighting it up never shrinks the content.
      border: Border.all(color: mark == CardMark.winner || hint ? _gold : Colors.transparent, width: 6),
      boxShadow: mark == CardMark.winner || hint ? _glow : (mark == CardMark.loser ? null : _softShadow),
    );

/// Level 1: [count] pictures of [emoji] in two columns; the number shows under them once [revealed].
class PictureCard extends StatelessWidget {
  const PictureCard({
    super.key,
    required this.side,
    required this.count,
    required this.emoji,
    required this.onTap,
    this.maxCount,
    this.mark = CardMark.none,
    this.revealed = false,
    this.hint = false,
    this.shaking = false,
  });

  /// `left` or `right`, used in the keys.
  final String side;
  final int count;
  final String emoji;
  final VoidCallback onTap;

  /// The larger of the two counts on screen (default [count]); both cards lay out for it,
  /// so their pictures are drawn at the same size.
  final int? maxCount;
  final CardMark mark;
  final bool revealed;
  final bool hint;
  final bool shaking;

  @override
  Widget build(BuildContext context) {
    final slots = max(count, maxCount ?? count);
    // Fixed-size cells, so the grid for [slots] has the same size on both cards and the
    // FittedBox below scales both by the same factor.
    final rows = [
      for (var i = 0; i < count; i += 2)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var j = i; j < min(i + 2, count); j++)
              SizedBox.square(dimension: _cell, child: Center(child: Text(emoji, style: const TextStyle(fontSize: 50)))),
          ],
        ),
    ];
    return GestureDetector(
      key: Key('compare-side-$side'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Shake(
        shaking: shaking,
        child: Container(
          key: mark == CardMark.winner ? Key('compare-win-$side') : (hint ? const Key('compare-hint') : null),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
          decoration: _cardDecoration(mark: mark, hint: hint),
          child: Column(
            children: [
              Expanded(
                child: Opacity(
                  opacity: mark == CardMark.loser ? 0.45 : 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 2 * _cell,
                      height: (slots + 1) ~/ 2 * _cell,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: rows),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 64,
                child: revealed
                    ? FittedBox(
                        key: Key('compare-count-$side'),
                        child: Text('$count', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: IceColors.deep, height: 1.1)),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Levels 2-4: a number, with pink counting dots under it on level 2.
class NumberCard extends StatelessWidget {
  const NumberCard({super.key, required this.side, required this.value, this.dots = false, this.mark = CardMark.none});

  final String side;
  final int value;
  final bool dots;
  final CardMark mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: mark == CardMark.winner ? Key('compare-win-$side') : null,
      width: dots ? 130 : 136,
      height: dots ? 190 : 150,
      padding: const EdgeInsets.all(8),
      decoration: _cardDecoration(mark: mark, hint: false),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                style: TextStyle(fontSize: dots ? 96 : 80, fontWeight: FontWeight.w900, color: IceColors.deep, height: 1.05),
              ),
            ),
          ),
          if (dots && value > 0) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 5 * 14 + 4 * 5,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (var i = 0; i < value; i++)
                    SizedBox.square(
                      dimension: 14,
                      child: DecoratedBox(
                        key: const Key('compare-dot'),
                        decoration: const BoxDecoration(color: _pink, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (dots && value == 0) const SizedBox(height: 4 + 14),
        ],
      ),
    );
  }
}

/// The dashed "?" box between the numbers; filled with the picked [sign] once answered.
class SignBox extends StatelessWidget {
  const SignBox({super.key, this.sign});

  final CompareSign? sign;

  @override
  Widget build(BuildContext context) {
    final s = sign;
    return AnimatedScale(
      scale: s == null ? 1 : 1.08,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: SizedBox.square(
        key: const Key('compare-box'),
        dimension: 68,
        child: s == null
            ? CustomPaint(
                painter: const _DashedBox(),
                child: const Center(
                  child: Text('?', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF7FA6D6))),
                ),
              )
            : Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s == CompareSign.eq ? _blue : _green,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _glow,
                ),
                child: Text(s.symbol, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
              ),
      ),
    );
  }
}

class _DashedBox extends CustomPainter {
  const _DashedBox();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)).deflate(2);
    canvas.drawRRect(rrect, Paint()..color = Colors.white.withValues(alpha: 0.6));
    final paint = Paint()
      ..color = const Color(0xFF7FA6D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, min(d + 8, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox oldDelegate) => false;
}

/// The crocodile's open mouth faces the bigger number (the 🐊 glyph faces left); 🤝 for equal.
class CompareCroc extends StatelessWidget {
  const CompareCroc({super.key, required this.sign, this.size = 64});

  final CompareSign sign;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Text(sign == CompareSign.eq ? '🤝' : '🐊', style: TextStyle(fontSize: size, height: 1));
    return sign == CompareSign.lt ? Transform.flip(flipX: true, child: text) : text;
  }
}

/// One of the three answer buttons: crocodile (or 🤝), the sign, and its word.
class SignButton extends StatelessWidget {
  const SignButton({super.key, required this.sign, required this.onTap, this.hint = false, this.shaking = false});

  final CompareSign sign;
  final VoidCallback onTap;
  final bool hint;
  final bool shaking;

  @override
  Widget build(BuildContext context) {
    final eq = sign == CompareSign.eq;
    return GestureDetector(
      key: Key('compare-sign-${sign.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Shake(
        shaking: shaking,
        child: Container(
          key: hint ? const Key('compare-hint') : null,
          height: 128,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: eq ? _blue : _green,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: hint ? _gold : Colors.transparent, width: 5),
            boxShadow: [
              BoxShadow(color: eq ? _blueShadow : _greenShadow, offset: const Offset(0, 6)),
              if (hint) ..._glow,
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CompareCroc(sign: sign, size: 30),
                Text(sign.symbol, style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                Text(sign.word, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
