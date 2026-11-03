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
  const RewardScreen({super.key, required this.outcome, this.popToRoot = false});

  final RewardOutcome outcome;

  /// After a game opened from a chooser: ✅ and back go all the way home, not back to the chooser.
  final bool popToRoot;

  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen> {
  /// Set as soon as the route starts popping (✅ or back) and on dispose; the
  /// pop transition keeps the screen mounted for a moment, and stopping the
  /// current phrase would otherwise let the chain carry on over "Về lâu đài nào!".
  bool _leaving = false;

  @override
  void dispose() {
    _leaving = true;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
  }

  Future<void> _celebrate() async {
    final voice = ref.read(voiceProvider);
    final o = widget.outcome;
    await voice.say('round_done');
    if (_leaving) return;
    if (o.questCompleted) await voice.say('quest_done');
    if (_leaving) return;
    if (o.leveledUp) await voice.say('castle_level_up');
    if (_leaving) return;
    if (o.friendUnlocked != null) await voice.say('friend_unlocked');
  }

  void _goHome() {
    _leaving = true;
    ref.read(voiceProvider).say('go_home');
    final nav = Navigator.of(context);
    widget.popToRoot ? nav.popUntil((r) => r.isFirst) : nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outcome;
    final friend = o.friendUnlocked;
    return PopScope(
      canPop: !widget.popToRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _leaving = true;
        } else {
          _goHome();
        }
      },
      child: Scaffold(
        body: IceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Shrinks on short phones so the ✅ button is never pushed off screen.
                Flexible(
                  child: FittedBox(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: o.leveledUp ? 0.7 : 1, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: CastleView(level: o.newLevel, width: 280),
                    ),
                  ),
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
                  onTap: _goHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
