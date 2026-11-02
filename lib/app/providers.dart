import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/models.dart';
import '../core/db/database.dart';
import '../core/progress/item_stats_store.dart';
import '../core/rewards/reward_store.dart';
import '../core/session/session_store.dart';

/// Overridden in main() after bootstrapping.
final contentProvider = Provider<ContentBundle>((ref) => throw UnimplementedError('contentProvider'));
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('databaseProvider'));
final appVersionProvider = Provider<String>((ref) => throw UnimplementedError('appVersionProvider'));

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final randomProvider = Provider<Random>((ref) => Random());

final itemStatsStoreProvider = Provider<ItemStatsStore>((ref) => DriftItemStatsStore(ref.watch(databaseProvider)));
final sessionStoreProvider = Provider<SessionStore>((ref) => DriftSessionStore(ref.watch(databaseProvider)));
final rewardStoreProvider = Provider<RewardStore>((ref) => DriftRewardStore(ref.watch(databaseProvider)));
