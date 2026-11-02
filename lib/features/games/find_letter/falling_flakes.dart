import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Snowflakes carrying letters drift down in lanes and loop back to the top.
/// They always stay fully on screen so a child (or a test) can tap them.
class FallingFlakes extends StatefulWidget {
  const FallingFlakes({super.key, required this.options, required this.onTap, this.hint, this.shaking, this.burst});

  final List<String> options;
  final ValueChanged<String> onTap;

  /// Option that glows (after two wrong taps).
  final String? hint;

  /// Option that wiggles (just tapped wrong).
  final String? shaking;

  /// Option that bursts (just tapped right).
  final String? burst;

  @override
  State<FallingFlakes> createState() => _FallingFlakesState();
}

class _FallingFlakesState extends State<FallingFlakes> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = widget.options.length;
        final lane = constraints.maxWidth / n;
        final size = min(104.0, lane - 8);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            children: [
              for (var i = 0; i < n; i++) _flake(i, lane, size, constraints.maxHeight),
            ],
          ),
        );
      },
    );
  }

  Widget _flake(int i, double lane, double size, double height) {
    final option = widget.options[i];
    final phase = (_controller.value + i * 0.37) % 1.0;
    final fade = phase < 0.08 ? phase / 0.08 : (phase > 0.92 ? (1 - phase) / 0.08 : 1.0);
    final shake = widget.shaking == option ? sin(_controller.value * 9 * 2 * pi * 6) * 8 : 0.0;
    final glow = widget.hint == option;
    final burst = widget.burst == option;
    return Positioned(
      left: (i + 0.5) * lane - size / 2 + shake,
      top: phase * max(0.0, height - size),
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0).toDouble(),
        child: AnimatedOpacity(
          opacity: burst ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: AnimatedScale(
            scale: burst ? 1.6 : (glow ? 1.15 : 1.0),
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => widget.onTap(option),
              child: _FlakeFace(letter: option, size: size, glow: glow),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlakeFace extends StatelessWidget {
  const _FlakeFace({required this.letter, required this.size, required this.glow});

  final String letter;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Colors.white, IceColors.frost]),
        boxShadow: glow
            ? const [BoxShadow(color: IceColors.glow, blurRadius: 24, spreadRadius: 8)]
            : [BoxShadow(color: IceColors.deep.withValues(alpha: 0.2), blurRadius: 6)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('❄', style: TextStyle(fontSize: size * 0.9, color: Colors.white.withValues(alpha: 0.6))),
          Text(
            letter,
            key: const Key('flake-letter'),
            style: TextStyle(fontSize: size * 0.48, fontWeight: FontWeight.w900, color: IceColors.deep),
          ),
        ],
      ),
    );
  }
}
