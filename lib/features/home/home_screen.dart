import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/reward_controller.dart';
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
import '../parent/parent_lock_button.dart';

class _GameEntry {
  const _GameEntry(this.emoji, this.phraseId, [this.builder]);

  final String emoji;
  final String phraseId;
  final WidgetBuilder? builder;

  bool get enabled => builder != null;
}

final _games = <_GameEntry>[
  _GameEntry('🎈', 'game_find_letter', (_) => const FindLetterScreen()),
  const _GameEntry('✏️', 'game_trace'),
  const _GameEntry('🗣️', 'game_talk'),
  const _GameEntry('🇻🇳', 'game_vi'),
  const _GameEntry('🐶', 'game_vocab'),
];

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

  Future<void> _openGame(_GameEntry game) async {
    final voice = ref.read(voiceProvider);
    final builder = game.builder;
    if (builder == null) {
      await voice.say(game.phraseId);
      await voice.say('coming_soon');
      return;
    }
    voice.say(game.phraseId);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  void _openCastle() {
    ref.read(voiceProvider).say('game_castle');
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CastleScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final rewards = ref.watch(rewardStateProvider).value ?? const RewardState();
    final today = dayKey(ref.watch(clockProvider)());
    final hasUpdate = ref.watch(updateCheckProvider).value is UpdateAvailable;
    return Scaffold(
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
                  for (final g in _games) BigButton(emoji: g.emoji, enabled: g.enabled, onTap: () => _openGame(g)),
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
    );
  }
}
