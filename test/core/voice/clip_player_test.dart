import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/voice/clip_player.dart';

/// Mimics just_audio 0.10.x on Android: a clip that played to its end stays
/// `playing`, setAsset does not clear that, play() returns at once when already
/// playing, and a new asset auto-starts while `playing` is still true.
class FakeClipAudio implements ClipAudio {
  final log = <String>[];
  final _completed = StreamController<bool>.broadcast();
  bool pauseKeepsPlaying = false;
  bool _playing = false;
  bool _isCompleted = false;
  Completer<void>? _playResult;

  @override
  bool get playing => _playing;

  @override
  Stream<bool> get completedStream async* {
    yield _isCompleted;
    yield* _completed.stream;
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    if (!pauseKeepsPlaying) _playing = false;
  }

  @override
  Future<void> setSpeed(double speed) async => log.add('speed:$speed');

  @override
  Future<void> setAsset(String assetPath) async {
    log.add('load:$assetPath');
    _setCompleted(false);
  }

  @override
  Future<void> play() async {
    log.add('play');
    if (_playing) return;
    _playing = true;
    final c = _playResult = Completer<void>();
    await c.future;
  }

  @override
  Future<void> stop() async {
    log.add('stop');
    _playing = false;
    _setCompleted(false);
    _end();
  }

  /// The loaded clip reaches its end: play() resolves, `playing` stays true.
  void finishClip() {
    _setCompleted(true);
    _end();
  }

  void _end() {
    final c = _playResult;
    _playResult = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  void _setCompleted(bool v) {
    _isCompleted = v;
    _completed.add(v);
  }
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeClipAudio audio;
  late JustAudioClipPlayer player;

  setUp(() {
    audio = FakeClipAudio();
    player = JustAudioClipPlayer.withAudio(audio);
  });

  test('plays a clip until it completes', () async {
    var done = false;
    final f = player.play('a.ogg', speed: 0.8).then((_) => done = true);
    await settle();
    expect(done, isFalse);
    expect(audio.log, ['speed:0.8', 'load:a.ogg', 'play']);
    audio.finishClip();
    await f;
    expect(done, isTrue);
  });

  test('a second play after a completed clip waits for its own completion', () async {
    final first = player.play('a.ogg');
    await settle();
    audio.finishClip();
    await first;
    expect(audio.playing, isTrue, reason: 'just_audio keeps playing == true after completion');

    var done = false;
    final second = player.play('b.ogg', speed: 0.7).then((_) => done = true);
    await settle();
    expect(audio.log.skip(3), ['pause', 'speed:0.7', 'load:b.ogg', 'play']);
    expect(done, isFalse, reason: 'must not return before the second clip ends');
    audio.finishClip();
    await second;
    expect(done, isTrue);
  });

  test('if play() returns early while still playing, the player still waits for the clip end', () async {
    audio.pauseKeepsPlaying = true;
    final first = player.play('a.ogg');
    await settle();
    audio.finishClip();
    await first;

    var done = false;
    final second = player.play('b.ogg').then((_) => done = true);
    await settle();
    expect(done, isFalse);
    audio.finishClip();
    await second;
    expect(done, isTrue);
  });

  test('a newer play ends the wait of the previous one', () async {
    var firstDone = false;
    final first = player.play('a.ogg').then((_) => firstDone = true);
    await settle();
    final second = player.play('b.ogg');
    await settle();
    expect(firstDone, isTrue);
    audio.finishClip();
    await second;
    await first;
  });

  test('stop() ends a pending play', () async {
    var done = false;
    final f = player.play('a.ogg').then((_) => done = true);
    await settle();
    expect(done, isFalse);
    await player.stop();
    await f;
    expect(done, isTrue);
    expect(audio.log.last, 'stop');
  });

  test('stop() during loading prevents the clip from starting', () async {
    final f = player.play('a.ogg');
    await player.stop();
    await f;
    expect(audio.log, isNot(contains('play')));
  });
}
