import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

abstract interface class ClipPlayer {
  /// Plays an asset at [speed] (1.0 = as recorded); completes when playback ends or is stopped.
  Future<void> play(String assetPath, {double speed = 1.0});

  Future<void> stop();
}

/// The few just_audio calls [JustAudioClipPlayer] needs, so its sequencing can
/// be unit-tested without a platform plugin.
abstract interface class ClipAudio {
  bool get playing;

  /// Emits whether the loaded clip has played to its end (current value first).
  Stream<bool> get completedStream;

  Future<void> pause();
  Future<void> setSpeed(double speed);
  Future<void> setAsset(String assetPath);
  Future<void> play();
  Future<void> stop();
}

class _JustAudioClipAudio implements ClipAudio {
  _JustAudioClipAudio(this._player);
  final AudioPlayer _player;

  @override
  bool get playing => _player.playing;
  @override
  Stream<bool> get completedStream => _player.processingStateStream.map((s) => s == ProcessingState.completed);
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> setAsset(String assetPath) => _player.setAsset(assetPath);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> stop() => _player.stop();
}

class JustAudioClipPlayer implements ClipPlayer {
  JustAudioClipPlayer._(this._audio);

  @visibleForTesting
  JustAudioClipPlayer.withAudio(ClipAudio audio) : _audio = audio;

  final ClipAudio _audio;
  int _token = 0;
  Completer<void> _stopped = Completer<void>();

  static Future<JustAudioClipPlayer> create() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    return JustAudioClipPlayer._(_JustAudioClipAudio(AudioPlayer()));
  }

  @override
  Future<void> play(String assetPath, {double speed = 1.0}) async {
    final token = ++_token;
    // Ends the wait of a previous play() that is still pending.
    if (!_stopped.isCompleted) _stopped.complete();
    final stopped = _stopped = Completer<void>();
    // A clip that played to its end stays `playing` (just_audio keeps
    // playWhenReady, and Android's setAsset does not clear it), so the next
    // asset would auto-start and play() would return at once. Pause first.
    if (_audio.playing) await _audio.pause();
    if (token != _token) return;
    await _audio.setSpeed(speed);
    if (token != _token) return;
    // No stop() here: loading a new asset already interrupts the current clip,
    // and a stop would rebuild ExoPlayer for every part.
    await _audio.setAsset(assetPath);
    // stop() (or a newer play) may have been called while the asset was loading.
    if (token != _token) return;
    // just_audio's play() normally completes when the clip ends, but returns
    // at once if the player is already "playing"; wait for the end explicitly.
    await Future.any([_audio.play(), stopped.future]);
    if (token != _token || !_audio.playing) return;
    await Future.any([_audio.completedStream.firstWhere((done) => done), stopped.future]);
  }

  @override
  Future<void> stop() {
    _token++;
    if (!_stopped.isCompleted) _stopped.complete();
    return _audio.stop();
  }
}
