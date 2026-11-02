import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/profile/profile_store.dart';
import 'providers.dart';

/// Parent setting: speech speed per language. The voice picks changes up immediately.
final voiceSpeedsProvider = AsyncNotifierProvider<VoiceSpeedsController, VoiceSpeeds>(VoiceSpeedsController.new);

class VoiceSpeedsController extends AsyncNotifier<VoiceSpeeds> {
  @override
  Future<VoiceSpeeds> build() => ref.watch(profileStoreProvider).voiceSpeeds();

  /// Follows a slider while it is being dragged; nothing is saved yet.
  void preview(VoiceSpeeds speeds) => state = AsyncData(speeds.clamped());

  /// Saves to the database and applies to the voice right away.
  Future<void> set(VoiceSpeeds speeds) async {
    final s = speeds.clamped();
    state = AsyncData(s);
    ref.read(voiceProvider).speeds = s;
    await ref.read(profileStoreProvider).setVoiceSpeeds(s);
  }
}
