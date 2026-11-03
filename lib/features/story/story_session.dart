import 'story_models.dart';

/// Tracks one story-time session: foreground time, which stories counted and
/// whether the parent's limit has been reached. Pure logic, no clocks — the
/// screen feeds it elapsed time with [advance].
class StorySession {
  StorySession(this.limit);

  final StoryLimit limit;

  Duration _elapsed = Duration.zero;
  Duration _currentPlayed = Duration.zero;
  int _listened = 0;
  Story? _current;

  /// Foreground time since the session began, playing or not.
  Duration get elapsed => _elapsed;

  /// Stories that counted as listened.
  int get listened => _listened;

  Story? get current => _current;

  /// Time the current story has actually played.
  Duration get currentPlayed => _currentPlayed;

  int? get storiesLeft => switch (limit) {
        CountLimit(:final stories) => (stories - _listened).clamp(0, stories),
        TimeLimit() => null,
      };

  Duration? get timeLeft => switch (limit) {
        TimeLimit(:final duration) => _elapsed >= duration ? Duration.zero : duration - _elapsed,
        CountLimit() => null,
      };

  /// Adds foreground time. Time only counts toward the current story while it
  /// is [playing].
  void advance(Duration dt, {required bool playing}) {
    _elapsed += dt;
    if (playing) _currentPlayed += dt;
  }

  void startStory(Story s) {
    assert(_current == null, 'a story is already playing');
    _current = s;
    _currentPlayed = Duration.zero;
  }

  /// Ends the current story. It counts if it [completed] or played long enough.
  /// Does nothing when no story is playing (a screen may end it twice).
  void finishStory({required bool completed}) {
    if (_current == null) return;
    if (completed || _currentPlayed >= storyCountsAfter) _listened++;
    _clearCurrent();
  }

  /// Ends the current story after a playback error. Never counts.
  void abandonStory() => _clearCurrent();

  void _clearCurrent() {
    _current = null;
    _currentPlayed = Duration.zero;
  }

  /// Whether [s] may still be started. With a time limit that lets the last
  /// story finish, a story may overrun by at most [storyOverrunCap].
  bool canPick(Story s) => switch (limit) {
        TimeLimit(overrun: StoryOverrun.finish) => s.duration == null || s.duration! <= timeLeft! + storyOverrunCap,
        _ => true,
      };

  bool get limitReached => switch (limit) {
        CountLimit(:final stories) => _listened >= stories,
        TimeLimit(:final duration) => _elapsed >= duration,
      };

  /// Whether playback must be cut now, mid-story.
  bool get mustStopPlayback => switch (limit) {
        CountLimit() => false,
        TimeLimit(:final duration, overrun: StoryOverrun.stopNow) => _elapsed >= duration,
        TimeLimit(:final duration, overrun: StoryOverrun.finish) => _elapsed >= duration + storyOverrunCap,
      };
}
