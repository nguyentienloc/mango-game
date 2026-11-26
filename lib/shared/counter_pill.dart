import 'package:flutter/material.dart';

import '../app/theme.dart';

/// "3/10" in the top bar of a game: red text on a white pill, readable on the night sky.
class CounterPill extends StatelessWidget {
  const CounterPill(this.text, {super.key, this.fontSize = 22});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: NoelColors.shadow.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: NoelColors.deepRed)),
    );
  }
}
