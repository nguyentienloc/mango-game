import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Shown when a letter (or a number of 10 and up) is traced: the character itself, big and sparkling.
class SparkleLetter extends StatelessWidget {
  const SparkleLetter({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const Key('trace-done-letter'),
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 40)),
              Text(
                letter,
                style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: IceColors.deep),
              ),
              const Text('✨', style: TextStyle(fontSize: 40)),
            ],
          ),
        ),
      ),
    );
  }
}
