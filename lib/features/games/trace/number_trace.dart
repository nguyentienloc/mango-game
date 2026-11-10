import '../../../core/content/models.dart';
import '../../../core/content/strokes.dart';
import '../../../core/progress/item_stat.dart';

/// Numbers per level: level k (1-based) is `numberLevels[k - 1]`, inclusive.
const numberLevels = [(0, 9), (10, 19), (20, 39), (40, 69), (70, 99)];

/// Progress key of number [n] in the number tracing game.
String numberTraceKey(int n) => 'trace_num:$n';

/// How much each digit of a two-digit number is shrunk.
const _kDigitScale = 0.75;
const _kTensCentre = TracePoint(0.28, 0.5);
const _kUnitsCentre = TracePoint(0.72, 0.5);

TracePoint _move(TracePoint p, TracePoint c) =>
    TracePoint(c.x + (p.x - 0.5) * _kDigitScale, c.y + (p.y - 0.5) * _kDigitScale);

/// [g] shrunk by [_kDigitScale] about the box centre and moved to [c]. Arcs
/// keep their angles; their centre moves like a point and their radii shrink.
StrokeSegment _place(StrokeSegment g, TracePoint c) {
  switch (g) {
    case LineSegment():
      return LineSegment([for (final p in g.points) _move(p, c)]);
    case ArcSegment():
      final centre = _move(TracePoint(g.cx, g.cy), c);
      return ArcSegment(centre.x, centre.y, g.rx * _kDigitScale, g.ry * _kDigitScale, g.startDeg, g.sweepDeg);
  }
}

Stroke _placeStroke(Stroke s, TracePoint c) => Stroke([for (final g in s.segments) _place(g, c)]);

/// Every number 0..99 as a traceable item (char = '$n', strokes composed from
/// [digits], which must hold "0".."9" in order). 0–9 reuse the digit strokes
/// as they are; 10–99 trace the tens digit on the left, then the units digit
/// on the right.
List<LetterItem> buildNumberItems(List<LetterItem> digits) => [
      for (var n = 0; n < 100; n++)
        n < 10
            ? LetterItem(char: '$n', strokes: digits[n].strokes)
            : LetterItem(char: '$n', strokes: [
                for (final s in digits[n ~/ 10].strokes) _placeStroke(s, _kTensCentre),
                for (final s in digits[n % 10].strokes) _placeStroke(s, _kUnitsCentre),
              ]),
    ];

bool _levelMastered((int, int) level, Map<String, ItemStat> stats) {
  final (from, to) = level;
  for (var n = from; n <= to; n++) {
    if ((stats[numberTraceKey(n)]?.mastery ?? 0) < 1) return false;
  }
  return true;
}

/// 1..5: highest unlocked level given mastery stats keyed by [numberTraceKey].
/// Level 1 is always open; level k+1 opens once every number of level k (and
/// so of every level before it) has been traced right first time at least once.
int unlockedNumberLevel(Map<String, ItemStat> stats) {
  var level = 1;
  while (level < numberLevels.length && _levelMastered(numberLevels[level - 1], stats)) {
    level++;
  }
  return level;
}

/// Items of all unlocked levels; an item whose char isn't a number is skipped.
List<LetterItem> unlockedNumbers(List<LetterItem> numbers, Map<String, ItemStat> stats) {
  final maxNumber = numberLevels[unlockedNumberLevel(stats) - 1].$2;
  return [
    for (final l in numbers)
      if ((int.tryParse(l.char) ?? maxNumber + 1) <= maxNumber) l,
  ];
}
