import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/voice/voice_service.dart';
import '../../shared/big_button.dart';
import 'night_sky.dart';
import 'story_end_screen.dart';
import 'story_models.dart';
import 'story_player_screen.dart';
import 'story_run.dart';

/// The child picks a story. Owns (and disposes) the [StoryRun].
///
/// On entry it checks the internet (offline → "no internet" end screen); the
/// session ends — good-night screen — when the limit is reached or nothing is
/// left to pick (checked on entry, on return from a story and every tick), or
/// with 🏠 / back.
class StoryGridScreen extends ConsumerStatefulWidget {
  const StoryGridScreen({super.key, required this.run});

  final StoryRun run;

  @override
  ConsumerState<StoryGridScreen> createState() => _StoryGridScreenState();
}

class _StoryGridScreenState extends ConsumerState<StoryGridScreen> {
  /// The internet check passed: the grid is shown and can be tapped.
  bool _ready = false;
  bool _inPlayer = false;
  bool _ending = false;

  StoryRun get _run => widget.run;

  VoiceService get _voice => ref.read(voiceProvider);

  @override
  void initState() {
    super.initState();
    _run.addListener(_onTick);
    unawaited(_start());
  }

  @override
  void dispose() {
    _run.removeListener(_onTick);
    _run.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final online = await ref.read(connectivityProbeProvider).online();
    if (!mounted || _ending) return;
    if (!online) {
      _end(StoryEndReason.offline);
      return;
    }
    setState(() => _ready = true);
    if (!_endIfDone()) _askToPick();
  }

  /// Elsa asks for a story — not while the app is in the background.
  void _askToPick() {
    if (StoryRun.appInForeground) unawaited(_voice.say('story_pick'));
  }

  void _onTick() {
    if (!mounted || !_ready || _inPlayer || _ending) return;
    _endIfDone();
  }

  bool _endIfDone() {
    if (!_run.shouldEnd) return false;
    _end(StoryEndReason.finished);
    return true;
  }

  void _end(StoryEndReason reason) {
    if (_ending) return;
    _ending = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => StoryEndScreen(reason: reason)));
  }

  /// 🏠 or back: the session is over.
  void _home() {
    if (_inPlayer) return;
    _end(StoryEndReason.finished);
  }

  Future<void> _open(Story s) async {
    if (!_ready || _inPlayer || _ending) return;
    _inPlayer = true;
    unawaited(_voice.stop());
    _run.session.startStory(s);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => StoryPlayerScreen(run: _run, story: s)));
    if (!mounted) return;
    _inPlayer = false;
    if (_endIfDone()) return;
    setState(() {});
    // A story that failed already had Elsa ask for another one.
    if (!_run.failedThisRun.contains(s.id)) _askToPick();
  }

  String _remaining() {
    final session = _run.session;
    return switch (_run.setup.limit) {
      CountLimit() => 'Còn ${session.storiesLeft} truyện',
      TimeLimit() => 'Còn ${(session.timeLeft!.inSeconds / 60).ceil()} phút',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: Scaffold(
        backgroundColor: NightColors.navy,
        body: NightSky(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _run,
              builder: (context, _) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        BigButton(key: const Key('story-grid-home'), emoji: '🏠', size: 64, onTap: _home),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(fit: BoxFit.scaleDown, child: _RemainingPill(text: _remaining())),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _ready
                        ? _Grid(stories: _run.pickable, onTap: _open)
                        : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemainingPill extends StatelessWidget {
  const _RemainingPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            text,
            key: const Key('story-remaining'),
            style: const TextStyle(color: NightColors.text, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.stories, required this.onTap});

  static const _pad = 12.0;
  static const _gap = 12.0;

  /// Room under the thumbnail for a two-line title.
  static const _titleHeight = 56.0;

  final List<Story> stories;
  final void Function(Story) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 2 * _pad - _gap) / 2;
        return GridView.builder(
          padding: const EdgeInsets.all(_pad),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: _gap,
            crossAxisSpacing: _gap,
            mainAxisExtent: tileWidth * 9 / 16 + _titleHeight,
          ),
          itemCount: stories.length,
          itemBuilder: (context, i) => _StoryCard(story: stories[i], onTap: () => onTap(stories[i])),
        );
      },
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  static const _topicColors = {
    StoryTopic.fairyVi: Color(0xFFFFCC80),
    StoryTopic.princess: Color(0xFFB3E5FC),
    StoryTopic.english: Color(0xFFC5E1A5),
    StoryTopic.other: Color(0xFFE1BEE7),
  };

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: _topicColors[story.topic]!,
      child: const Center(child: Text('📖', style: TextStyle(fontSize: 36))),
    );
    return GestureDetector(
      key: Key('story-${story.videoId}'),
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                story.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : fallback,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  story.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NightColors.navy, fontSize: 15, fontWeight: FontWeight.bold, height: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
