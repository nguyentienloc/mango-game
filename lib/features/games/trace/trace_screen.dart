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
import '../../../shared/big_button.dart';
import '../../../shared/character_view.dart';
import '../../../shared/ice_background.dart';
import '../../reward/reward_screen.dart';
import '../../../shared/example_card.dart';
import '../letter_game_spec.dart';
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

  VoiceService get _voice => ref.read(voiceProvider);
  LetterGameSpec get _spec => widget.spec;

  /// Set when we pop ourselves (🏠 or error): those say their own phrase.
  bool _leavingByUs = false;

  /// A system back gesture: say go_home, which also cuts whatever is still being spoken.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop && !_leavingByUs) _voice.say('go_home');
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
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    final random = ref.read(randomProvider);
    _stats = await ref.read(itemStatsStoreProvider).loadByPrefix('${_spec.keyPrefix}:');
    final letters = buildTraceRound(
      letters: _spec.letters(ref.read(contentProvider)),
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
      await _voice.sayGroup('try_again');
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
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => RewardScreen(outcome: outcome)));
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letters;
    final session = _session;
    if (letters == null || session == null || _done) {
      return PopScope(
        canPop: _letters == null,
        onPopInvokedWithResult: _onPopInvoked,
        child: const Scaffold(body: IceBackground(child: Center(child: CircularProgressIndicator()))),
      );
    }
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
                          _spec.showExampleCard ? ExampleCard(item: _letter) : _SparkleLetter(letter: _letter.char),
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

/// Shown instead of an example card when a letter is done: the letter itself, big and sparkling.
class _SparkleLetter extends StatelessWidget {
  const _SparkleLetter({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const Key('trace-done-letter'),
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 40)),
              Text(
                letter,
                style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: IceColors.deep),
              ),
              const Text('✨', style: TextStyle(fontSize: 40)),
            ],
          ),
        ),
      ),
    );
  }
}
