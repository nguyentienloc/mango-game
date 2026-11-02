import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

abstract interface class ClipPlayer {
  /// Plays an asset at [speed] (1.0 = as recorded); completes when playback ends or is stopped.
  Future<void> play(String assetPath, {double speed = 1.0});

  Future<void> stop();
}

class JustAudioClipPlayer implements ClipPlayer {
  JustAudioClipPlayer._(this._player);

  final AudioPlayer _player;
  int _token = 0;

  static Future<JustAudioClipPlayer> create() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    return JustAudioClipPlayer._(AudioPlayer());
  }

  @override
  Future<void> play(String assetPath, {double speed = 1.0}) async {
    final token = ++_token;
    // No stop() first: setAsset already interrupts the current clip, and a
    // second stop would rebuild ExoPlayer twice per phrase.
    await _player.setAsset(assetPath);
    // stop() (or a newer play) may have been called while the asset was loading.
    if (token != _token) return;
    await _player.setSpeed(speed);
    if (token != _token) return;
    // just_audio's play() completes when playback finishes, pauses or stops.
    await _player.play();
  }

  @override
  Future<void> stop() {
    _token++;
    return _player.stop();
  }
}
