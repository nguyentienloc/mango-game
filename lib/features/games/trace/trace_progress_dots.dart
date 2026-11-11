import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Ring colour of the dot being traced now.
const kTraceDotCurrent = Color(0xFFFFB74D);

/// One dot per item of the round: done ones deep blue, the current one white
/// with an orange ring, the ones to come faint white.
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < current
                    ? IceColors.deep
                    : i == current
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                border: i == current
                    ? Border.all(color: kTraceDotCurrent, width: 3)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
