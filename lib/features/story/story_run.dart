import 'dart:async';

import 'package:flutter/widgets.dart';

import 'story_library.dart';
import 'story_models.dart';
import 'story_session.dart';

/// One story-time sitting: owns the [StorySession] and its clock.
///
/// Every second the app is in the foreground (resumed or merely inactive) the
/// session advances by a second — counting toward the current story only while
/// [isPlaying] — and listeners are notified. In the background (paused, hidden,
/// detached) the clock stands still. Back in front after [storyBackgroundExpiry]
/// or more away (wall clock) the sitting has [expired]. The grid screen owns
/// and disposes it.
class StoryRun extends ChangeNotifier with WidgetsBindingObserver {
  StoryRun({required this.setup, required this.library, DateTime Function()? now})
    : session = StorySession(setup.limit),
      _now = now ?? DateTime.now {
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(tick, (_) => _onTick());
  }

  static const tick = Duration(seconds: 1);

  final StorySetup setup;
  final StoryLibrary library;
  final StorySession session;

  /// Whether the current story's video is really playing (set by the player screen).
  bool isPlaying = false;

  /// [Story.id]s that failed to play in this sitting; hidden from the grid.
  final Set<String> failedThisRun = {};

  final DateTime Function() _now;

  /// When the app last went to the background; null while in front.
  DateTime? _awaySince;
  bool _expired = false;

  /// The app was away for [storyBackgroundExpiry] or more: the sitting is over.
  bool get expired => _expired;

  late final Timer _timer;
  late bool _foreground;
  bool _disposed = false;

  static bool _isForeground(AppLifecycleState? s) =>
      s == null || s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;

  /// The app is in front (resumed or merely inactive): Elsa may speak.
  static bool get appInForeground => _isForeground(WidgetsBinding.instance.lifecycleState);

  /// Stories the child may start now: visible in the chosen topics, not failed,
  /// and allowed by the session (length vs. time left).
  List<Story> get pickable => [
    for (final s in library.visible(topics: setup.topics))
      if (!failedThisRun.contains(s.id) && session.canPick(s)) s,
  ];

  /// Time to say good night: no story is playing and the limit is reached, the
  /// sitting [expired] or nothing is left.
  bool get shouldEnd => session.current == null && (_expired || session.limitReached || pickable.isEmpty);

  void _onTick() {
    if (_disposed || !_foreground) return;
    session.advance(tick, playing: isPlaying);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = _isForeground(state);
    if (!_foreground) {
      _awaySince ??= _now();
      return;
    }
    final since = _awaySince;
    _awaySince = null;
    if (since == null || _expired || _disposed || _now().difference(since) < storyBackgroundExpiry) return;
    _expired = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
