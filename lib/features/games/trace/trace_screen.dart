import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reward_controller.dart';
import '../../../app/theme.dart';
import '../../../core/content/models.dart';
import '../../../core/content/strokes.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../../../core/session/session_store.dart';
import '../../../core/time.dart';
import '../../../core/voice/voice_service.dart';
import '../../../core/voice/say_capped.dart';
import '../../../shared/big_button.dart';
import '../../../shared/character_view.dart';
import '../../../shared/ice_background.dart';
import '../../reward/reward_screen.dart';
import '../../../shared/example_card.dart';
import '../letter_game_spec.dart';
import 'sparkle_letter.dart';
import 'trace_logic.dart';
import 'trace_pad.dart';

class TraceScreen extends ConsumerStatefulWidget {
  const TraceScreen({super.key, this.spec = LetterGameSpec.traceEn});

  final LetterGameSpec spec;

  @override
  ConsumerState<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends ConsumerState<TraceScreen> {
  List<LetterItem>? _letters;
  TraceLetterSession? _session;
  Map<String, ItemStat> _stats = {};
  final List<AnswerOutcome> _outcomes = [];
  int _index = 0;
  late final DateTime _startedAt;
  bool _busy = true;
  bool _celebrating = false;
  bool _done = false;

  /// The spec's level when the round started (null: the spec has no levels).
  int? _levelAtStart;

  VoiceService get _voice => ref.read(voiceProvider);
  LetterGameSpec get _spec => widget.spec;

  /// Set when we pop ourselves (🏠 or error): those say their own phrase.
  bool _leavingByUs = false;

  /// A system back gesture: say go_home, which also cuts whatever is still being spoken.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) {
      if (!_leavingByUs) _voice.say('go_home');
    } else if (_spec.popToRootOnExit && !_finishing && !_done) {
      // Games from a chooser take the back gesture themselves, to go all the way home.
      _leavingByUs = true;
      _voice.say('go_home');
      _spec.leave(context);
    }
  }

  bool get _finishing {
    final letters = _letters;
    return _celebrating && letters != null && _index == letters.length - 1;
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
      debugPrint('Trace error: $e\n$st');
      if (!mounted) return;
      _leavingByUs = true;
      await _voice.say('error_home');
      if (mounted) _spec.leave(context);
    }
  }

  Future<void> _start() async {
    final random = ref.read(randomProvider);
    _stats = await ref.read(itemStatsStoreProvider).loadByPrefix('${_spec.keyPrefix}:');
    final all = _spec.letters(ref.read(contentProvider));
    _levelAtStart = _spec.level?.call(_stats);
    final letters = buildTraceRound(
      letters: _spec.available?.call(all, _stats) ?? all,
      stats: _stats,
      picker: QuestionPicker(random),
      keyPrefix: _spec.keyPrefix,
    );
    if (!mounted) return;
    setState(() {
      _letters = letters;
      _index = 0;
      _session = TraceLetterSession(letters[0]);
    });
    await _ask();
  }

  LetterItem get _letter => _letters![_index];

  Future<void> _ask() async {
    setState(() => _busy = false);
    await _sayPrompt();
  }

  Future<void> _sayPrompt() => _voice.say(_spec.promptId, vars: _spec.vars(_letter));

  void _onStrokeDrawn(List<TracePoint> drawn) {
    if (_busy) return;
    _guard(() => _handleStroke(drawn));
  }

  Future<void> _handleStroke(List<TracePoint> drawn) async {
    final session = _session!;
    final ok = session.submit(drawn);
    setState(() {});
    if (!ok) {
      final id = _spec.tryAgainId;
      await (id == null ? _voice.sayGroup('try_again') : _voice.say(id));
      return;
    }
    if (!session.isDone) return;

    final letter = _letter;
    setState(() {
      _busy = true;
      _celebrating = true;
    });
    final outcome = session.outcome;
    _outcomes.add(outcome);
    final key = traceKey(letter, _spec.keyPrefix);
    final stat = (_stats[key] ?? ItemStat(key: key)).apply(outcome, ref.read(clockProvider)());
    _stats[key] = stat;
    await ref.read(itemStatsStoreProvider).save(stat);
    await Future.wait([
      _voice.say(_spec.doneId, vars: _spec.vars(letter)),
      Future<void>.delayed(const Duration(milliseconds: 800)),
    ]);
    if (!mounted) return;
    if (_index == _letters!.length - 1) {
      // Still celebrating, so the traced item stays up while a new level is announced.
      await _sayLevelUp();
      if (!mounted) return;
      setState(() {
        _celebrating = false;
        _done = true;
      });
      await _finish();
    } else {
      setState(() {
        _celebrating = false;
        _index++;
        _session = TraceLetterSession(_letters![_index]);
      });
      await _ask();
    }
  }

  /// Says the spec's level-up line when the stats saved this round opened a new
  /// level; waits at most 3 s so a broken TTS can't hold back the reward.
  Future<void> _sayLevelUp() async {
    final level = _spec.level;
    final before = _levelAtStart;
    if (level == null || before == null || level(_stats) <= before) return;
    await sayCapped(_voice, _spec.levelUpId);
  }

  Future<void> _finish() async {
    final now = ref.read(clockProvider)();
    final firstTry = _outcomes.where((o) => o == AnswerOutcome.firstTry).length;
    await ref.read(sessionStoreProvider).add(SessionRecord(
          date: dayKey(_startedAt),
          game: _spec.sessionGame,
          startedAt: _startedAt,
          durationSec: now.difference(_startedAt).inSeconds,
          correct: firstTry,
          total: _letters!.length,
        ));
    final outcome = await ref.read(rewardStateProvider.notifier).completeRound(firstTry);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => RewardScreen(outcome: outcome, popToRoot: _spec.popToRootOnExit)));
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letters;
    final session = _session;
    if (letters == null || session == null || _done) {
      return PopScope(
        canPop: _letters == null && !_spec.popToRootOnExit,
        onPopInvokedWithResult: _onPopInvoked,
        child: const Scaffold(body: IceBackground(child: Center(child: CircularProgressIndicator()))),
      );
    }
    return PopScope(
      canPop: !_finishing && !_spec.popToRootOnExit,
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
                        _spec.leave(context);
                      },
                    ),
                    const Spacer(),
                    Text(
                      '${_index + 1}/${letters.length}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: IceColors.deep),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (!_busy) _sayPrompt();
                },
                child: const CharacterView(id: 'elsa', size: 90),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    // Keep clear of Android's back-gesture zones so a stroke that
                    // starts near an edge is not stolen by the system.
                    padding: EdgeInsets.fromLTRB(
                      max(16, MediaQuery.systemGestureInsetsOf(context).left + 8),
                      16,
                      max(16, MediaQuery.systemGestureInsetsOf(context).right + 8),
                      16,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TracePad(
                          key: ValueKey(_index),
                          strokes: session.targets,
                          current: session.strokeIndex,
                          onStrokeDrawn: _onStrokeDrawn,
                          enabled: !_busy,
                        ),
                        if (_celebrating)
                          _spec.doneView?.call(_letter) ??
                              (_spec.showExampleCard ? ExampleCard(item: _letter) : SparkleLetter(letter: _letter.char)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
