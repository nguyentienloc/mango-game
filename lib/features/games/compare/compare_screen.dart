import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reward_controller.dart';
import '../../../app/theme.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/session/session_store.dart';
import '../../../core/time.dart';
import '../../../core/voice/say_capped.dart';
import '../../../core/voice/voice_service.dart';
import '../../../shared/big_button.dart';
import '../../../shared/character_view.dart';
import '../../../shared/ice_background.dart';
import '../../reward/reward_screen.dart';
import '../pick_session.dart';
import 'compare_cards.dart';
import 'compare_logic.dart';

/// ⚖️ So sánh: which side has more/fewer (level 1), then > < = for numbers up to 10 with
/// counting dots, 20 and 99 (levels 2-4). A round of 10; 8 first tries move up a level.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  PickSession<CompareQuestion>? _session;
  int _level = 1;
  late final DateTime _startedAt;

  /// True while Elsa celebrates (or before the first question): taps are ignored.
  bool _busy = true;

  /// The current question has been answered: numbers, sign and sentence are shown.
  bool _revealed = false;
  String? _shaking;

  VoiceService get _voice => ref.read(voiceProvider);

  /// Set when we pop ourselves (🏠 or error): those say their own phrase.
  bool _leavingByUs = false;

  /// A system back gesture: say go_home, which also cuts whatever is still being spoken.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop && !_leavingByUs) _voice.say('go_home');
  }

  /// The last answer is in: the round is being saved, so leaving is blocked.
  bool get _finishing {
    final s = _session;
    return _revealed && s != null && s.index == s.questions.length - 1;
  }

  @override
  void initState() {
    super.initState();
    _startedAt = ref.read(clockProvider)();
    _guard(_start);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('Compare error: $e\n$st');
      if (!mounted) return;
      _leavingByUs = true;
      await _voice.say('error_home');
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    _level = await loadCompareLevel(ref.read(itemStatsStoreProvider));
    final questions = buildCompareRound(level: _level, random: ref.read(randomProvider));
    if (!mounted) return;
    setState(() => _session = PickSession(questions));
    await _ask();
  }

  Future<void> _ask() async {
    setState(() => _busy = false);
    await _sayPrompt();
  }

  Future<void> _sayPrompt() {
    final q = _session!.current;
    return _voice.say(q.promptId, vars: q.promptVars);
  }

  void _onTap(String option) {
    if (_busy) return;
    _guard(() => _handleTap(option));
  }

  Future<void> _handleTap(String option) async {
    final session = _session!;
    final result = session.tap(option);
    if (result == TapResult.wrong) {
      // The second wrong tap also lights up the answer (session.showHint).
      setState(() => _shaking = option);
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shaking = null);
      });
      await _voice.say('compare_try_again');
      return;
    }
    if (result != TapResult.correct) return;

    final q = session.current;
    setState(() {
      _busy = true;
      _revealed = true;
      _shaking = null;
    });
    await Future.wait([
      _voice.say(q.rightId, vars: q.rightVars),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!mounted) return;
    if (session.index == session.questions.length - 1) {
      // The last board stays up while the round is saved and a level-up is announced.
      await _finish();
      return;
    }
    session.next();
    setState(() => _revealed = false);
    await _ask();
  }

  Future<void> _finish() async {
    final session = _session!;
    final now = ref.read(clockProvider)();
    final firstTries = session.firstTryCount;
    await ref.read(sessionStoreProvider).add(SessionRecord(
          date: dayKey(_startedAt),
          game: 'compare',
          startedAt: _startedAt,
          durationSec: now.difference(_startedAt).inSeconds,
          correct: firstTries,
          total: session.questions.length,
        ));
    final next = nextCompareLevel(_level, firstTries);
    if (next != _level) await saveCompareLevel(ref.read(itemStatsStoreProvider), next, now);
    final outcome = await ref.read(rewardStateProvider.notifier).completeRound(firstTries);
    if (!mounted) return;
    if (next != _level) await sayCapped(_voice, 'compare_level_up');
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => RewardScreen(outcome: outcome)));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null || session.isFinished) {
      return PopScope(
        canPop: _session == null,
        onPopInvokedWithResult: _onPopInvoked,
        child: const Scaffold(body: IceBackground(child: Center(child: CircularProgressIndicator()))),
      );
    }
    final q = session.current;
    final firstTry = _revealed && session.outcomes.isNotEmpty && session.outcomes.last == AnswerOutcome.firstTry;
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
                      size: 56,
                      onTap: () {
                        if (_finishing) return;
                        _leavingByUs = true;
                        _voice.say('go_home');
                        Navigator.of(context).pop();
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [BoxShadow(color: IceColors.deep.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Text(
                        '${session.index + 1}/${session.questions.length}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: IceColors.deep),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey(session.index),
                  child: q.isPicture ? _pictureBoard(q, session) : _numberBoard(q, session),
                ),
              ),
              SizedBox(
                height: 124,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      key: const Key('compare-elsa'),
                      onTap: () {
                        if (!_busy) _sayPrompt();
                      },
                      child: const CharacterView(id: 'elsa', size: 120),
                    ),
                    Expanded(
                      child: Center(
                        child: firstTry
                            ? const Text('+1 ❄️', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: IceColors.deep))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  CardMark _mark(String side, CompareQuestion q) {
    if (!_revealed) return CardMark.none;
    return q.answer == side ? CardMark.winner : CardMark.loser;
  }

  Widget _pictureBoard(CompareQuestion q, PickSession<CompareQuestion> session) {
    Widget card(String side, int count) => Expanded(
          child: PictureCard(
            side: side,
            count: count,
            emoji: q.emoji,
            maxCount: max(q.left, q.right),
            onTap: () => _onTap(side),
            mark: _mark(side, q),
            revealed: _revealed,
            hint: !_revealed && session.showHint && q.answer == side,
            shaking: _shaking == side,
          ),
        );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              q.askMore ? 'Bên nào nhiều hơn?' : 'Bên nào ít hơn?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: IceColors.deep),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Center(
              child: SizedBox(
                height: min(300.0, c.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [card('left', q.left), const SizedBox(width: 14), card('right', q.right)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberBoard(CompareQuestion q, PickSession<CompareQuestion> session) {
    final dots = compareShowsDots(q.level);
    final sign = q.sign;
    CardMark mark(String side) {
      if (!_revealed) return CardMark.none;
      final bigger = sign == CompareSign.eq || (side == 'left') == (sign == CompareSign.gt);
      return bigger ? CardMark.winner : CardMark.none;
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NumberCard(side: 'left', value: q.left, dots: dots, mark: mark('left')),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SignBox(sign: _revealed ? sign : null),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 66,
                                child: _revealed ? FittedBox(key: const Key('compare-croc'), child: CompareCroc(sign: sign)) : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        NumberCard(side: 'right', value: q.right, dots: dots, mark: mark('right')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: _revealed
                          ? Text(
                              q.sentence,
                              key: const Key('compare-sentence'),
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: IceColors.deep),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              for (final (i, s) in CompareSign.values.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: SignButton(
                    sign: s,
                    onTap: () => _onTap(s.symbol),
                    hint: !_revealed && session.showHint && q.answer == s.symbol,
                    shaking: _shaking == s.symbol,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
