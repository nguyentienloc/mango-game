import 'dart:math';

import 'item_stat.dart';

class QuestionPicker {
  QuestionPicker(this._random);

  final Random _random;

  /// Picks [count] keys from [candidates]. Keys with lower mastery are more
  /// likely (weight = 5 − mastery; unseen keys count as mastery 0). At most
  /// [maxNew] distinct unseen keys are used, and a key never appears twice in a row.
  List<String> pick({
    required List<String> candidates,
    required Map<String, ItemStat> stats,
    required int count,
    int maxNew = 2,
  }) {
    if (candidates.isEmpty) return const [];
    final picked = <String>[];
    final newUsed = <String>{};
    for (var i = 0; i < count; i++) {
      final last = picked.isEmpty ? null : picked.last;
      bool allowed(String k) =>
          k != last && (stats.containsKey(k) || newUsed.contains(k) || newUsed.length < maxNew);
      var pool = candidates.where(allowed).toList();
      if (pool.isEmpty) pool = candidates.where((k) => k != last).toList();
      if (pool.isEmpty) pool = candidates;
      final key = _weighted(pool, stats);
      if (!stats.containsKey(key)) newUsed.add(key);
      picked.add(key);
    }
    return picked;
  }

  String _weighted(List<String> pool, Map<String, ItemStat> stats) {
    final weights = [for (final k in pool) 5 - (stats[k]?.mastery ?? 0)];
    final total = weights.fold<int>(0, (a, b) => a + b);
    var roll = _random.nextInt(total);
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll < 0) return pool[i];
    }
    return pool.last;
  }
}
