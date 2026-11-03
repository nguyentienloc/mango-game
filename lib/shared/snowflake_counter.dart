import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/theme.dart';

/// The child's snowflake total. Tapping it makes Elsa say the number.
class SnowflakeCounter extends ConsumerWidget {
  const SnowflakeCounter({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(voiceProvider).say('snowflake_count', vars: {'count': '$count'}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(24)),
        child: Text(
          '❄️ $count',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: IceColors.deep),
        ),
      ),
    );
  }
}
