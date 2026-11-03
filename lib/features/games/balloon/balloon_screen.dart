import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reward_controller.dart';
import '../../../app/theme.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../../../core/session/session_store.dart';
import '../../../core/time.dart';
import '../../../core/voice/voice_service.dart';
import '../../../shared/big_button.dart';
import '../../../shared/character_view.dart';
import '../../../shared/ice_background.dart';
import '../../reward/reward_screen.dart';
import '../pick_session.dart';
import 'balloon_field.dart';
import 'balloon_logic.dart';

class BalloonScreen extends ConsumerStatefulWidget {
  const BalloonScreen({super.key});

  @override
  ConsumerState<BalloonScreen> createState() => _BalloonScreenState();
}

class _BalloonScreenState extends ConsumerState<BalloonScreen> {
  PickSession<BalloonQuestion>? _session;
  Map<String, ItemStat> _stats = {};
  late final DateTime _startedAt;

  /// True while Elsa is speaking about a pop (so sentences never overlap) and
  /// until the first prompt.
  bool _busy = true;
  bool _celebrating = false;

  VoiceService get _voice => ref.read(voiceProvider);

  /// Set when we pop ourselves (🏠 or error): those say their own phrase.
  bool _leavingByUs = false;

  /// A system back gesture: say go_home, which also cuts whatever is still being spoken.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop && !_leavingByUs) _voice.say('go_home');
  }

  bool get _finishing {
    final s = _session;
    return _celebrating && s != null && s.index == s.questions.length - 1;
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
      debugPrint('Balloon error: $e\n$st');
      if (!mounted) return;
      _leavingByUs = true;
      await _voice.say('error_home');
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    final random = ref.read(randomProvider);
    _stats = await ref.read(itemStatsStoreProvider).loadByPrefix('balloon_en_upper:');
    final round = buildBalloonRound(
      letters: ref.read(contentProvider).lettersEn,
      stats: _stats,
      picker: QuestionPicker(random),
    );
    if (!mounted) return;
    setState(() => _session = PickSession([for (final l in round) BalloonQuestion(l)]));
    await _ask();
  }

  Future<void> _ask() async {
    setState(() => _busy = false);
    await _voice.say('balloon_prompt', vars: {'letter': _session!.current.answer});
  }

  /// The field asks before it pops a balloon. Locks synchronously, so a second touch in
  /// the same frame is refused (and its balloon stays) instead of being popped unseen.
  bool _onPop(String letter) {
    if (_busy) return false;
    _busy = true;
    _guard(() => _handlePop(letter));
    return true;
  }

  Future<void> _handlePop(String letter) async {
    final session = _session!;
    final result = session.tap(letter);
    if (result == TapResult.wrong) {
      // Locked only while the tapped letter is named; "find X" plays on while the child can
      // already tap again (a new tap's speech cuts it).
      await _voice.say('balloon_wrong_this', vars: {'tapped': letter});
      if (!mounted) return;
      setState(() => _busy = false);
      unawaited(_guard(() => _voice.say('balloon_wrong_find', vars: {'letter': session.current.answer})));
      return;
    }
    if (result != TapResult.correct) {
      if (mounted && !_celebrating) setState(() => _busy = false);
      return;
    }

    final q = session.current;
    setState(() {
      _busy = true;
      _celebrating = true;
    });
    final stat = (_stats[q.key] ?? ItemStat(key: q.key)).apply(session.outcomes.last, ref.read(clockProvider)());
    _stats[q.key] = stat;
    // The stats write does not delay Elsa's cheer: both run together.
    await Future.wait([
      ref.read(itemStatsStoreProvider).save(stat),
      _voice.say('balloon_correct', vars: {'letter': q.answer}),
      Future<void>.delayed(const Duration(milliseconds: 800)),
    ]);
    if (!mounted) return;
    session.next();
    setState(() => _celebrating = false);
    if (session.isFinished) {
      await _finish();
    } else {
      await _ask();
    }
  }

  Future<void> _finish() async {
    final session = _session!;
    final now = ref.read(clockProvider)();
    await ref.read(sessionStoreProvider).add(SessionRecord(
          date: dayKey(_startedAt),
          game: 'balloon',
          startedAt: _startedAt,
          durationSec: now.difference(_startedAt).inSeconds,
          correct: session.firstTryCount,
          total: session.questions.length,
        ));
    final outcome = await ref.read(rewardStateProvider.notifier).completeRound(session.firstTryCount);
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
              GestureDetector(
                onTap: () {
                  if (!_busy) _voice.say('balloon_prompt', vars: {'letter': q.answer});
                },
                child: const CharacterView(id: 'elsa', size: 90),
              ),
              Expanded(
                child: BalloonField(
                  target: q.answer,
                  onPop: _onPop,
                  hint: session.showHint ? q.answer : null,
                  random: ref.read(randomProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
