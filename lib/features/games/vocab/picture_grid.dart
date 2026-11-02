import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/content/models.dart';

/// Four picture cards in a 2×2 grid. Cards are as big as fit (max 200 dp).
class PictureGrid extends StatelessWidget {
  const PictureGrid({super.key, required this.options, required this.onTap, this.hint, this.shaking, this.burst});

  final List<VocabItem> options;
  final ValueChanged<String> onTap;
  final String? hint;
  final String? shaking;
  final String? burst;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 16.0;
      final side = min(200.0, min((c.maxWidth - gap * 3) / 2, (c.maxHeight - gap * 3) / 2));
      return Center(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final o in options) _Card(item: o, side: side, grid: this)],
        ),
      );
    });
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.side, required this.grid});

  final VocabItem item;
  final double side;
  final PictureGrid grid;

  @override
  Widget build(BuildContext context) {
    final glow = grid.hint == item.id;
    final burst = grid.burst == item.id;
    final shaking = grid.shaking == item.id;
    final image = item.image;
    Widget picture = image == null
        ? Text(item.emoji, style: TextStyle(fontSize: side * 0.55))
        : Image.asset('content/$image',
            width: side * 0.8,
            height: side * 0.8,
            errorBuilder: (_, _, _) => Text(item.emoji, style: TextStyle(fontSize: side * 0.55)));
    return GestureDetector(
      key: Key('card-${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => grid.onTap(item.id),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(shaking),
        tween: Tween(begin: 0, end: shaking ? 1 : 0),
        duration: const Duration(milliseconds: 400),
        builder: (context, t, child) => Transform.translate(offset: Offset(sin(t * pi * 6) * 8, 0), child: child),
        child: AnimatedScale(
          scale: burst ? 1.12 : 1,
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: glow ? Key('glow-${item.id}') : null,
            width: side,
            height: side,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: glow
                  ? const [BoxShadow(color: IceColors.glow, blurRadius: 28, spreadRadius: 10)]
                  : [BoxShadow(color: IceColors.deep.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))],
              border: burst ? Border.all(color: IceColors.frost, width: 6) : null,
            ),
            child: picture,
          ),
        ),
      ),
    );
  }
}
