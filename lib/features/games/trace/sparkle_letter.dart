import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'pop_in_card.dart';

/// Shown when a letter (or a number of 10 and up) is traced: the character itself, big and sparkling.
class SparkleLetter extends StatelessWidget {
  const SparkleLetter({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return PopInCard(
      key: const Key('trace-done-letter'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 40)),
          Text(
            letter,
            style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: IceColors.deep),
          ),
          const Text('✨', style: TextStyle(fontSize: 40)),
        ],
      ),
    );
  }
}
