import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/big_button.dart';
import '../../../shared/character_view.dart';
import '../../../shared/ice_background.dart';
import '../balloon/balloon_screen.dart';
import '../letter_game_spec.dart';
import '../trace/trace_screen.dart';

/// 🇻🇳: pick the Vietnamese balloon game (🎈) or tracing game (✏️).
class VietnameseLettersScreen extends ConsumerStatefulWidget {
  const VietnameseLettersScreen({super.key});

  @override
  ConsumerState<VietnameseLettersScreen> createState() => _VietnameseLettersScreenState();
}

class _VietnameseLettersScreenState extends ConsumerState<VietnameseLettersScreen> {
  /// True from the tap until the game is pushed; further taps are ignored so they can't stack a second screen.
  bool _opening = false;

  Future<void> _open(String phraseId, WidgetBuilder builder) async {
    if (_opening) return;
    _opening = true;
    try {
      // Name the game first, but wait at most 3 s so a broken TTS can't stall the menu.
      final cap = Completer<void>();
      final timer = Timer(const Duration(seconds: 3), cap.complete);
      try {
        await Future.any([ref.read(voiceProvider).say(phraseId), cap.future]);
      } finally {
        timer.cancel();
      }
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
    } finally {
      _opening = false;
    }
  }

  /// Set when we pop ourselves (🏠): that says its own phrase.
  bool _leavingByUs = false;

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop && !_leavingByUs) ref.read(voiceProvider).say('go_home');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        body: IceBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      BigButton(
                        emoji: '🏠',
                        size: 64,
                        onTap: () {
                          _leavingByUs = true;
                          ref.read(voiceProvider).say('go_home');
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                const CharacterView(id: 'elsa', size: 120),
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: [
                        BigButton(
                          emoji: '🎈',
                          size: 110,
                          onTap: () => _open('game_vi_balloon', (_) => const BalloonScreen(spec: LetterGameSpec.balloonVi)),
                        ),
                        BigButton(
                          emoji: '✏️',
                          size: 110,
                          onTap: () => _open('game_vi_trace', (_) => const TraceScreen(spec: LetterGameSpec.traceVi)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
