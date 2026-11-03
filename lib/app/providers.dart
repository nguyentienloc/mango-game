import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/models.dart';
import '../core/db/database.dart';
import '../core/profile/profile_store.dart';
import '../core/progress/item_stats_store.dart';
import '../core/progress/progress_resetter.dart';
import '../core/rewards/reward_store.dart';
import '../core/session/session_store.dart';
import '../core/speech/speech_recognizer.dart';
import '../core/speech/speech_to_text_recognizer.dart';
import '../core/updater/app_updater.dart';
import '../core/voice/voice_service.dart';
import 'config.dart';

/// Overridden in main() after bootstrapping.
final contentProvider = Provider<ContentBundle>((ref) => throw UnimplementedError('contentProvider'));
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('databaseProvider'));
final appVersionProvider = Provider<String>((ref) => throw UnimplementedError('appVersionProvider'));
final voiceProvider = Provider<VoiceService>((ref) => throw UnimplementedError('voiceProvider'));

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
