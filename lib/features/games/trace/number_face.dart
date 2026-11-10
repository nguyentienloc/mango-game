import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'pop_in_card.dart';
import 'sparkle_letter.dart';

/// The thing to count for each number 1–9 (index n − 1).
const numberFaceEmoji = ['🍎', '⭐', '🐟', '🌸', '🎈', '🍓', '🦋', '🍪', '🐥'];

/// Items per row in the counting grid (like a ten frame: 7 is a row of 5 and 2).
const _kPerRow = 5;

/// Shown once number [n] is traced: the big number, and to count, n of its emoji
/// (1–9), an empty basket (0), or just the number sparkling (10–99).
class NumberFace extends StatelessWidget {
  const NumberFace(this.n, {super.key});

  final int n;

  @override
  Widget build(BuildContext context) {
    // Scaled down rather than clipped when the pad is small (a phone of 360 dp wide).
    return FittedBox(fit: BoxFit.scaleDown, child: _face());
  }

  Widget _face() {
    if (n >= 10) return KeyedSubtree(key: Key('number-face-$n'), child: SparkleLetter(letter: '$n'));
    final Widget below;
    if (n == 0) {
      below = const Text('🧺', style: TextStyle(fontSize: 64));
    } else {
      final emoji = numberFaceEmoji[n - 1];
      below = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row * _kPerRow < n; row++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = row * _kPerRow; i < n && i < (row + 1) * _kPerRow; i++)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(emoji, key: const Key('number-face-item'), style: const TextStyle(fontSize: 40)),
                  ),
              ],
            ),
        ],
      );
    }
    return PopInCard(
      key: Key('number-face-$n'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$n',
            style: const TextStyle(fontSize: 96, height: 1.1, fontWeight: FontWeight.bold, color: IceColors.deep),
          ),
          below,
        ],
      ),
    );
  }
}
