import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/db/database.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/progress/progress_resetter.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';

void main() {
  test('reset clears progress and keeps the profile', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final profile = DriftProfileStore(db);
    await profile.loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
    await profile.setShowFindLetter(true);
    await DriftItemStatsStore(db).save(const ItemStat(key: 'word:lion', mastery: 3));
    await DriftSessionStore(db).add(SessionRecord(
        date: '2026-11-02', game: 'vocab', startedAt: DateTime(2026, 11, 2, 9), durationSec: 60, correct: 8, total: 8));
    await DriftRewardStore(db).save(const RewardState(
        snowflakesTotal: 120, castleLevel: 4, streakDays: 3, dailyQuestDate: '2026-11-02', dailyRoundsDone: 2));

    await DriftProgressResetter(db).resetProgress();

    expect(await DriftItemStatsStore(db).loadByPrefix(''), isEmpty);
    expect(await db.select(db.sessions).get(), isEmpty);
    final r = await DriftRewardStore(db).load();
    expect([r.snowflakesTotal, r.castleLevel, r.streakDays, r.dailyRoundsDone], [0, 1, 0, 0]);
    expect(r.dailyQuestDate, isNull);
    expect(await profile.showFindLetter(), isTrue);
    expect((await profile.loadNames(const ProfileDefaults(nameEn: 'X', nameVi: 'Y', dailyLimitMin: 1))).vi, 'Xoài');
  });
}
