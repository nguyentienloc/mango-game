import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xoai_castle/app/providers.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/net/connectivity_probe.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/progress/progress_resetter.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/screen/screen_awake.dart';
import 'package:xoai_castle/core/session/session_store.dart';
import 'package:xoai_castle/core/speech/speech_recognizer.dart';
import 'package:xoai_castle/core/stories/story_store.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/core/voice/voice_service.dart';
import 'package:xoai_castle/features/story/oembed_client.dart';
import 'package:xoai_castle/features/story/story_models.dart';
import 'package:xoai_castle/features/story/story_player.dart';

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
  ProgressResetter? resetter,
  int voiceSeed = 1,
  SpeechRecognizer? speech,
  StoryStore? stories,
  StoryPlayerFactory? storyPlayer,
  ConnectivityProbe? connectivity,
  ScreenAwake? screenAwake,
  OEmbedClient? oembed,
}) {
  const names = Names(en: 'An', vi: 'Xoài');
  return ProviderScope(
    overrides: [
      contentProvider.overrideWithValue(content),
      namesProvider.overrideWithValue(names),
      voiceProvider.overrideWithValue(VoiceService(
        tts: tts,
        phrases: content.phrases,
        names: names,
        random: Random(voiceSeed),
      )),
      itemStatsStoreProvider.overrideWithValue(itemStats ?? MemoryItemStatsStore()),
      sessionStoreProvider.overrideWithValue(sessions ?? MemorySessionStore()),
      rewardStoreProvider.overrideWithValue(rewards ?? MemoryRewardStore()),
      profileStoreProvider.overrideWithValue(profile ?? MemoryProfileStore()),
      progressResetterProvider.overrideWithValue(resetter ?? FakeProgressResetter()),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 9)),
      randomProvider.overrideWithValue(Random(42)),
      appVersionProvider.overrideWithValue('0.1.0'),
      updateCheckProvider.overrideWith((ref) => updateFuture ?? Future.value(update)),
      missingVoicesProvider.overrideWithValue(missingVoices),
      speechRecognizerProvider.overrideWithValue(speech ?? FakeSpeechRecognizer()),
      storyStoreProvider.overrideWithValue(stories ?? MemoryStoryStore()),
      storyPlayerFactoryProvider.overrideWithValue(storyPlayer ?? FakeStoryPlayers().create),
      connectivityProbeProvider.overrideWithValue(connectivity ?? FakeConnectivityProbe()),
      screenAwakeProvider.overrideWithValue(screenAwake ?? FakeScreenAwake()),
      oembedClientProvider.overrideWithValue(oembed ?? FakeOEmbedClient()),
    ],
    child: MaterialApp(home: home),
  );
}

/// [content] with its bundled stories replaced by [stories].
ContentBundle withStories(ContentBundle content, List<Story> stories) => ContentBundle(
  lettersEn: content.lettersEn,
  lettersVi: content.lettersVi,
  phrases: content.phrases,
  castle: content.castle,
  characters: content.characters,
  profileDefaults: content.profileDefaults,
  vocab: content.vocab,
  conversation: content.conversation,
  stories: stories,
);
