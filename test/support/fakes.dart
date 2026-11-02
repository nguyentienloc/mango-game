import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';
import 'package:xoai_castle/core/voice/tts_engine.dart';

class FakeTts implements TtsEngine {
  final calls = <String>[];
  final spoken = <({String text, String lang})>[];

  List<String> get texts => [for (final s in spoken) s.text];

  @override
  Future<void> speak(String text, {required String lang}) async {
    calls.add('speak');
    spoken.add((text: text, lang: lang));
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

class MemoryItemStatsStore implements ItemStatsStore {
  final stats = <String, ItemStat>{};

  @override
  Future<Map<String, ItemStat>> loadByPrefix(String prefix) async =>
      {for (final e in stats.entries) if (e.key.startsWith(prefix)) e.key: e.value};

  @override
  Future<void> save(ItemStat stat) async => stats[stat.key] = stat;
}

class FailingItemStatsStore implements ItemStatsStore {
  @override
  Future<Map<String, ItemStat>> loadByPrefix(String prefix) => Future.error(StateError('db broken'));

  @override
  Future<void> save(ItemStat stat) => Future.error(StateError('db broken'));
}

class MemorySessionStore implements SessionStore {
  final records = <SessionRecord>[];

  @override
  Future<void> add(SessionRecord record) async => records.add(record);
}

class MemoryRewardStore implements RewardStore {
  MemoryRewardStore([this.state = const RewardState()]);

  RewardState state;

  @override
  Future<RewardState> load() async => state;

  @override
  Future<void> save(RewardState s) async => state = s;
}
