import 'package:flutter/material.dart';

import '../core/rewards/reward_rules.dart';

/// Today's quest: one gift per round, faint until that round is played.
class QuestDots extends StatelessWidget {
  const QuestDots({super.key, required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kQuestRounds; i++)
          Padding(
            padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
            child: Opacity(
              key: Key('quest-gift-$i'),
              opacity: i < done ? 1 : 0.35,
              child: const Text('🎁', style: TextStyle(fontSize: 26)),
            ),
          ),
      ],
    );
  }
}
