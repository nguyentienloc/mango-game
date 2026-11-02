import 'dart:math';

import '../../../core/content/models.dart';
import '../../../core/content/strokes.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';

const kTraceTolerance = 0.12;
const kMinCoverage = 0.8;
const kMinPrecision = 0.7;

class StrokeScore {
  const StrokeScore(this.coverage, this.precision);

  final double coverage;
  final double precision;

  bool get passed => coverage >= kMinCoverage && precision >= kMinPrecision;
}

double _distToSegment(TracePoint p, TracePoint a, TracePoint b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return p.distanceTo(a);
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  return p.distanceTo(TracePoint(a.x + t * dx, a.y + t * dy));
}

StrokeScore scoreStroke(List<TracePoint> target, List<TracePoint> drawn, {double tolerance = kTraceTolerance}) {
  if (drawn.length < 2 || target.isEmpty) return const StrokeScore(0, 0);
  double distToDrawn(TracePoint p) {
    var best = double.infinity;
    for (var i = 1; i < drawn.length; i++) {
      best = min(best, _distToSegment(p, drawn[i - 1], drawn[i]));
    }
    return best;
  }

  double distToTarget(TracePoint p) => target.map(p.distanceTo).reduce(min);
  final covered = target.where((p) => distToDrawn(p) <= tolerance).length;
  final precise = drawn.where((p) => distToTarget(p) <= tolerance).length;
  return StrokeScore(covered / target.length, precise / drawn.length);
}

String traceKey(LetterItem l) => 'trace_en_upper:${l.char}';

class TraceLetterSession {
  TraceLetterSession(this.letter)
      : targets = [for (final s in letter.strokes) s.sample()],
        _failures = List.filled(letter.strokes.length, 0);

  final LetterItem letter;
  final List<List<TracePoint>> targets;
  final List<int> _failures;
  int _stroke = 0;

  int get strokeIndex => _stroke;
  bool get isDone => _stroke >= targets.length;
  int failuresOn(int stroke) => _failures[stroke];

  /// Scores [drawn] against the current stroke; true when it passes.
  bool submit(List<TracePoint> drawn) {
    if (isDone) throw StateError('letter already traced');
    if (scoreStroke(targets[_stroke], drawn).passed) {
      _stroke++;
      return true;
    }
    _failures[_stroke]++;
    return false;
  }

  AnswerOutcome get outcome => _failures.any((f) => f >= 3) ? AnswerOutcome.retry : AnswerOutcome.firstTry;
}

List<LetterItem> buildTraceRound({
  required List<LetterItem> letters,
  required Map<String, ItemStat> stats,
  required QuestionPicker picker,
  int count = 3,
  int maxNew = 3,
}) {
  final byKey = {for (final l in letters) traceKey(l): l};
  // Pick one letter at a time so a letter never repeats within the round
  // (QuestionPicker only avoids back-to-back repeats), and cap unseen letters.
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
