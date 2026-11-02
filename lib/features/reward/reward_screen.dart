import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/rewards/reward_state.dart';
import '../../shared/big_button.dart';
import '../../shared/castle_view.dart';
import '../../shared/character_view.dart';
import '../../shared/ice_background.dart';

class RewardScreen extends ConsumerStatefulWidget {
  const RewardScreen({super.key, required this.outcome});

  final RewardOutcome outcome;

  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
  }

  Future<void> _celebrate() async {
    final voice = ref.read(voiceProvider);
    final o = widget.outcome;
    await voice.say('round_done');
    if (o.questCompleted) await voice.say('quest_done');
    if (o.leveledUp) await voice.say('castle_level_up');
    if (o.friendUnlocked != null) await voice.say('friend_unlocked');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outcome;
    final friend = o.friendUnlocked;
    return Scaffold(
      body: IceBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: o.leveledUp ? 0.7 : 1, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: CastleView(level: o.newLevel, width: 280),
              ),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: o.earned),
                duration: const Duration(milliseconds: 1200),
                builder: (context, value, _) => Text(
                  '+$value ❄️',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: IceColors.deep),
                ),
              ),
              if (o.questCompleted) const Text('🎁', style: TextStyle(fontSize: 72)),
              if (friend != null) CharacterView(id: friend, size: 96),
              BigButton(
                emoji: '✅',
                size: 96,
                onTap: () {
                  ref.read(voiceProvider).say('go_home');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
