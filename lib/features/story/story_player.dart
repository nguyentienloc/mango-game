import 'package:flutter/widgets.dart';

enum StoryPlayerState { loading, playing, paused, ended, error }

/// A video player for one story screen. The real one is [YoutubeStoryPlayer];
/// tests use a fake (widget tests cannot run a WebView).
abstract interface class StoryPlayerController {
  /// Distinct states as they change; `error` covers blocked embeds and a load that never finishes.
  Stream<StoryPlayerState> get states;

  /// The video length; null until the player knows it.
  Future<Duration?> duration();

  /// Loads [videoId] and starts playing it.
  Future<void> load(String videoId);

  Future<void> play();

  Future<void> pause();

  /// 0..100.
  Future<void> setVolume(int percent);

  /// The video surface. The story screen wraps it in IgnorePointer and a touch shield;
  /// with `controls: true` (the parent's preview) it takes touches.
  Widget buildView();

  void dispose();
}

typedef StoryPlayerFactory = StoryPlayerController Function({required bool controls});
