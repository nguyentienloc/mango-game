import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reward_controller.dart';
import '../../../app/theme.dart';
import '../../../core/content/vocab.dart';
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
import 'picture_grid.dart';
import 'vocab_logic.dart';

class VocabScreen extends ConsumerStatefulWidget {
  const VocabScreen({super.key});

  @override
  ConsumerState<VocabScreen> createState() => _VocabScreenState();
}

class _VocabScreenState extends ConsumerState<VocabScreen> {
  PickSession<VocabQuestion>? _session;
  Map<String, ItemStat> _stats = {};
  late final DateTime _startedAt;
  bool _busy = true;
  String? _shaking;
  String? _burst;

  VoiceService get _voice => ref.read(voiceProvider);

  /// Set when we pop ourselves (🏠 or error): those say their own phrase.
  bool _leavingByUs = false;

  /// A system back gesture: say go_home, which also cuts whatever is still being spoken.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop && !_leavingByUs) _voice.say('go_home');
  }

  bool get _finishing {
    final s = _session;
    return _burst != null && s != null && s.index == s.questions.length - 1;
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
      debugPrint('Vocab error: $e\n$st');
      if (!mounted) return;
      _leavingByUs = true;
      await _voice.say('error_home');
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    final random = ref.read(randomProvider);
    _stats = await ref.read(itemStatsStoreProvider).loadByPrefix('word:');
    final questions = buildVocabRound(
      words: ref.read(contentProvider).vocab,
      stats: _stats,
      picker: QuestionPicker(random),
      random: random,
    );
    if (!mounted) return;
    setState(() => _session = PickSession(questions));
    await _ask();
  }

  Map<String, String> get _vars => vocabVars(_session!.current.item);

  Future<void> _ask() async {
    setState(() => _busy = false);
    await _voice.say('vocab_prompt', vars: _vars);
  }

  void _onTap(String id) {
    if (_busy) return;
    _guard(() => _handleTap(id));
  }

  Future<void> _handleTap(String id) async {
    final session = _session!;
    final result = session.tap(id);
    if (result == TapResult.wrong) {
      setState(() => _shaking = id);
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shaking = null);
      });
      if (session.showHint) {
        setState(() {});
        await _voice.say('vocab_hint', vars: _vars);
      } else {
        await _voice.sayGroup('try_again');
      }
      return;
    }
    if (result != TapResult.correct) return;

    final q = session.current;
    setState(() {
      _busy = true;
      _burst = id;
    });
    final stat = (_stats[q.key] ?? ItemStat(key: q.key)).apply(session.outcomes.last, ref.read(clockProvider)());
    _stats[q.key] = stat;
    await ref.read(itemStatsStoreProvider).save(stat);
    await Future.wait([
      _voice.say('vocab_correct', vars: _vars),
      Future<void>.delayed(const Duration(milliseconds: 800)),
    ]);
    if (!mounted) return;
    session.next();
    setState(() => _burst = null);
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
          game: 'vocab',
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
                  if (!_busy) _voice.say('vocab_prompt', vars: _vars);
                },
                child: const CharacterView(id: 'elsa', size: 110),
              ),
              Expanded(
                child: PictureGrid(
                  key: ValueKey(session.index),
                  options: q.options,
                  onTap: _onTap,
                  hint: session.showHint ? q.answer : null,
                  shaking: _shaking,
                  burst: _burst,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
