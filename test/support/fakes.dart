import 'dart:async';

import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/progress/progress_resetter.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';
import 'package:xoai_castle/core/speech/speech_recognizer.dart';
import 'package:xoai_castle/core/voice/clip_player.dart';
import 'package:xoai_castle/core/voice/tts_engine.dart';

class FakeTts implements TtsEngine {
  final calls = <String>[];
  final spoken = <({String text, String lang})>[];
  final speeds = <double>[];

  List<String> get texts => [for (final s in spoken) s.text];

  @override
  Future<void> speak(String text, {required String lang, double speed = 1.0}) async {
    calls.add('speak');
    spoken.add((text: text, lang: lang));
    speeds.add(speed);
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

class FakeClipPlayer implements ClipPlayer {
  final played = <String>[];
  final speeds = <double>[];
  int stops = 0;
  Object? failWith;

  @override
  Future<void> play(String assetPath, {double speed = 1.0}) async {
    played.add(assetPath);
    speeds.add(speed);
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  Future<void> stop() async => stops++;
}

/// Like the real engine: speak() stays pending until stop() or release().
class GatedTts extends FakeTts {
  final _pending = <Completer<void>>[];

  @override
  Future<void> speak(String text, {required String lang, double speed = 1.0}) {
    spoken.add((text: text, lang: lang));
    speeds.add(speed);
    final c = Completer<void>();
    _pending.add(c);
    return c.future;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    release();
  }

  void release() {
    for (final c in _pending) {
      if (!c.isCompleted) c.complete();
    }
    _pending.clear();
  }
}

class MemoryItemStatsStore implements ItemStatsStore {
  final stats = <String, ItemStat>{};

  @override
  Future<Map<String, ItemStat>> loadByPrefix(String prefix) async => {
    for (final e in stats.entries)
      if (e.key.startsWith(prefix)) e.key: e.value,
  };

  @override
  Future<void> save(ItemStat stat) async => stats[stat.key] = stat;
}

class FailingItemStatsStore implements ItemStatsStore {
  @override
  Future<Map<String, ItemStat>> loadByPrefix(String prefix) => Future.error(StateError('db broken'));

  @override
  Future<void> save(ItemStat stat) => Future.error(StateError('db broken'));
}

class MemorySessionStore implements SessionStore {
  final records = <SessionRecord>[];

  @override
  Future<void> add(SessionRecord record) async => records.add(record);
}

class MemoryRewardStore implements RewardStore {
  MemoryRewardStore([this.state = const RewardState()]);

  RewardState state;

  @override
  Future<RewardState> load() async => state;

  @override
  Future<void> save(RewardState s) async => state = s;
}

class MemoryProfileStore implements ProfileStore {
  MemoryProfileStore({this.show = false, this.speeds = const VoiceSpeeds()});

  bool show;
  VoiceSpeeds speeds;

  @override
  Future<Names> loadNames(ProfileDefaults defaults) async => const Names(en: 'An', vi: 'Xoài');

  // unused since v0.4.0
  @override
  Future<bool> showFindLetter() async => show;

  @override
  Future<void> setShowFindLetter(bool value) async => show = value;

  @override
  Future<VoiceSpeeds> voiceSpeeds() async => speeds;

  @override
  Future<void> setVoiceSpeeds(VoiceSpeeds value) async => speeds = value.clamped();
}

class FakeProgressResetter implements ProgressResetter {
  int calls = 0;
  Future<void> Function()? onReset;

  @override
  Future<void> resetProgress() async {
    calls++;
    await onReset?.call();
  }
}

/// Scriptable microphone. [scripts] holds what each listening session "hears":
/// the next entry is delivered as the final result when the session is stopped
/// (like releasing the mic button). [emit] pushes a result by hand.
class FakeSpeechRecognizer implements SpeechRecognizer {
  FakeSpeechRecognizer({this.initResult = true, List<List<String>> scripts = const []}) : scripts = [...scripts];

  /// What [init] answers; also what [available] becomes.
  bool initResult;
  final List<List<String>> scripts;
  int inits = 0;
  int starts = 0;
  int stops = 0;
  int cancels = 0;
  bool _available = false;
  bool _listening = false;
  void Function(List<String> transcripts, bool isFinal)? _onResult;

  bool get isListening => _listening;

  @override
  bool get available => _available;

  @override
  Future<bool> init() async {
    inits++;
    _available = initResult;
    return _available;
  }

  @override
  Future<void> start({required void Function(List<String> transcripts, bool isFinal) onResult}) async {
    if (!_available) return;
    starts++;
    _listening = true;
    _onResult = onResult;
  }

  /// Delivers [transcripts] to the running session; a final one ends it.
  void emit(List<String> transcripts, {bool isFinal = true}) {
    final cb = _onResult;
    if (cb == null) return;
    if (isFinal) {
      _listening = false;
      _onResult = null;
    }
    cb(transcripts, isFinal);
  }

  @override
  Future<void> stop() async {
    stops++;
    if (!_listening) return;
    emit(scripts.isEmpty ? const [] : scripts.removeAt(0));
  }

  @override
  Future<void> cancel() async {
    cancels++;
    _listening = false;
    _onResult = null;
  }
}
