import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/models.dart';
import '../core/net/connectivity_probe.dart';
import '../core/db/database.dart';
import '../core/profile/profile_store.dart';
import '../core/profile/names.dart';
import '../core/progress/item_stats_store.dart';
import '../core/progress/progress_resetter.dart';
import '../core/screen/screen_awake.dart';
import '../core/rewards/reward_store.dart';
import '../core/session/session_store.dart';
import '../core/speech/speech_recognizer.dart';
import '../core/stories/story_store.dart';
import '../core/speech/speech_to_text_recognizer.dart';
import '../core/updater/app_updater.dart';
import '../core/voice/voice_service.dart';
import '../features/story/oembed_client.dart';
import '../features/story/story_library.dart';
import '../features/story/story_player.dart';
import '../features/story/youtube_story_player.dart';
import 'config.dart';

/// Overridden in main() after bootstrapping.
final contentProvider = Provider<ContentBundle>((ref) => throw UnimplementedError('contentProvider'));
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('databaseProvider'));
final appVersionProvider = Provider<String>((ref) => throw UnimplementedError('appVersionProvider'));
final voiceProvider = Provider<VoiceService>((ref) => throw UnimplementedError('voiceProvider'));
/// The child's names (what VoiceService speaks with); the talk game needs the English one.
final namesProvider = Provider<Names>((ref) => throw UnimplementedError('namesProvider'));

/// Created on first use and NOT initialised until a screen calls init(), so the
/// microphone permission is asked when the child enters the talk game, not at launch.
final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  final recognizer = SpeechToTextRecognizer();
  ref.onDispose(() => recognizer.cancel());
  return recognizer;
});

/// Locales ('vi-VN', 'en-US') the device has no TTS voice for; the parent area warns about them.
final missingVoicesProvider = Provider<Set<String>>((ref) => const {});

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final randomProvider = Provider<Random>((ref) => Random());

final itemStatsStoreProvider = Provider<ItemStatsStore>((ref) => DriftItemStatsStore(ref.watch(databaseProvider)));
final sessionStoreProvider = Provider<SessionStore>((ref) => DriftSessionStore(ref.watch(databaseProvider)));
final profileStoreProvider = Provider<ProfileStore>((ref) => DriftProfileStore(ref.watch(databaseProvider)));
final progressResetterProvider = Provider<ProgressResetter>((ref) => DriftProgressResetter(ref.watch(databaseProvider)));
final rewardStoreProvider = Provider<RewardStore>((ref) => DriftRewardStore(ref.watch(databaseProvider)));

final appUpdaterProvider = Provider<AppUpdater>((ref) {
  // One Dio for the update check and the APK download. receiveTimeout in dio 5
  // is inactivity between received chunks (not a total cap), so a slow but
  // steady download is fine while a stalled check or download fails.
  final dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30)),
  );
  return AppUpdater(api: GithubReleaseApi(dio, kGithubRepo), dio: dio, currentVersion: ref.watch(appVersionProvider));
});

final updateCheckProvider = FutureProvider<UpdateCheck>((ref) => ref.watch(appUpdaterProvider).check());

final storyStoreProvider = Provider<StoryStore>((ref) => DriftStoryStore(ref.watch(databaseProvider)));

/// Bundled stories plus the parent's own and which ones are hidden.
/// Reloads after the parent edits: screens call `ref.invalidate(storyLibraryProvider)`.
final storyLibraryProvider = FutureProvider<StoryLibrary>((ref) async {
  final store = ref.watch(storyStoreProvider);
  return StoryLibrary(
    bundled: ref.watch(contentProvider).stories,
    user: await store.userStories(),
    hidden: await store.hiddenIds(),
  );
});

final oembedClientProvider = Provider<OEmbedClient>((ref) => OEmbedClient(Dio()));

/// Makes the video player for a story screen (a fake in widget tests: no WebView there).
final storyPlayerFactoryProvider = Provider<StoryPlayerFactory>((ref) => YoutubeStoryPlayer.new);

final connectivityProbeProvider = Provider<ConnectivityProbe>((ref) => const DnsConnectivityProbe());

final screenAwakeProvider = Provider<ScreenAwake>((ref) => const WakelockScreenAwake());
