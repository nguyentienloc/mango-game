import 'package:flutter/material.dart';

import '../app/theme.dart';

class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.emoji, required this.onTap, this.size = 88, this.enabled = true});

  final String emoji;
  final VoidCallback onTap;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Colors.white, IceColors.frost]),
            boxShadow: [
              BoxShadow(color: IceColors.deep.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Text(emoji, style: TextStyle(fontSize: size * 0.45)),
        ),
      ),
    );
  }
}
