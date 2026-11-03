import 'dart:async';

import 'package:flutter/material.dart';
// webview.dart re-exports webview_flutter (WebViewWidget, NavigationDelegate).
import 'package:youtube_player_iframe/webview.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'story_player.dart';
import 'youtube_state_mapping.dart';

/// [StoryPlayerController] over the YouTube IFrame player in a WebView.
///
/// A thin layer (it cannot be unit-tested; the decisions live in
/// youtube_state_mapping.dart): YouTube states → [StoryPlayerState], any YouTube
/// error (including 101/150/152 "embedding blocked") → `error`, and a load that
/// has not started playing within [loadTimeout] of being wanted → `error`.
///
/// The WebView is shown with a plain [WebViewWidget] rather than the package's
/// `YoutubePlayer`, which on Android/iOS draws the video in an OverlayPortal above
/// the whole route — the screen's own covers (listen mode, touch shield) could not
/// sit on top of it.
class YoutubeStoryPlayer implements StoryPlayerController {
  YoutubeStoryPlayer({required bool controls})
    : _controller = YoutubePlayerController(
        params: YoutubePlayerParams(
          showControls: controls,
          showFullscreenButton: false,
          strictRelatedVideos: true,
          enableCaption: false,
          enableKeyboard: false,
          showVideoAnnotations: false,
          interfaceLanguage: 'vi',
          pointerEvents: controls ? PointerEvents.auto : PointerEvents.none,
          // Position updates for the progress bar; once a second is plenty.
          videoStateUpdateInterval: 1000,
        ),
      ) {
    // Replaces the package's delegate, which opens the YouTube app / browser for
    // the title, logo and share links. Nothing may leave the app: the page itself
    // is loaded with loadHtmlString and the video iframe is a sub-frame, neither
    // of which asks this delegate.
    unawaited(
      _controller.webViewController.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.prevent,
          onWebResourceError: (e) => debugPrint('Story player web error: ${e.errorCode} ${e.description}'),
        ),
      ),
    );
    unawaited(_controller.webViewController.setBackgroundColor(Colors.black));
    _sub = _controller.listen(_onValue);
    _ready = _controller.initWithParams(params: _controller.params).catchError((Object e) {
      debugPrint('Story player init failed: $e');
      _fail();
    });
  }

  static const loadTimeout = Duration(seconds: 20);

  final YoutubePlayerController _controller;
  final _states = StreamController<StoryPlayerState>.broadcast();
  late final StreamSubscription<YoutubePlayerValue> _sub;
  late final Future<void> _ready;
  Timer? _loadTimer;
  StoryPlayerState? _last;
  bool _failed = false;
  bool _disposed = false;

  /// A video was loaded and not paused by us since.
  bool _wanted = false;

  /// The video got past loading at least once.
  bool _started = false;

  @override
  Stream<StoryPlayerState> get states => _states.stream;

  @override
  Stream<Duration> get positions => _controller.videoStateStream.map((v) => v.position);

  /// Starts or stops the load timeout to match [loadTimeoutRunning].
  void _syncLoadTimer() {
    final run = loadTimeoutRunning(started: _started, wanted: _wanted, failed: _failed);
    if (!run) {
      _loadTimer?.cancel();
      _loadTimer = null;
    } else {
      _loadTimer ??= Timer(loadTimeout, () {
        debugPrint('Story player: no playback within $loadTimeout');
        _fail();
      });
    }
  }

  void _emit(StoryPlayerState s) {
    if (_disposed || s == _last) return;
    _last = s;
    _states.add(s);
  }

  void _fail() {
    if (_failed) return;
    _failed = true;
    _syncLoadTimer();
    _emit(StoryPlayerState.error);
  }

  void _onValue(YoutubePlayerValue v) {
    if (_failed) return;
    final s = mapYoutubeState(v.playerState, v.error);
    if (s == StoryPlayerState.error) {
      debugPrint('Story player error: ${v.error}');
      _fail();
      return;
    }
    if (startsPlayback(s)) _started = true;
    _syncLoadTimer();
    _emit(s);
  }

  /// Runs a player command; a failing one (player gone, page broken) is only logged.
  Future<void> _safely(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Story player $what failed: $e');
    }
  }

  @override
  Future<Duration?> duration() async {
    try {
      final sec = await _controller.duration;
      return sec > 0 ? Duration(milliseconds: (sec * 1000).round()) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> load(String videoId) async {
    _wanted = true;
    _started = false;
    _loadTimer?.cancel();
    _loadTimer = null;
    _syncLoadTimer();
    _emit(StoryPlayerState.loading);
    try {
      await _ready;
      await _controller.loadVideoById(videoId: videoId);
    } catch (e) {
      debugPrint('Story player load failed: $e');
      _fail();
    }
  }

  @override
  Future<void> play() {
    _wanted = true;
    _syncLoadTimer();
    return _safely('play', _controller.playVideo);
  }

  /// Also stops the load timeout: a video paused while the app is hidden must not "fail".
  @override
  Future<void> pause() {
    _wanted = false;
    _syncLoadTimer();
    return _safely('pause', _controller.pauseVideo);
  }

  @override
  Future<void> setVolume(int percent) => _safely('setVolume', () => _controller.setVolume(percent.clamp(0, 100)));

  @override
  Widget buildView() => WebViewWidget(controller: _controller.webViewController);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _loadTimer?.cancel();
    unawaited(_sub.cancel());
    unawaited(_states.close());
    unawaited(_controller.close().catchError((Object e) => debugPrint('Story player close failed: $e')));
  }
}
