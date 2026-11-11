import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/reward_controller.dart';
import '../../core/rewards/reward_rules.dart';
import '../../core/rewards/reward_state.dart';
import '../../core/time.dart';
import '../../core/voice/say_capped.dart';
import '../../core/updater/app_updater.dart';
import '../../shared/big_button.dart';
import '../../shared/castle_view.dart';
import '../../shared/character_view.dart';
import '../../shared/ice_background.dart';
import '../../shared/quest_dots.dart';
import '../../shared/snowflake_counter.dart';
import '../castle/castle_screen.dart';
import '../games/balloon/balloon_screen.dart';
import '../games/compare/compare_screen.dart';
import '../games/talk/talk_screen.dart';
import '../games/trace/trace_chooser_screen.dart';
import '../games/vi_letters/vi_letters_screen.dart';
import '../games/vocab/vocab_screen.dart';
import '../parent/parent_lock_button.dart';
import '../story/math_gate_screen.dart';
import '../story/story_setup_screen.dart';

const _castleWidth = 300.0;

class _GameEntry {
  const _GameEntry(this.emoji, this.phraseId, this.builder);

  final String emoji;
  final String phraseId;
  final WidgetBuilder builder;
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
    _opening = true;
    try {
      // Name the game first so the game's own first prompt doesn't cut it off,
      // but wait at most 3 s so a broken TTS can't stall the menu.
      await sayCapped(voice, game.phraseId);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: game.builder));
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
    final games = <_GameEntry>[
      _GameEntry('🐾', 'game_vocab', (_) => const VocabScreen()),
      _GameEntry('🎈', 'game_balloon', (_) => const BalloonScreen()),
      _GameEntry('✏️', 'game_trace', (_) => const TraceChooserScreen()),
      _GameEntry('🗣️', 'game_talk', (_) => const TalkScreen()),
      _GameEntry('🇻🇳', 'game_vi', (_) => const VietnameseLettersScreen()),
      _GameEntry('⚖️', 'game_compare', (_) => const CompareScreen()),
      _GameEntry('🌙', 'game_story', (_) => MathGateScreen(onPassed: (_) => const StorySetupScreen())),
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
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // Castle (300 wide, 255 tall) and Elsa (150) shrink together
                      // when the area is shorter than the castle, so nothing clips.
                      final scale = c.maxHeight.isFinite ? (c.maxHeight / (_castleWidth * 0.85)).clamp(0.0, 1.0) : 1.0;
                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          GestureDetector(
                            key: const Key('home-castle'),
                            onTap: _openCastle,
                            child: CastleView(level: rewards.castleLevel, width: _castleWidth * scale),
                          ),
                          Positioned(
                            left: 8,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () => ref.read(voiceProvider).say('greet_en'),
                              child: CharacterView(id: 'elsa', size: 150 * scale),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                // 8 dp at the sides so 4 x 76 + 3 x 12 fits a 360 dp phone.
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: LayoutBuilder(
                  builder: (context, c) {
                    // Rows of 4 + 3; 88 dp buttons when 4 of them fit, 76 dp otherwise.
                    final size = c.maxWidth >= 4 * 88 + 3 * 12 ? 88.0 : 76.0;
                    Widget row(Iterable<_GameEntry> items) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final (i, g) in items.indexed) ...[
                              if (i > 0) const SizedBox(width: 12),
                              BigButton(emoji: g.emoji, size: size, onTap: () => _openGame(g)),
                            ],
                          ],
                        );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [row(games.take(4)), const SizedBox(height: 12), row(games.skip(4))],
                    );
                  },
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
