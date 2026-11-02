import 'package:flutter/material.dart';

import '../app/theme.dart';

class SnowflakeCounter extends StatelessWidget {
  const SnowflakeCounter({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(24)),
      child: Text(
        '❄️ $count',
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: IceColors.deep),
      ),
    );
  }
}
