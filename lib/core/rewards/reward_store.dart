import 'package:drift/drift.dart';

import '../db/database.dart';
import 'reward_state.dart';

abstract interface class RewardStore {
  Future<RewardState> load();
  Future<void> save(RewardState state);
}

class DriftRewardStore implements RewardStore {
  DriftRewardStore(this._db);

  final AppDatabase _db;

  @override
  Future<RewardState> load() async {
    await _db.into(_db.rewards).insert(RewardsCompanion.insert(id: const Value(1)), mode: InsertMode.insertOrIgnore);
    final row = await (_db.select(_db.rewards)..where((t) => t.id.equals(1))).getSingle();
    return RewardState(
      snowflakesTotal: row.snowflakesTotal,
      castleLevel: row.castleLevel,
      streakDays: row.streakDays,
      lastPlayDate: row.lastPlayDate,
      dailyQuestDate: row.dailyQuestDate,
      dailyRoundsDone: row.dailyRoundsDone,
    );
  }

  @override
  Future<void> save(RewardState s) async {
    await _db.into(_db.rewards).insertOnConflictUpdate(RewardsCompanion(
          id: const Value(1),
          snowflakesTotal: Value(s.snowflakesTotal),
          castleLevel: Value(s.castleLevel),
          streakDays: Value(s.streakDays),
          lastPlayDate: Value(s.lastPlayDate),
          dailyQuestDate: Value(s.dailyQuestDate),
          dailyRoundsDone: Value(s.dailyRoundsDone),
        ));
  }
}
