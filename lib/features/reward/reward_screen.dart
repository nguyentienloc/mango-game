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

  /// Phrases still to say, in order; the gift line can jump the queue.
  final _lines = <String>[];
  bool _speaking = false;
  bool _giftOpened = false;

  @override
  void initState() {
    super.initState();
    final o = widget.outcome;
    _lines.addAll([
      'round_done',
      if (o.questCompleted) 'quest_done',
      if (o.leveledUp) 'castle_level_up',
      if (o.friendUnlocked != null) 'friend_unlocked',
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  /// Says the queued lines one after another; the line being spoken is never cut.
  Future<void> _speak() async {
    if (_speaking) return;
    _speaking = true;
    final voice = ref.read(voiceProvider);
    while (_lines.isNotEmpty && !_leaving) {
      await voice.say(_lines.removeAt(0));
    }
    _speaking = false;
  }

  void _openGift() {
    if (_giftOpened || _leaving) return;
    setState(() => _giftOpened = true);
    // "Tap the gift" is pointless once it is open; the gift line comes next.
    _lines
      ..remove('quest_done')
      ..insert(0, 'gift_open');
    _speak();
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
                  // The gift's snowflakes join the count when it is opened.
                  tween: IntTween(begin: 0, end: _giftOpened ? o.earned : o.earned - o.questBonus),
                  duration: const Duration(milliseconds: 1200),
                  builder: (context, value, _) => Text(
                    '+$value ❄️',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: IceColors.deep),
                  ),
                ),
                if (o.questCompleted) _GiftBox(opened: _giftOpened, bonus: o.questBonus, onTap: _openGift),
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

/// The daily-quest gift: wiggles until tapped, then pops open on its snowflakes.
class _GiftBox extends StatefulWidget {
  const _GiftBox({required this.opened, required this.bonus, required this.onTap});

  final bool opened;
  final int bonus;
  final VoidCallback onTap;

  @override
  State<_GiftBox> createState() => _GiftBoxState();
}

class _GiftBoxState extends State<_GiftBox> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    if (!widget.opened) _wiggle.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_GiftBox old) {
    super.didUpdateWidget(old);
    if (widget.opened) _wiggle.stop();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('reward-gift'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        height: 96,
        child: Center(
          child: widget.opened
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Text(
                    '+${widget.bonus} ❄️',
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: IceColors.deep),
                  ),
                )
              : AnimatedBuilder(
                  animation: _wiggle,
                  builder: (context, child) => Transform.rotate(angle: (_wiggle.value - 0.5) * 0.3, child: child),
                  child: const Text('🎁', style: TextStyle(fontSize: 72)),
                ),
        ),
      ),
    );
  }
}
