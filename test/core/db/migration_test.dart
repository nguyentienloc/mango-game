import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/db/database.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';

/// DDL of the v1 tables (captured from sqlite_master of a freshly created v1 database).
const _itemStatsV1 =
    'CREATE TABLE "item_stats" ("item_key" TEXT NOT NULL, "mastery" INTEGER NOT NULL DEFAULT 0, "correct" INTEGER NOT NULL DEFAULT 0, "wrong" INTEGER NOT NULL DEFAULT 0, "last_seen" INTEGER NULL, PRIMARY KEY ("item_key"))';
const _sessionsV1 =
    'CREATE TABLE "sessions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "date" TEXT NOT NULL, "game" TEXT NOT NULL, "started_at" INTEGER NOT NULL, "duration_sec" INTEGER NOT NULL, "correct" INTEGER NOT NULL, "total" INTEGER NOT NULL)';
const _rewardsV1 =
    'CREATE TABLE "rewards" ("id" INTEGER NOT NULL DEFAULT 1, "snowflakes_total" INTEGER NOT NULL DEFAULT 0, "castle_level" INTEGER NOT NULL DEFAULT 1, "streak_days" INTEGER NOT NULL DEFAULT 0, "last_play_date" TEXT NULL, "daily_quest_date" TEXT NULL, "daily_rounds_done" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))';

/// DDL of the `profile` table at schema v1 (copied from the v1 generated code).
const _profileV1 =
    'CREATE TABLE "profile" ("id" INTEGER NOT NULL DEFAULT 1, "name_en" TEXT NOT NULL, "name_vi" TEXT NOT NULL, "daily_limit_min" INTEGER NOT NULL, "music_on" INTEGER NOT NULL DEFAULT 1 CHECK ("music_on" IN (0, 1)), "test_mode" INTEGER NOT NULL DEFAULT 0 CHECK ("test_mode" IN (0, 1)), PRIMARY KEY ("id"))';

void main() {
  test('upgrading from v1 keeps the profile and adds showFindLetter = false', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute(_profileV1);
      raw.execute("INSERT INTO profile (id, name_en, name_vi, daily_limit_min) VALUES (1, 'An', 'Xoài', 20)");
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(db.close);

    final store = DriftProfileStore(db);
    expect(await store.showFindLetter(), isFalse);
    final row = await db.select(db.profile).getSingle();
    expect([row.nameEn, row.nameVi, row.dailyLimitMin], ['An', 'Xoài', 20]);
  });

  test('upgrading from v1 keeps the rows of every other table', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      for (final ddl in [_itemStatsV1, _sessionsV1, _rewardsV1, _profileV1]) {
        raw.execute(ddl);
      }
      raw.execute("INSERT INTO item_stats (item_key, mastery, correct, wrong) VALUES ('letter_en_upper:A', 2, 3, 1)");
      raw.execute("INSERT INTO sessions (date, game, started_at, duration_sec, correct, total) VALUES ('2026-11-01', 'letters', 1000, 60, 7, 8)");
      raw.execute("INSERT INTO rewards (id, snowflakes_total, castle_level, streak_days) VALUES (1, 42, 3, 5)");
      raw.execute("INSERT INTO profile (id, name_en, name_vi, daily_limit_min, music_on, test_mode) VALUES (1, 'An', 'Xoài', 20, 0, 1)");
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(db.close);

    final stat = await db.select(db.itemStats).getSingle();
    expect([stat.itemKey, stat.mastery, stat.correct, stat.wrong], ['letter_en_upper:A', 2, 3, 1]);
    final session = await db.select(db.sessions).getSingle();
    expect([session.game, session.correct, session.total], ['letters', 7, 8]);
    final rewards = await db.select(db.rewards).getSingle();
    expect([rewards.snowflakesTotal, rewards.castleLevel, rewards.streakDays], [42, 3, 5]);
    final profile = await db.select(db.profile).getSingle();
    expect([profile.musicOn, profile.testMode, profile.showFindLetter], [false, true, false]);
  });
}
