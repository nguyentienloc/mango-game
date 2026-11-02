import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/reward_controller.dart';
import '../../app/show_find_letter_controller.dart';
import '../../core/rewards/reward_rules.dart';
import '../../core/rewards/reward_state.dart';
import '../../core/time.dart';
import '../../core/updater/app_updater.dart';
import '../../shared/big_button.dart';
import '../../shared/castle_view.dart';
import '../../shared/character_view.dart';
import '../../shared/ice_background.dart';
import '../../shared/quest_dots.dart';
import '../../shared/snowflake_counter.dart';
import '../castle/castle_screen.dart';
import '../games/find_letter/find_letter_screen.dart';
import '../games/trace/trace_screen.dart';
import '../games/vocab/vocab_screen.dart';
import '../parent/parent_lock_button.dart';

class _GameEntry {
  const _GameEntry(this.emoji, this.phraseId, [this.builder]);

  final String emoji;
  final String phraseId;
  final WidgetBuilder? builder;

  bool get enabled => builder != null;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(voiceProvider).say('greet_vi'));
  }

  /// True from the game tap until the game screen has been pushed; further
  /// game/castle taps are ignored so they can't stack a second screen.
  bool _opening = false;

  Future<void> _openGame(_GameEntry game) async {
    if (_opening) return;
    final voice = ref.read(voiceProvider);
    final builder = game.builder;
    if (builder == null) {
      await voice.say(game.phraseId);
      await voice.say('coming_soon');
      return;
    }
    _opening = true;
    try {
      // Name the game first so the game's own first prompt doesn't cut it off,
      // but wait at most 3 s so a broken TTS can't stall the menu.
      final cap = Completer<void>();
      final timer = Timer(const Duration(seconds: 3), cap.complete);
      try {
        await Future.any([voice.say(game.phraseId), cap.future]);
      } finally {
        timer.cancel();
      }
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
    } finally {
      _opening = false;
    }
  }

  void _openCastle() {
    if (_opening) return;
    ref.read(voiceProvider).say('game_castle');
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CastleScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final rewards = ref.watch(rewardStateProvider).value ?? const RewardState();
    final today = dayKey(ref.watch(clockProvider)());
    final hasUpdate = ref.watch(updateCheckProvider).value is UpdateAvailable;
    final showFindLetter = ref.watch(showFindLetterProvider).value ?? false;
    final games = <_GameEntry>[
      _GameEntry('🐾', 'game_vocab', (_) => const VocabScreen()),
      if (showFindLetter) _GameEntry('🎈', 'game_find_letter', (_) => const FindLetterScreen()),
      _GameEntry('✏️', 'game_trace', (_) => const TraceScreen()),
      const _GameEntry('🗣️', 'game_talk'),
      const _GameEntry('🇻🇳', 'game_vi'),
    ];
    // Home is the root: the back gesture must not exit the app by accident.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: IceBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SnowflakeCounter(count: rewards.snowflakesTotal),
                    QuestDots(done: roundsToday(rewards, today)),
                  ],
                ),
              ),
              Expanded(
                // Full width so Elsa sits at the screen edge, not on top of the castle.
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      GestureDetector(
                        key: const Key('home-castle'),
                        onTap: _openCastle,
                        child: CastleView(level: rewards.castleLevel, width: 300),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => ref.read(voiceProvider).say('greet_en'),
                          child: const CharacterView(id: 'elsa', size: 150),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final g in games) BigButton(emoji: g.emoji, enabled: g.enabled, onTap: () => _openGame(g)),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ParentLockButton(hasUpdate: hasUpdate),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
