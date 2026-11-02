import 'package:drift/drift.dart';

import '../db/database.dart';
import 'item_stat.dart';

abstract interface class ItemStatsStore {
  Future<Map<String, ItemStat>> loadByPrefix(String prefix);
  Future<void> save(ItemStat stat);
}

class DriftItemStatsStore implements ItemStatsStore {
  DriftItemStatsStore(this._db);

  final AppDatabase _db;

  @override
  Future<Map<String, ItemStat>> loadByPrefix(String prefix) async {
    final rows = await _db.select(_db.itemStats).get();
    return {
      for (final r in rows)
        if (r.itemKey.startsWith(prefix))
          r.itemKey: ItemStat(
            key: r.itemKey,
            mastery: r.mastery,
            correct: r.correct,
            wrong: r.wrong,
            lastSeen: r.lastSeen,
          ),
    };
  }

  @override
  Future<void> save(ItemStat stat) async {
    await _db.into(_db.itemStats).insertOnConflictUpdate(ItemStatsCompanion(
          itemKey: Value(stat.key),
          mastery: Value(stat.mastery),
          correct: Value(stat.correct),
          wrong: Value(stat.wrong),
          lastSeen: Value(stat.lastSeen),
        ));
  }
}
