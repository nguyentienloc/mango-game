import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/db/database.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('item stats are saved, updated and loaded by prefix', () async {
    final store = DriftItemStatsStore(db);
    final seen = DateTime(2026, 11, 2, 9, 30);
    await store.save(ItemStat(key: 'letter_en_upper:A', mastery: 2, correct: 3, wrong: 1, lastSeen: seen));
    await store.save(const ItemStat(key: 'word:cat', mastery: 1));
    await store.save(ItemStat(key: 'letter_en_upper:A', mastery: 3, correct: 4, wrong: 1, lastSeen: seen));

    final stats = await store.loadByPrefix('letter_en_');
    expect(stats.keys, ['letter_en_upper:A']);
    final a = stats['letter_en_upper:A']!;
    expect([a.mastery, a.correct, a.wrong], [3, 4, 1]);
    expect(a.lastSeen, seen);
  });

  test('reward store returns defaults first, then persists', () async {
    final store = DriftRewardStore(db);
    final initial = await store.load();
    expect(initial.snowflakesTotal, 0);
    expect(initial.castleLevel, 1);

    await store.save(const RewardState(
      snowflakesTotal: 42,
      castleLevel: 2,
      lastPlayDate: '2026-11-02',
      dailyQuestDate: '2026-11-02',
      dailyRoundsDone: 2,
    ));
    final loaded = await DriftRewardStore(db).load();
    expect(loaded.snowflakesTotal, 42);
    expect(loaded.castleLevel, 2);
    expect(loaded.dailyQuestDate, '2026-11-02');
    expect(loaded.dailyRoundsDone, 2);
  });

  test('session store appends records', () async {
    await DriftSessionStore(db).add(SessionRecord(
      date: '2026-11-02',
      game: 'find_letter',
      startedAt: DateTime(2026, 11, 2, 9),
      durationSec: 150,
      correct: 6,
      total: 8,
    ));
    final rows = await db.select(db.sessions).get();
    expect(rows.single.game, 'find_letter');
    expect(rows.single.durationSec, 150);
  });

  test('profile store inserts defaults once', () async {
    final store = DriftProfileStore(db);
    final first = await store.loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
    final second = await store.loadNames(const ProfileDefaults(nameEn: 'Other', nameVi: 'Khác', dailyLimitMin: 5));
    expect([first.en, first.vi], ['An', 'Xoài']);
    expect([second.en, second.vi], ['An', 'Xoài']);
  });

  test('showFindLetter defaults to false and can be toggled', () async {
    final store = DriftProfileStore(db);
    await store.loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
    expect(await store.showFindLetter(), isFalse);
    await store.setShowFindLetter(true);
    expect(await DriftProfileStore(db).showFindLetter(), isTrue);
  });
}
