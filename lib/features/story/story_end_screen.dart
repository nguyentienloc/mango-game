import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/character_view.dart';
import 'night_sky.dart';

enum StoryEndReason { finished, offline }

/// Good night (or "no internet"): Elsa says it, then back to the home screen.
/// Nothing to tap; at least [minShow] on screen.
class StoryEndScreen extends ConsumerStatefulWidget {
  const StoryEndScreen({super.key, required this.reason});

  final StoryEndReason reason;

  static const minShow = Duration(seconds: 2);

  /// Never stay here because the voice hangs.
  static const sayCap = Duration(seconds: 10);

  @override
  ConsumerState<StoryEndScreen> createState() => _StoryEndScreenState();
}

class _StoryEndScreenState extends ConsumerState<StoryEndScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final phrase = widget.reason == StoryEndReason.finished ? 'story_bye' : 'story_offline';
    final say = ref.read(voiceProvider).say(phrase).timeout(StoryEndScreen.sayCap, onTimeout: () {}).catchError((Object e) {
      debugPrint('Story end voice failed: $e');
    });
    await Future.wait([say, Future<void>.delayed(StoryEndScreen.minShow)]);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: NightColors.navy,
        body: NightSky(
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CharacterView(id: 'elsa', size: 180),
                  const SizedBox(height: 16),
                  Text(
                    widget.reason == StoryEndReason.finished ? '🌙' : '📡',
                    style: const TextStyle(fontSize: 56),
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
