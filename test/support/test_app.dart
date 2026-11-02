import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xoai_castle/app/providers.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/core/voice/voice_service.dart';

import 'fakes.dart';

Widget testApp({
  required ContentBundle content,
  required FakeTts tts,
  required Widget home,
  ItemStatsStore? itemStats,
  SessionStore? sessions,
  RewardStore? rewards,
  ProfileStore? profile,
  UpdateCheck update = const UpToDate(),
  Set<String> missingVoices = const {},
  Future<UpdateCheck>? updateFuture,
}) {
  return ProviderScope(
    overrides: [
      contentProvider.overrideWithValue(content),
      voiceProvider.overrideWithValue(VoiceService(
        tts: tts,
        phrases: content.phrases,
        names: const Names(en: 'An', vi: 'Xoài'),
        random: Random(1),
      )),
      itemStatsStoreProvider.overrideWithValue(itemStats ?? MemoryItemStatsStore()),
      sessionStoreProvider.overrideWithValue(sessions ?? MemorySessionStore()),
      rewardStoreProvider.overrideWithValue(rewards ?? MemoryRewardStore()),
      profileStoreProvider.overrideWithValue(profile ?? MemoryProfileStore()),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 9)),
      randomProvider.overrideWithValue(Random(42)),
      appVersionProvider.overrideWithValue('0.1.0'),
      updateCheckProvider.overrideWith((ref) => updateFuture ?? Future.value(update)),
      missingVoicesProvider.overrideWithValue(missingVoices),
    ],
    child: MaterialApp(home: home),
  );
}
