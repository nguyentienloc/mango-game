import 'dart:async';

import 'voice_service.dart';

/// Says phrase [id] but returns after at most [cap], so a broken TTS can't stall
/// the caller (a menu, a reward). The phrase keeps playing if the cap hits first.
Future<void> sayCapped(VoiceService voice, String id, {Duration cap = const Duration(seconds: 3)}) async {
  final capped = Completer<void>();
  final timer = Timer(cap, capped.complete);
  try {
    await Future.any([voice.say(id), capped.future]);
  } finally {
    timer.cancel();
  }
}
