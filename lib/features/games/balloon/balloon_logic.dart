import 'dart:math';

import '../../../core/content/models.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../pick_session.dart';

/// Number of balloon colours in the painter's palette.
const kBalloonColors = 8;

String balloonKey(LetterItem l) => 'balloon_en_upper:${l.char}';

/// Picks [count] different letters for one round, at most [maxNew] unseen ones
/// (same approach as `buildTraceRound`, since [QuestionPicker] only avoids
/// back-to-back repeats).
List<LetterItem> buildBalloonRound({
  required List<LetterItem> letters,
  required Map<String, ItemStat> stats,
  required QuestionPicker picker,
  int count = 5,
  int maxNew = 3,
}) {
  final byKey = {for (final l in letters) balloonKey(l): l};
  final remaining = byKey.keys.toList();
  final round = <LetterItem>[];
  var newCount = 0;
  while (round.length < count && remaining.isNotEmpty) {
    final seen = remaining.where(stats.containsKey).toList();
    final pool = newCount >= maxNew && seen.isNotEmpty ? seen : remaining;
    final k = picker.pick(candidates: pool, stats: stats, count: 1).single;
    remaining.remove(k);
    if (!stats.containsKey(k)) newCount++;
    round.add(byKey[k]!);
  }
  return round;
}

class BalloonQuestion implements PickQuestion {
  const BalloonQuestion(this.item);

  final LetterItem item;

  @override
  String get key => balloonKey(item);

  @override
  String get answer => item.char;
}

/// Chooses the letter of each new balloon: never one already on screen, and
/// the target letter is guaranteed to show up.
class BalloonSpawner {
  // ignore: prefer_initializing_formals
  BalloonSpawner({required this.alphabet, required Random random}) : _random = random;

  final List<String> alphabet;
  final Random _random;

  /// [onScreen] holds the letters of all balloons in flight. [targetPending]
  /// is true when a balloon with the target letter is already waiting to
  /// appear. Throws [StateError] if every letter is already on screen.
  String nextLetter({required Set<String> onScreen, required String target, required bool targetPending}) {
    final targetAbsent = !onScreen.contains(target);
    if (targetAbsent && !targetPending) return target;
    final free = alphabet.where((c) => !onScreen.contains(c)).toList();
    if (free.isEmpty) throw StateError('every letter is already on screen');
    if (targetAbsent && free.contains(target) && _random.nextInt(4) == 0) return target;
    return free[_random.nextInt(free.length)];
  }
}

/// Position of a balloon as a fraction of the field height: 1 at the bottom,
/// 0 at the top, for a [progress] of 0 to 1.
double balloonY(double progress) => 1 - progress;

/// Pure data for one balloon; the field widget animates it.
class Balloon {
  Balloon({
    required this.id,
    required this.letter,
    required this.colorIndex,
    required this.x,
    required this.startTime,
    required this.duration,
    required this.wobblePhase,
  });

  /// A balloon of [letter] released at [startTime] (seconds) with a random
  /// colour, horizontal centre, speed (7 to 9 s to cross) and wobble phase.
  factory Balloon.random({required int id, required String letter, required double startTime, required Random random}) =>
      Balloon(
        id: id,
        letter: letter,
        colorIndex: random.nextInt(kBalloonColors),
        x: 0.1 + random.nextDouble() * 0.8,
        startTime: startTime,
        duration: 11 + random.nextDouble() * 3, // 11–14 s to rise (slowed for a 5-year-old)
        wobblePhase: random.nextDouble() * 2 * pi,
      );

  final int id;
  final String letter;
  final int colorIndex;

  /// Horizontal centre, 0 to 1 of the field width.
  final double x;

  /// Seconds on the field clock when the balloon starts rising.
  final double startTime;

  /// Seconds to rise the full height.
  final double duration;
  final double wobblePhase;
  bool popped = false;

  /// 0 when released, 1 once it has fully crossed the field (can exceed 1,
  /// or be negative before [startTime]).
  double progress(double t) => (t - startTime) / duration;
}
