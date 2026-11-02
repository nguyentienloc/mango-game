import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/reward_controller.dart';
import '../../core/rewards/reward_state.dart';
import '../../shared/big_button.dart';
import '../../shared/castle_view.dart';
import '../../shared/character_view.dart';
import '../../shared/ice_background.dart';
import '../../shared/snowflake_counter.dart';

class CastleScreen extends ConsumerWidget {
  const CastleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardStateProvider).value ?? const RewardState();
    final levels = ref.watch(contentProvider).castle;
    final current = levels.firstWhere((l) => l.level == rewards.castleLevel);
    final next = levels.where((l) => l.level == rewards.castleLevel + 1).firstOrNull;
    final progress = next == null
        ? 1.0
        : (rewards.snowflakesTotal - current.snowflakes) / (next.snowflakes - current.snowflakes);
    final friends = [
      for (final l in levels)
        if (l.level <= rewards.castleLevel && l.friend != null) l.friend!,
    ];
    return Scaffold(
      body: IceBackground(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: BigButton(
                  emoji: '🏠',
                  size: 64,
                  onTap: () {
                    ref.read(voiceProvider).say('go_home');
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            Expanded(child: Center(child: CastleView(level: rewards.castleLevel, width: 320))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 16,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            SnowflakeCounter(count: rewards.snowflakesTotal),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                const CharacterView(id: 'elsa', size: 72),
                for (final f in friends) CharacterView(id: f, size: 72),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
