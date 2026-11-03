import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/story/story_player.dart';
import 'package:xoai_castle/features/story/youtube_state_mapping.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  group('mapYoutubeState', () {
    test('playing, paused and ended map one to one', () {
      expect(mapYoutubeState(PlayerState.playing, YoutubeError.none), StoryPlayerState.playing);
      expect(mapYoutubeState(PlayerState.paused, YoutubeError.none), StoryPlayerState.paused);
      expect(mapYoutubeState(PlayerState.ended, YoutubeError.none), StoryPlayerState.ended);
    });

    test('everything before playing (and buffering) is loading', () {
      for (final s in [PlayerState.unknown, PlayerState.unStarted, PlayerState.buffering, PlayerState.cued]) {
        expect(mapYoutubeState(s, YoutubeError.none), StoryPlayerState.loading, reason: '$s');
      }
    });

    test('any YouTube error is an error, whatever the state (embedding blocked included)', () {
      for (final e in YoutubeError.values.where((e) => e != YoutubeError.none)) {
        for (final s in PlayerState.values) {
          expect(mapYoutubeState(s, e), StoryPlayerState.error, reason: '$s $e');
        }
      }
    });
  });

  group('loadTimeoutRunning', () {
    test('runs while waiting for the first frame of a wanted video', () {
      expect(loadTimeoutRunning(started: false, wanted: true, failed: false), isTrue);
    });

    test('stops once the video has started, after a failure, or while paused (app hidden)', () {
      expect(loadTimeoutRunning(started: true, wanted: true, failed: false), isFalse);
      expect(loadTimeoutRunning(started: false, wanted: true, failed: true), isFalse);
      expect(loadTimeoutRunning(started: false, wanted: false, failed: false), isFalse);
    });

    test('a non-loading state means started', () {
      expect(startsPlayback(StoryPlayerState.loading), isFalse);
      for (final s in [StoryPlayerState.playing, StoryPlayerState.paused, StoryPlayerState.ended]) {
        expect(startsPlayback(s), isTrue);
      }
    });
  });
}
