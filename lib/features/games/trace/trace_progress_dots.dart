import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Ring colour of the dot being traced now.
const kTraceDotCurrent = NoelColors.gold;

/// Fill of the dots still to come.
final kTraceDotUpcoming = Colors.white.withValues(alpha: 0.35);

/// One dot per item of the round: done ones are a gift 🎁, the current one white
/// with a gold ring, the ones to come faint white.
class TraceProgressDots extends StatelessWidget {
  const TraceProgressDots({
    super.key,
    required this.total,
    required this.current,
  });

  final int total;

  /// Index of the item being traced; every dot before it is done.
  final int current;

  static const double dotSize = 22;
  static const double gap = 6;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          // The gap is padding so that the dots (all with the same key) are not siblings.
          Padding(
            padding: EdgeInsets.only(left: i > 0 ? gap : 0),
            child: Container(
              key: const Key('trace-progress-dot'),
              width: dotSize,
              height: dotSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < current
                    ? null
                    : i == current
                    ? Colors.white
                    : kTraceDotUpcoming,
                border: i == current
                    ? Border.all(color: kTraceDotCurrent, width: 3)
                    : null,
              ),
              child: i < current
                  ? const FittedBox(child: Text('🎁', style: TextStyle(fontSize: 18, height: 1)))
                  : null,
            ),
          ),
      ],
    );
  }
}
