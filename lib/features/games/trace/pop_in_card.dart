import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// The white rounded card that pops in (scales 0.5 to 1) when a traced item is shown.
/// [key] goes on the animation, so tests and callers can find the whole card.
/// With [glow] the card shines with a soft yellow halo.
class PopInCard extends StatelessWidget {
  const PopInCard({super.key, required this.padding, required this.child, this.glow = false});

  final EdgeInsets padding;
  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(32));
    Widget card = Card(color: Colors.white, shape: shape, child: Padding(padding: padding, child: child));
    if (glow) {
      card = DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          shadows: [BoxShadow(color: IceColors.glow.withValues(alpha: 0.9), blurRadius: 28, spreadRadius: 6)],
        ),
        child: card,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: card,
    );
  }
}
