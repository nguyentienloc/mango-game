import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/screen/screen_awake.dart';
import '../../shared/big_button.dart';
import '../../shared/character_view.dart';
import 'night_sky.dart';
import 'story_models.dart';
import 'story_player.dart';
import 'story_run.dart';

/// Plays one story. The grid has already started it in the session; this screen
/// ends it (finished, left, failed or cut by the time limit) and pops back to the grid.
///
/// The video never takes touches: it sits under IgnorePointer and a transparent
/// shield. In listen mode an opaque night sky with Elsa covers it.
class StoryPlayerScreen extends ConsumerStatefulWidget {
  const StoryPlayerScreen({super.key, required this.run, required this.story});

  final StoryRun run;
  final Story story;

  /// How long Elsa may take to say the story failed before we go back anyway.
  static const errorSayCap = Duration(seconds: 5);

  static const fadeSteps = 10;

  /// Time + finish: a story paused this long after the time is up ends the session.
  static const pausedAfterLimitCap = Duration(seconds: 30);

  @override
  ConsumerState<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends ConsumerState<StoryPlayerScreen> {
  late final StoryPlayerController _player;
  late final ScreenAwake _awake;
  late final StreamSubscription<StoryPlayerState> _sub;
  late final StreamSubscription<Duration> _positionSub;
  late final AppLifecycleListener _lifecycle;
  StoryPlayerState _state = StoryPlayerState.loading;
  Duration _position = Duration.zero;
  Duration? _duration;

  /// The app is in the background: nothing may play.
  bool _hidden = false;

  /// Foreground time the story has stood paused since the time limit was reached.
  Duration _pausedAfterLimit = Duration.zero;

  /// Set once this screen has ended the story; every later exit path is ignored.
  bool _leaving = false;

  StoryRun get _run => widget.run;

  @override
  void initState() {
    super.initState();
    _player = ref.read(storyPlayerFactoryProvider)(controls: false);
    _awake = ref.read(screenAwakeProvider);
    unawaited(_awake.enable());
    _duration = widget.story.duration;
    _sub = _player.states.listen(_onState);
    _positionSub = _player.positions.listen((p) {
      if (mounted && !_leaving) setState(() => _position = p);
    });
    _run.addListener(_onTick);
    // In the background the video pauses; back in front it waits for ▶.
    // (The engine always passes through `hidden` on the way to `paused`.)
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _hidden = true;
        if (!_leaving) unawaited(_player.pause());
      },
      onShow: () => _hidden = false,
    );
    unawaited(_start());
  }

  Future<void> _start() async {
    await _player.load(widget.story.videoId);
    // YouTube remembers the volume between embeds; a faded-out story must not leave the next one silent.
    if (!_leaving) await _player.setVolume(100);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_sub.cancel());
    unawaited(_positionSub.cancel());
    _run.removeListener(_onTick);
    // Only if the route went away without us ending the story. Otherwise the
    // grid may already have started the next story (and its wakelock) during
    // our pop animation, so neither may be touched here.
    if (!_leaving) {
      _run.isPlaying = false;
      if (identical(_run.session.current, widget.story)) _run.session.finishStory(completed: false);
      unawaited(_awake.disable());
    }
    _player.dispose();
    super.dispose();
  }

  void _onState(StoryPlayerState s) {
    if (_leaving || !mounted) return;
    if (s == StoryPlayerState.playing && _hidden) {
      // Started (e.g. finished loading) while the app is in the background.
      unawaited(_player.pause());
      return;
    }
    _run.isPlaying = s == StoryPlayerState.playing;
    if (s == StoryPlayerState.playing && _duration == null) unawaited(_readDuration());
    setState(() => _state = s);
    switch (s) {
      case StoryPlayerState.ended:
        _leave(completed: true);
      case StoryPlayerState.error:
        unawaited(_fail());
      case StoryPlayerState.loading || StoryPlayerState.playing || StoryPlayerState.paused:
        break;
    }
  }

  Future<void> _readDuration() async {
    final d = await _player.duration();
    if (d != null && mounted) setState(() => _duration = d);
  }

  void _onTick() {
    if (_leaving || !mounted) return;
    final session = _run.session;
    final finishMode = switch (_run.setup.limit) {
      TimeLimit(overrun: StoryOverrun.finish) => true,
      _ => false,
    };
    if (finishMode && session.limitReached && _state == StoryPlayerState.paused) {
      _pausedAfterLimit += StoryRun.tick;
    } else {
      _pausedAfterLimit = Duration.zero;
    }
    if (session.mustStopPlayback || _pausedAfterLimit >= StoryPlayerScreen.pausedAfterLimitCap) {
      unawaited(_stopForTime());
    }
  }

  /// Last thing before popping back to the grid. The wakelock goes off now, not
  /// in dispose: the next story may be picked during our pop animation.
  void _pop() {
    unawaited(_awake.disable());
    if (mounted) Navigator.of(context).pop();
  }

  /// Ends the story and goes back to the grid.
  void _leave({required bool completed}) {
    if (_leaving) return;
    _leaving = true;
    _run.isPlaying = false;
    _run.session.finishStory(completed: completed);
    _pop();
  }

  /// 🏠 or the back gesture: back to the grid (the session goes on). The video
  /// stops first so it does not talk over Elsa on the grid.
  void _home() {
    if (_leaving) return;
    unawaited(_player.pause());
    _leave(completed: false);
  }

  Future<void> _fail() async {
    if (_leaving) return;
    _leaving = true;
    _run.isPlaying = false;
    _run.session.abandonStory();
    _run.failedThisRun.add(widget.story.id);
    await ref
        .read(voiceProvider)
        .say('story_error')
        .timeout(StoryPlayerScreen.errorSayCap, onTimeout: () {})
        .catchError((Object e) => debugPrint('Story error voice failed: $e'));
    _pop();
  }

  /// Time is up mid-story: fade the sound out over [storyFadeOut] (if it is
  /// playing), stop, back to the grid (which then says good night).
  Future<void> _stopForTime() async {
    if (_leaving) return;
    _leaving = true;
    if (_state == StoryPlayerState.playing) {
      const steps = StoryPlayerScreen.fadeSteps;
      for (var i = 1; i <= steps; i++) {
        await Future<void>.delayed(storyFadeOut ~/ steps);
        if (!mounted) break;
        await _player.setVolume(100 - i * 100 ~/ steps);
      }
      if (mounted) await _player.pause();
    }
    _run.isPlaying = false;
    _run.session.finishStory(completed: true);
    _pop();
  }

  void _togglePlay() {
    if (_leaving) return;
    if (_state == StoryPlayerState.playing) {
      unawaited(_player.pause());
    } else {
      unawaited(_player.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    final listen = _run.setup.mode == StoryViewMode.listen;
    final playing = _state == StoryPlayerState.playing;
    final d = _duration;
    final progress = d == null || d <= Duration.zero
        ? null
        : (_position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: IgnorePointer(child: _player.buildView()),
              ),
            ),
            // Touches on the video area do nothing.
            const AbsorbPointer(child: SizedBox.expand()),
            if (listen) _ListenCover(key: const Key('story-listen-cover'), title: widget.story.title),
            if (_state == StoryPlayerState.loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (progress != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          // Shows where we are; it cannot be dragged or tapped.
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                key: const Key('story-progress'),
                                value: progress,
                                minHeight: 8,
                                color: NightColors.star,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          BigButton(key: const Key('story-home'), emoji: '🏠', size: 64, onTap: _home),
                          const Spacer(),
                          BigButton(
                            key: const Key('story-playpause'),
                            emoji: playing ? '⏸️' : '▶️',
                            size: 88,
                            enabled: !_leaving,
                            onTap: _togglePlay,
                          ),
                          const Spacer(),
                          const SizedBox(width: 64),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listen mode: the video is hidden under a night sky, Elsa and the story's name.
class _ListenCover extends StatelessWidget {
  const _ListenCover({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return NightSky(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CharacterView(id: 'elsa', size: 160),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NightColors.text, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
