import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/content/asset_content_source.dart';
import 'core/content/content_repository.dart';
import 'core/db/database.dart';
import 'core/profile/profile_store.dart';
import 'core/voice/clip_library.dart';
import 'core/voice/clip_player.dart';
import 'core/voice/flutter_tts_engine.dart';
import 'core/voice/voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final content = await ContentRepository(AssetContentSource()).load();
  final db = AppDatabase(driftDatabase(name: 'xoai'));
  final profileStore = DriftProfileStore(db);
  final names = await profileStore.loadNames(content.profileDefaults);
  final speeds = await profileStore.voiceSpeeds();
  final clips = await ClipLibrary.load(AssetContentSource());
  ClipPlayer? player;
  try {
    player = await JustAudioClipPlayer.create();
  } on Object catch (e) {
    debugPrint('Clip player unavailable: $e — voice uses TTS only');
  }
  final tts = await FlutterTtsEngine.create();
  final info = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      overrides: [
        contentProvider.overrideWithValue(content),
        databaseProvider.overrideWithValue(db),
        voiceProvider.overrideWithValue(
          VoiceService(tts: tts, phrases: content.phrases, names: names, clips: clips, player: player, speeds: speeds),
        ),
        appVersionProvider.overrideWithValue(info.version),
        missingVoicesProvider.overrideWithValue(tts.missingLocales),
      ],
      child: const XoaiApp(),
    ),
  );
}
