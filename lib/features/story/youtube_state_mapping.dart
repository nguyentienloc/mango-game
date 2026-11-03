import 'package:youtube_player_iframe/youtube_player_iframe.dart' show PlayerState, YoutubeError;

import 'story_player.dart';

/// YouTube's player state + error → ours. Any error (including 101/150/152,
/// "embedding blocked") wins over the state.
StoryPlayerState mapYoutubeState(PlayerState state, YoutubeError error) {
  if (error != YoutubeError.none) return StoryPlayerState.error;
  return switch (state) {
    PlayerState.playing => StoryPlayerState.playing,
    PlayerState.paused => StoryPlayerState.paused,
    PlayerState.ended => StoryPlayerState.ended,
    // unknown, unStarted, buffering, cued
    PlayerState.unknown || PlayerState.unStarted || PlayerState.buffering || PlayerState.cued =>
      StoryPlayerState.loading,
  };
}

/// Whether [s] shows the video got going (so the load timeout no longer applies).
bool startsPlayback(StoryPlayerState s) => s != StoryPlayerState.loading;

/// The load timeout only runs while we wait for a video we want playing that has
/// not started yet. Paused by us (the app went to the background) it stands still,
/// and starts afresh on play().
bool loadTimeoutRunning({required bool started, required bool wanted, required bool failed}) =>
    !failed && wanted && !started;
