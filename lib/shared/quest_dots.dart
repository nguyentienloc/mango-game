import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/rewards/reward_rules.dart';

class QuestDots extends StatelessWidget {
  const QuestDots({super.key, required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('⭐', style: TextStyle(fontSize: 24)),
        for (var i = 0; i < kQuestRounds; i++)
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? IceColors.glow : Colors.white,
              border: Border.all(color: IceColors.deep, width: 2),
            ),
          ),
      ],
    );
  }
}
