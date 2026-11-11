import 'dart:math';

import '../../../core/progress/item_stat.dart';
import '../../../core/progress/item_stats_store.dart';
import '../pick_session.dart';

/// The one stat the compare game keeps: its level, as the mastery 0..3 of this key (level 1..4).
/// Reset progress wipes item stats, so it goes back to level 1.
const compareLevelKey = 'compare:level';
const compareMaxLevel = 4;
const compareRoundLength = 10;

/// First tries in a round that move the child up a level.
const compareLevelUpFirstTries = 8;

/// Level 1 picture cards: one emoji per question, rotating through the round.
const compareEmojis = ['🍎', '⭐', '🐟', '🌸', '🎈', '🍓', '🦋', '🍪', '🐥'];

/// Equal pairs per round on levels 2-4 (about one in five) and swapped-digit pairs on level 4.
const _equalPerRound = 2;
const _swappedPerRound = 2;

enum CompareSign {
  gt('>', 'lớn hơn'),
  lt('<', 'bé hơn'),
  eq('=', 'bằng');

  const CompareSign(this.symbol, this.word);

  final String symbol;
  final String word;
}

/// Biggest number on a level: 0..10, 0..20, 0..99. Level 1 counts pictures 1..10.
int compareMaxNumber(int level) => switch (level) {
      1 || 2 => 10,
      3 => 20,
      _ => 99,
    };

/// Level 2 shows counting dots under each number; 3 and 4 only the numbers.
bool compareShowsDots(int level) => level == 2;

class CompareQuestion implements PickQuestion {
  /// Level 1: [left] and [right] pictures of [emoji]; "which side has more?" or "...fewer?".
  const CompareQuestion.picture({required this.left, required this.right, required this.askMore, required this.emoji}) : level = 1;

  /// Levels 2-4: two numbers and a > < = sign to pick.
  const CompareQuestion.numbers({required this.level, required this.left, required this.right})
      : askMore = false,
        emoji = '';

  final int level;
  final int left;
  final int right;
  final bool askMore;
  final String emoji;

  bool get isPicture => level == 1;

  CompareSign get sign => left > right
      ? CompareSign.gt
      : left < right
          ? CompareSign.lt
          : CompareSign.eq;

  /// The game keeps no per-question stats; only its level.
  @override
  String get key => compareLevelKey;

  /// `left`/`right` for the picture cards, otherwise the sign's symbol.
  @override
  String get answer => isPicture ? ((left > right) == askMore ? 'left' : 'right') : sign.symbol;

  int get _picked => answer == 'left' ? left : right;
  int get _other => answer == 'left' ? right : left;

  String get promptId => isPicture ? (askMore ? 'compare_more' : 'compare_fewer') : 'compare_ask';
  Map<String, String> get promptVars => isPicture ? const {} : {'a': '$left', 'b': '$right'};

  /// "Đúng rồi! 7 nhiều hơn 3": the picked side's count first; numbers are said left to right.
  String get rightId => isPicture ? (askMore ? 'compare_right_more' : 'compare_right_fewer') : 'compare_right_${sign.name}';
  Map<String, String> get rightVars => isPicture ? {'a': '$_picked', 'b': '$_other'} : {'a': '$left', 'b': '$right'};

  /// Shown under the numbers once answered, e.g. "3 bé hơn 5".
  String get sentence => '$left ${sign.word} $right';
}

/// A round of [compareRoundLength] questions for [level], none asked twice.
List<CompareQuestion> buildCompareRound({required int level, required Random random}) {
  final seen = <String>{};
  bool fresh(int a, int b) => seen.add('$a-$b');

  if (level <= 1) {
    final start = random.nextInt(compareEmojis.length);
    final out = <CompareQuestion>[];
    while (out.length < compareRoundLength) {
      final a = 1 + random.nextInt(10);
      final b = 1 + random.nextInt(10);
      if (a == b || !fresh(a, b)) continue;
      out.add(CompareQuestion.picture(
        left: a,
        right: b,
        askMore: random.nextBool(),
        emoji: compareEmojis[(start + out.length) % compareEmojis.length],
      ));
    }
    return out;
  }

  final lvl = min(level, compareMaxLevel);
  final max = compareMaxNumber(lvl);
  final out = <CompareQuestion>[];
  void add(int a, int b) => out.add(CompareQuestion.numbers(level: lvl, left: a, right: b));

  while (out.length < _equalPerRound) {
    final n = random.nextInt(max + 1);
    if (fresh(n, n)) add(n, n);
  }
  if (lvl == compareMaxLevel) {
    // Swapped digits (ab vs ba) make the child look at the tens, not just the last digit.
    var swapped = 0;
    while (swapped < _swappedPerRound) {
      final t = 1 + random.nextInt(9);
      final u = 1 + random.nextInt(9);
      if (t == u || !fresh(t * 10 + u, u * 10 + t)) continue;
      add(t * 10 + u, u * 10 + t);
      swapped++;
    }
  }
  while (out.length < compareRoundLength) {
    final a = random.nextInt(max + 1);
    final b = random.nextInt(max + 1);
    if (a == b || !fresh(a, b)) continue;
    add(a, b);
  }
  return out..shuffle(random);
}

/// One level up after [firstTries] >= [compareLevelUpFirstTries] in a round, up to [compareMaxLevel].
int nextCompareLevel(int level, int firstTries) =>
    firstTries >= compareLevelUpFirstTries ? min(level + 1, compareMaxLevel) : level;

int compareLevelOf(Map<String, ItemStat> stats) => (stats[compareLevelKey]?.mastery ?? 0).clamp(0, compareMaxLevel - 1) + 1;

Future<int> loadCompareLevel(ItemStatsStore store) async => compareLevelOf(await store.loadByPrefix(compareLevelKey));

Future<void> saveCompareLevel(ItemStatsStore store, int level, DateTime now) =>
    store.save(ItemStat(key: compareLevelKey, mastery: level.clamp(1, compareMaxLevel) - 1, lastSeen: now));
