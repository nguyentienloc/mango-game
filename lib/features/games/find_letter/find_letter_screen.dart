import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reward_controller.dart';
import '../../../app/theme.dart';
import '../../../core/content/models.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../../../core/session/session_store.dart';
import '../../../core/time.dart';
import '../../../core/voice/voice_service.dart';
import '../../../shared/big_button.dart';
import '../../../shared/character_view.dart';
import '../../../shared/ice_background.dart';
import '../../reward/reward_screen.dart';
import 'example_card.dart';
import 'falling_flakes.dart';
import 'find_letter_logic.dart';

class FindLetterScreen extends ConsumerStatefulWidget {
  const FindLetterScreen({super.key});

  @override
  ConsumerState<FindLetterScreen> createState() => _FindLetterScreenState();
}

class _FindLetterScreenState extends ConsumerState<FindLetterScreen> {
  FindLetterSession? _session;
  Map<String, ItemStat> _stats = {};
  late final DateTime _startedAt;
  bool _busy = true;
  String? _shaking;
  String? _burst;
  LetterItem? _celebrating;

  VoiceService get _voice => ref.read(voiceProvider);

  /// Set when we pop ourselves (🏠 or error): those say their own phrase.
  bool _leavingByUs = false;

  /// A system back gesture: say go_home, which also cuts whatever is still being spoken.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop && !_leavingByUs) _voice.say('go_home');
  }

  /// Celebrating the last question: the round is fully answered and only
  /// _finish (save session, award snowflakes) is left. Leaving now would
  /// dispose the screen first and the round would earn nothing, so 🏠 and the
  /// back gesture are ignored for these ~1-2 seconds.
  bool get _finishing {
    final session = _session;
    return _celebrating != null && session != null && session.index == session.questions.length - 1;
  }

  @override
  void initState() {
    super.initState();
    _startedAt = ref.read(clockProvider)();
    _guard(_start);
  }

  /// Any unexpected error: Elsa says we go home, and we leave the game.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('FindLetter error: $e\n$st');
      if (!mounted) return;
      _leavingByUs = true;
      await _voice.say('error_home');
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    final random = ref.read(randomProvider);
    _stats = await ref.read(itemStatsStoreProvider).loadByPrefix('letter_en_');
    final questions = buildFindLetterRound(
      letters: ref.read(contentProvider).lettersEn,
      stats: _stats,
      picker: QuestionPicker(random),
      random: random,
    );
    if (!mounted) return;
    setState(() => _session = FindLetterSession(questions));
    await _ask();
  }

  Future<void> _ask() async {
    final q = _session!.current;
    setState(() => _busy = false);
    await _voice.say(q.promptPhraseId, vars: q.promptVars);
  }

  void _onTap(String option) {
    if (_busy) return;
    _guard(() => _handleTap(option));
  }

  Future<void> _handleTap(String option) async {
    final session = _session!;
    final result = session.tap(option);
    if (result == TapResult.wrong) {
      setState(() => _shaking = option);
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shaking = null);
      });
      await _voice.sayGroup('try_again');
      if (session.showHint && mounted) {
        setState(() {});
        await _voice.say(session.current.promptPhraseId, vars: session.current.promptVars);
      }
      return;
    }
    if (result != TapResult.correct) return;

    final q = session.current;
    setState(() {
      _busy = true;
      _burst = option;
      _celebrating = q.item;
    });
    final stat = (_stats[q.key] ?? ItemStat(key: q.key)).apply(session.outcomes.last, ref.read(clockProvider)());
    _stats[q.key] = stat;
    await ref.read(itemStatsStoreProvider).save(stat);
    await Future.wait([
      _voice.say('letter_example', vars: {'letter': q.item.char, 'word': q.item.exampleWord}),
      Future<void>.delayed(const Duration(milliseconds: 800)),
    ]);
    if (!mounted) return;
    session.next();
    setState(() {
      _burst = null;
      _celebrating = null;
    });
    if (session.isFinished) {
      await _finish();
    } else {
      await _ask();
    }
  }

  Future<void> _finish() async {
    final session = _session!;
    final now = ref.read(clockProvider)();
    await ref
        .read(sessionStoreProvider)
        .add(
          SessionRecord(
            date: dayKey(_startedAt),
            game: 'find_letter',
            startedAt: _startedAt,
            durationSec: now.difference(_startedAt).inSeconds,
            correct: session.firstTryCount,
            total: session.questions.length,
          ),
        );
    final outcome = await ref.read(rewardStateProvider.notifier).completeRound(session.firstTryCount);
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => RewardScreen(outcome: outcome)));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null || session.isFinished) {
      return PopScope(
        canPop: _session == null,
        onPopInvokedWithResult: _onPopInvoked,
        child: const Scaffold(
          body: IceBackground(child: Center(child: CircularProgressIndicator())),
        ),
      );
    }
    final q = session.current;
    final shown = q.shownLetter;
    final celebrating = _celebrating;
    return PopScope(
      canPop: !_finishing,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        body: IceBackground(
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
                        if (_finishing) return;
                        _leavingByUs = true;
                        _voice.say('go_home');
                        Navigator.of(context).pop();
                      },
                    ),
                    const Spacer(),
                    Text(
                      '${session.index + 1}/${session.questions.length}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: IceColors.deep),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _voice.say(q.promptPhraseId, vars: q.promptVars),
                      child: const CharacterView(id: 'elsa', size: 110),
                    ),
                    if (shown != null)
                      Text(
                        shown,
                        style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: IceColors.deep),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    FallingFlakes(
                      key: ValueKey(session.index),
                      options: q.options,
                      onTap: _onTap,
                      hint: session.showHint ? q.answer : null,
                      shaking: _shaking,
                      burst: _burst,
                    ),
                    if (celebrating != null) Center(child: ExampleCard(item: celebrating)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
