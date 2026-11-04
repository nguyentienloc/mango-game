import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reward_controller.dart';
import '../../../app/theme.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../../../core/session/session_store.dart';
import '../../../core/speech/speech_recognizer.dart';
import '../../../core/time.dart';
import '../../../core/voice/utterances.dart';
import '../../../core/voice/voice_service.dart';
import '../../../shared/big_button.dart';
import '../../../shared/character_view.dart';
import '../../../shared/ice_background.dart';
import '../../reward/reward_screen.dart';
import 'mic_button.dart';
import 'talk_logic.dart';

/// Talk with Elsa: she asks, the child holds the mic and answers in English.
/// When speech recognition is unavailable the child just repeats after Elsa
/// and taps a big check button.
class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key});

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  /// Safety net: how long after the mic was released we wait for the final
  /// result before treating it as silence (the recogniser has its own, shorter grace).
  static const _resultTimeout = Duration(seconds: 6);

  late final SpeechRecognizer _speech;
  late final DateTime _startedAt;
  List<TalkTurn>? _turns;
  TalkMode _mode = TalkMode.normal;
  Map<String, ItemStat> _stats = {};
  int _index = 0;
  bool _busy = true;
  bool _celebrating = false;
  bool _listening = false;

  /// The mic was released and the result is not in yet: the mic stays locked.
  bool _waiting = false;

  /// Consecutive releases of this turn with nothing heard.
  int _silent = 0;
  int _listenId = 0;
  Future<void>? _starting;
  Timer? _resultTimer;

  VoiceService get _voice => ref.read(voiceProvider);

  /// Set when we pop ourselves (🏠 or error): those say their own phrase.
  bool _leavingByUs = false;

  /// A system back gesture: say go_home, which also cuts whatever is still being spoken.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop && !_leavingByUs) _voice.say('go_home');
  }

  bool get _isFinished => _turns != null && _index >= _turns!.length;

  bool get _finishing => _celebrating && _turns != null && _index == _turns!.length - 1;

  TalkTurn get _turn => _turns![_index];

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechRecognizerProvider);
    _startedAt = ref.read(clockProvider)();
    _guard(_start);
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _listenId++;
    unawaited(_speech.cancel());
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('Talk error: $e\n$st');
      if (!mounted) return;
      _leavingByUs = true;
      await _voice.say('error_home');
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _initSpeech() async {
    try {
      return await _speech.init();
    } on Object catch (e) {
      debugPrint('Speech init failed: $e');
      return false;
    }
  }

  Future<void> _start() async {
    _stats = await ref.read(itemStatsStoreProvider).loadByPrefix('conv:');
    final items = buildTalkRound(
      items: ref.read(contentProvider).conversation,
      stats: _stats,
      picker: QuestionPicker(ref.read(randomProvider)),
    );
    if (items.isEmpty) throw StateError('No conversation items');
    // The first call asks for the microphone permission.
    final speechOk = await _initSpeech();
    if (!mounted) return;
    _mode = speechOk ? TalkMode.normal : TalkMode.followAlong;
    final childName = ref.read(namesProvider).en;
    setState(() => _turns = [for (final i in items) TalkTurn(i, mode: _mode, childName: childName)]);
    await _ask(hint: _mode == TalkMode.normal);
  }

  /// The model answer is given along with the question: always when following
  /// along, and once the child has missed twice or been silent twice.
  bool get _needsModel => _mode == TalkMode.followAlong || _turn.attempts >= 2 || _silent >= 2;

  Future<void> _sayQuestion() async {
    final names = ref.read(namesProvider);
    await _voice.say('talk_question', vars: talkQuestionVars(_turn.item, names));
    if (_needsModel && mounted) await _saySayAfter();
  }

  Future<void> _saySayAfter() => _voice.say('talk_say_after', vars: talkModelVars(_turn.item, ref.read(namesProvider)));

  Future<void> _ask({bool hint = false}) async {
    setState(() => _busy = true);
    await _sayQuestion();
    if (hint && mounted) await _voice.say('talk_hold_hint');
    if (mounted) setState(() => _busy = false);
  }

  void _reask() {
    if (_busy || _listening || _waiting) return;
    _guard(() async {
      setState(() => _busy = true);
      await _sayQuestion();
      if (mounted) setState(() => _busy = false);
    });
  }

  // --- listening -----------------------------------------------------------

  void _onHoldStart() {
    if (_busy || _listening || _mode != TalkMode.normal) return;
    final id = ++_listenId;
    setState(() => _listening = true);
    _starting = _speech.start(onResult: (transcripts, isFinal) => _onResult(id, transcripts, isFinal)).catchError((Object e) {
      debugPrint('Speech start failed: $e');
      _onResult(id, const [], true);
    });
  }

  void _onHoldEnd() {
    if (!_listening || _waiting) return;
    final id = _listenId;
    setState(() => _waiting = true);
    // Armed first: even a hanging start()/stop() cannot leave the child stuck.
    _resultTimer?.cancel();
    _resultTimer = Timer(_resultTimeout, () => _onResult(id, const [], true));
    _guard(() async {
      await _starting;
      await _speech.stop();
    });
  }

  void _onResult(int id, List<String> transcripts, bool isFinal) {
    if (id != _listenId || !isFinal || !_listening || !mounted) return;
    _resultTimer?.cancel();
    _listenId++;
    setState(() {
      _listening = false;
      _waiting = false;
      _busy = true;
    });
    _guard(() => _score(transcripts));
  }

  /// The recogniser broke for good (e.g. the permission was withdrawn): the
  /// rest of the round is follow-along, like when it was unavailable at the start.
  void _switchToFollowAlong() {
    final names = ref.read(namesProvider);
    _mode = TalkMode.followAlong;
    _silent = 0;
    setState(() {
      for (var i = _index; i < _turns!.length; i++) {
        _turns![i] = TalkTurn(_turns![i].item, mode: _mode, childName: names.en);
      }
    });
  }

  Future<void> _score(List<String> transcripts) async {
    if (!_speech.available) {
      _switchToFollowAlong();
      await _saySayAfter();
      if (mounted) setState(() => _busy = false);
      return;
    }
    final heard = [
      for (final t in transcripts)
        if (t.trim().isNotEmpty) t,
    ];
    final turn = _turn;
    if (heard.isEmpty) {
      // Nothing heard is not a wrong answer: no attempt is used up. But the
      // child must never be stuck, so the third silence passes the turn.
      _silent++;
      if (_silent >= 3 && turn.passUnheard()) {
        await _next(turn, praise: false);
        return;
      }
      if (_silent == 2) {
        await _saySayAfter();
      } else {
        await _voice.say('talk_hold_hint');
      }
      if (mounted) setState(() => _busy = false);
      return;
    }
    _silent = 0;
    final feedback = turn.submit(heard);
    if (feedback.correct || feedback.moveOn) {
      await _next(turn, praise: feedback.correct);
      return;
    }
    if (feedback.sayAfter) {
      await _saySayAfter();
    } else {
      await _voice.say('talk_again');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final turn = _turn;
    if (!turn.confirm()) return;
    setState(() => _busy = true);
    await _next(turn, praise: true);
  }

  /// The turn is over: remember it, praise a right answer (or a confirmed
  /// follow-along) or comfort after a miss, and go to the next question.
  Future<void> _next(TalkTurn turn, {required bool praise}) async {
    setState(() => _celebrating = true);
    final outcome = turn.outcome;
    if (outcome != null) {
      final key = talkKey(turn.item);
      final stat = (_stats[key] ?? ItemStat(key: key)).apply(outcome, ref.read(clockProvider)());
      _stats[key] = stat;
      await ref.read(itemStatsStoreProvider).save(stat);
    }
    await Future.wait([
      praise ? _voice.sayGroup('praise') : _voice.say('talk_move_on'),
      Future<void>.delayed(const Duration(milliseconds: 800)),
    ]);
    if (!mounted) return;
    setState(() {
      _index++;
      _silent = 0;
      _celebrating = false;
    });
    if (_isFinished) {
      await _finish();
    } else {
      await _ask();
    }
  }

  Future<void> _finish() async {
    final turns = _turns!;
    final snowflakes = turns.where((t) => t.earnsSnowflake).length;
    final now = ref.read(clockProvider)();
    await ref
        .read(sessionStoreProvider)
        .add(
          SessionRecord(
            date: dayKey(_startedAt),
            game: 'talk',
            startedAt: _startedAt,
            durationSec: now.difference(_startedAt).inSeconds,
            correct: snowflakes,
            total: turns.length,
          ),
        );
    final outcome = await ref.read(rewardStateProvider.notifier).completeRound(snowflakes);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => RewardScreen(outcome: outcome)));
  }

  @override
  Widget build(BuildContext context) {
    if (_turns == null || _isFinished) {
      return PopScope(
        canPop: _turns == null,
        onPopInvokedWithResult: _onPopInvoked,
        child: const Scaffold(
          body: IceBackground(child: Center(child: CircularProgressIndicator())),
        ),
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
                      '${_index + 1}/${_turns!.length}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: IceColors.deep),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        key: const Key('elsa'),
                        onTap: _reask,
                        child: const CharacterView(id: 'elsa', size: 150),
                      ),
                      SizedBox(
                        height: 48,
                        child: _celebrating && _turn.earnsSnowflake
                            ? const Text(
                                '+1 ❄️',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: IceColors.deep),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (_mode == TalkMode.normal)
                MicButton(
                  key: const Key('mic-button'),
                  enabled: !_busy && !_waiting,
                  waiting: _waiting,
                  onHoldStart: _onHoldStart,
                  onHoldEnd: _onHoldEnd,
                )
              else
                SizedBox(
                  height: MicButton.size * 1.4,
                  child: Center(
                    child: BigButton(
                      key: const Key('confirm-button'),
                      emoji: '✅',
                      size: MicButton.size,
                      enabled: !_busy,
                      onTap: () => _guard(_confirm),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
