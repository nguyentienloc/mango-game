import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/db/database.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/stories/story_store.dart';
import 'package:xoai_castle/features/story/story_models.dart';

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

/// DDL of the `profile` table at schema v2 (captured from sqlite_master of a
/// freshly created v2 database, before the v3 columns existed).
const _profileV2 =
    'CREATE TABLE "profile" ("id" INTEGER NOT NULL DEFAULT 1, "name_en" TEXT NOT NULL, "name_vi" TEXT NOT NULL, "daily_limit_min" INTEGER NOT NULL, "music_on" INTEGER NOT NULL DEFAULT 1 CHECK ("music_on" IN (0, 1)), "test_mode" INTEGER NOT NULL DEFAULT 0 CHECK ("test_mode" IN (0, 1)), "show_find_letter" INTEGER NOT NULL DEFAULT 0 CHECK ("show_find_letter" IN (0, 1)), PRIMARY KEY ("id"))';

/// DDL of the `profile` table at schema v3 (captured from sqlite_master of a
/// freshly created v3 database, before the v4 storySetup column existed).
const _profileV3 =
    'CREATE TABLE "profile" ("id" INTEGER NOT NULL DEFAULT 1, "name_en" TEXT NOT NULL, "name_vi" TEXT NOT NULL, "daily_limit_min" INTEGER NOT NULL, "music_on" INTEGER NOT NULL DEFAULT 1 CHECK ("music_on" IN (0, 1)), "test_mode" INTEGER NOT NULL DEFAULT 0 CHECK ("test_mode" IN (0, 1)), "show_find_letter" INTEGER NOT NULL DEFAULT 0 CHECK ("show_find_letter" IN (0, 1)), "en_speed" REAL NOT NULL DEFAULT 0.85, "vi_speed" REAL NOT NULL DEFAULT 1.0, PRIMARY KEY ("id"))';

void main() {
  test('upgrading from v1 keeps the profile and adds showFindLetter = false', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(_profileV1);
          raw.execute("INSERT INTO profile (id, name_en, name_vi, daily_limit_min) VALUES (1, 'An', 'Xoài', 20)");
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(db.close);

    final store = DriftProfileStore(db);
    expect(await store.showFindLetter(), isFalse);
    final row = await db.select(db.profile).getSingle();
    expect([row.nameEn, row.nameVi, row.dailyLimitMin], ['An', 'Xoài', 20]);
  });

  test('upgrading from v1 keeps the rows of every other table', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final ddl in [_itemStatsV1, _sessionsV1, _rewardsV1, _profileV1]) {
            raw.execute(ddl);
          }
          raw.execute(
            "INSERT INTO item_stats (item_key, mastery, correct, wrong) VALUES ('letter_en_upper:A', 2, 3, 1)",
          );
          raw.execute(
            "INSERT INTO sessions (date, game, started_at, duration_sec, correct, total) VALUES ('2026-11-01', 'letters', 1000, 60, 7, 8)",
          );
          raw.execute("INSERT INTO rewards (id, snowflakes_total, castle_level, streak_days) VALUES (1, 42, 3, 5)");
          raw.execute(
            "INSERT INTO profile (id, name_en, name_vi, daily_limit_min, music_on, test_mode) VALUES (1, 'An', 'Xoài', 20, 0, 1)",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
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

  test('upgrading from v2 keeps every row and adds default speeds (en 0.85, vi 1.0)', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final ddl in [_itemStatsV1, _sessionsV1, _rewardsV1, _profileV2]) {
            raw.execute(ddl);
          }
          raw.execute(
            "INSERT INTO item_stats (item_key, mastery, correct, wrong) VALUES ('letter_en_upper:A', 2, 3, 1)",
          );
          raw.execute(
            "INSERT INTO sessions (date, game, started_at, duration_sec, correct, total) VALUES ('2026-11-01', 'letters', 1000, 60, 7, 8)",
          );
          raw.execute("INSERT INTO rewards (id, snowflakes_total, castle_level, streak_days) VALUES (1, 42, 3, 5)");
          raw.execute(
            "INSERT INTO profile (id, name_en, name_vi, daily_limit_min, music_on, test_mode, show_find_letter) VALUES (1, 'An', 'Xoài', 20, 0, 1, 1)",
          );
          raw.execute('PRAGMA user_version = 2');
        },
      ),
    );
    addTearDown(db.close);

    final profile = await db.select(db.profile).getSingle();
    expect([profile.nameEn, profile.nameVi, profile.dailyLimitMin], ['An', 'Xoài', 20]);
    expect([profile.musicOn, profile.testMode, profile.showFindLetter], [false, true, true]);
    expect([profile.enSpeed, profile.viSpeed], [0.85, 1.0]);
    final stat = await db.select(db.itemStats).getSingle();
    expect([stat.itemKey, stat.mastery, stat.correct, stat.wrong], ['letter_en_upper:A', 2, 3, 1]);
    final session = await db.select(db.sessions).getSingle();
    expect([session.game, session.correct, session.total], ['letters', 7, 8]);
    final rewards = await db.select(db.rewards).getSingle();
    expect([rewards.snowflakesTotal, rewards.castleLevel, rewards.streakDays], [42, 3, 5]);
    expect(await DriftProfileStore(db).voiceSpeeds(), const VoiceSpeeds());
  });

  test('upgrading from v1 reaches v3: default speeds and showFindLetter', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(_profileV1);
          raw.execute("INSERT INTO profile (id, name_en, name_vi, daily_limit_min) VALUES (1, 'An', 'Xoài', 20)");
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(db.close);

    final profile = await db.select(db.profile).getSingle();
    expect([profile.nameEn, profile.showFindLetter, profile.enSpeed, profile.viSpeed], ['An', false, 0.85, 1.0]);
  });

  test('speeds are saved, read back and clamped', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftProfileStore(db);
    await store.loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
    expect(await store.voiceSpeeds(), const VoiceSpeeds());
    await store.setVoiceSpeeds(const VoiceSpeeds(en: 0.7, vi: 1.25));
    expect(await store.voiceSpeeds(), const VoiceSpeeds(en: 0.7, vi: 1.25));
    await store.setVoiceSpeeds(const VoiceSpeeds(en: 0.1, vi: 9));
    expect(await store.voiceSpeeds(), const VoiceSpeeds(en: 0.6, vi: 1.3));
  });

  test(
    'upgrading from v3 keeps every row and adds the story tables and setup',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            for (final ddl in [
              _itemStatsV1,
              _sessionsV1,
              _rewardsV1,
              _profileV3,
            ]) {
              raw.execute(ddl);
            }
            raw.execute(
              "INSERT INTO item_stats (item_key, mastery, correct, wrong) VALUES ('letter_en_upper:A', 2, 3, 1)",
            );
            raw.execute(
              "INSERT INTO sessions (date, game, started_at, duration_sec, correct, total) VALUES ('2026-11-01', 'letters', 1000, 60, 7, 8)",
            );
            raw.execute(
              "INSERT INTO rewards (id, snowflakes_total, castle_level, streak_days) VALUES (1, 42, 3, 5)",
            );
            raw.execute(
              "INSERT INTO profile (id, name_en, name_vi, daily_limit_min, music_on, test_mode, show_find_letter, en_speed, vi_speed) VALUES (1, 'An', 'Xoài', 20, 0, 1, 1, 0.7, 1.2)",
            );
            raw.execute('PRAGMA user_version = 3');
          },
        ),
      );
      addTearDown(db.close);

      final profile = await db.select(db.profile).getSingle();
      expect(
        [
          profile.nameEn,
          profile.dailyLimitMin,
          profile.musicOn,
          profile.enSpeed,
          profile.viSpeed,
        ],
        ['An', 20, false, 0.7, 1.2],
      );
      expect(profile.storySetup, isNull);
      final stat = await db.select(db.itemStats).getSingle();
      expect([stat.itemKey, stat.mastery], ['letter_en_upper:A', 2]);
      expect((await db.select(db.sessions).getSingle()).total, 8);
      expect((await db.select(db.rewards).getSingle()).snowflakesTotal, 42);

      final store = DriftStoryStore(db);
      expect(await store.userStories(), isEmpty);
      expect(await store.hiddenIds(), isEmpty);
      await store.addUserStory(
        const Story(
          videoId: 'abcdefghijk',
          title: 'Truyện',
          topic: StoryTopic.other,
          userAdded: true,
        ),
      );
      await store.setHidden('yt:x', true);
      await store.saveSetup(const StorySetup(topics: {StoryTopic.english}));
      expect((await store.userStories()).single.videoId, 'abcdefghijk');
      expect(await store.hiddenIds(), {'yt:x'});
      expect((await store.lastSetup()).topics, {StoryTopic.english});
    },
  );

  test(
    'upgrading from v1 reaches v4: story tables exist, other data kept',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(_profileV1);
            raw.execute(
              "INSERT INTO profile (id, name_en, name_vi, daily_limit_min) VALUES (1, 'An', 'Xoài', 20)",
            );
            raw.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(db.close);

      final profile = await db.select(db.profile).getSingle();
      expect(
        [profile.nameEn, profile.enSpeed, profile.storySetup],
        ['An', 0.85, null],
      );
      final store = DriftStoryStore(db);
      expect(await store.userStories(), isEmpty);
      await store.setHidden('yt:x', true);
      expect(await store.hiddenIds(), {'yt:x'});
      // Setup is saved even though the migrated profile row exists already.
      await store.saveSetup(const StorySetup(mode: StoryViewMode.watch));
      expect((await store.lastSetup()).mode, StoryViewMode.watch);
    },
  );
}
