import 'dart:math';

import 'package:flutter/foundation.dart';

import '../content/models.dart';
import '../profile/names.dart';
import 'clip_library.dart';
import 'clip_player.dart';
import 'tts_engine.dart';
import 'utterance.dart';

/// Single entry point for everything the game says out loud.
class VoiceService {
  VoiceService({
    required TtsEngine tts,
    required Map<String, Phrase> phrases,
    required Names names,
    ClipLibrary clips = ClipLibrary.empty,
    ClipPlayer? player,
    Random? random,
  })  : _tts = tts,
        _clips = clips,
        _player = player,
        _phrases = phrases,
        _names = names,
        _random = random ?? Random();

  final TtsEngine _tts;
  final Map<String, Phrase> _phrases;
  final Names _names;
  final ClipLibrary _clips;
  final ClipPlayer? _player;
  final Random _random;
  int _generation = 0;

  static final _placeholder = RegExp(r'\{(\w+)\}');

  String render(String template, [Map<String, String> vars = const {}]) {
    final all = {'name_en': _names.en, 'name_vi': _names.vi, ...vars};
    return template.replaceAllMapped(_placeholder, (m) => all[m[1]] ?? m[0]!);
  }

  Future<void> say(String phraseId, {Map<String, String> vars = const {}}) {
    final phrase = _phrases[phraseId];
    if (phrase == null) throw ArgumentError.value(phraseId, 'phraseId', 'Không có câu này');
    return _speak(phrase, vars);
  }

  Future<void> sayGroup(String group, {Map<String, String> vars = const {}}) {
    final options = _phrases.values.where((p) => p.group == group).toList();
    if (options.isEmpty) throw ArgumentError.value(group, 'group', 'Không có nhóm câu này');
    return _speak(options[_random.nextInt(options.length)], vars);
  }

  /// What would be spoken for [phraseId], with names and [vars] filled in.
  Utterance utterance(String phraseId, {Map<String, String> vars = const {}}) {
    final phrase = _phrases[phraseId];
    if (phrase == null) throw ArgumentError.value(phraseId, 'phraseId', 'Không có câu này');
    return _build(phrase, vars);
  }

  /// Cuts the current phrase, including any parts not yet spoken.
  Future<void> stop() async {
    _generation++;
    await _player?.stop();
    await _tts.stop();
  }

  Utterance _build(Phrase phrase, Map<String, String> vars) =>
      Utterance([for (final p in phrase.allParts) UtterancePart(p.lang, render(p.text, vars))]);

  Future<void> _speak(Phrase phrase, Map<String, String> vars) => _play(_build(phrase, vars));

  static const _clipTimeout = Duration(seconds: 15);

  Future<void> _play(Utterance u) async {
    final gen = ++_generation;
    await _tts.stop();
    await _player?.stop();
    final asset = _clips.assetFor(u);
    final player = _player;
    if (asset != null && player != null) {
      try {
        await player.play(asset).timeout(_clipTimeout);
        return;
      } catch (e) {
        debugPrint('Clip failed ($asset): $e — using TTS');
        if (gen != _generation) return;
        // A timed-out clip may still be playing; don't talk over it.
        await player.stop().catchError((Object _) {});
      }
    }
    for (final part in u.parts) {
      if (gen != _generation) return;
      await _tts.speak(part.text, lang: part.lang);
    }
  }
}
