import 'package:drift/drift.dart';

import '../db/database.dart';

abstract interface class ProgressResetter {
  /// Deletes all learning progress and rewards; keeps the profile (names, switches).
  Future<void> resetProgress();
}

class DriftProgressResetter implements ProgressResetter {
  DriftProgressResetter(this._db);

  final AppDatabase _db;

  @override
  Future<void> resetProgress() => _db.transaction(() async {
        await _db.delete(_db.itemStats).go();
        await _db.delete(_db.sessions).go();
        await _db.into(_db.rewards).insertOnConflictUpdate(RewardsCompanion(
              id: const Value(1),
              snowflakesTotal: const Value(0),
              castleLevel: const Value(1),
              streakDays: const Value(0),
              lastPlayDate: const Value(null),
              dailyQuestDate: const Value(null),
              dailyRoundsDone: const Value(0),
            ));
      });
}
