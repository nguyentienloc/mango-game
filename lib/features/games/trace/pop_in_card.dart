import 'package:flutter/material.dart';

/// The white rounded card that pops in (scales 0.5 to 1) when a traced item is shown.
/// [key] goes on the animation, so tests and callers can find the whole card.
class PopInCard extends StatelessWidget {
  const PopInCard({super.key, required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
