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

  String render(String template, [Map<String, String> vars = const {}]) => renderTemplate(template, _names, vars);

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

  Utterance _build(Phrase phrase, Map<String, String> vars) => buildUtterance(phrase, _names, vars);

  Future<void> _speak(Phrase phrase, Map<String, String> vars) => _play(_build(phrase, vars));

  /// The longest clip is ~3.5 s; anything slower than this is a stuck player.
  static const _clipTimeout = Duration(seconds: 6);

  /// After this many clip failures/timeouts in a row, clips are skipped for the
  /// rest of the process (TTS only), so a broken player never delays speech again.
  static const _maxClipFailures = 2;
  int _clipFailures = 0;

  /// Silence between two parts of one utterance.
  static const _partGap = Duration(milliseconds: 200);

  Future<void> _play(Utterance u) async {
    final gen = ++_generation;
    await _tts.stop();
    await _player?.stop();
    for (var i = 0; i < u.parts.length; i++) {
      // A stop() or newer say() may have arrived while the engines were being
      // cut, or while the previous part was playing.
      if (gen != _generation) return;
      if (i > 0) {
        await Future<void>.delayed(_partGap);
        if (gen != _generation) return;
      }
      if (!await _playPart(u.parts[i], gen)) return;
    }
  }

  /// Plays one part: its clip when there is one (and clips are not given up),
  /// else (or if the clip fails) the device voice. False when [gen] was
  /// superseded, so the remaining parts must not play.
  Future<bool> _playPart(UtterancePart part, int gen) async {
    final asset = _clips.assetFor(part);
    final player = _player;
    if (asset != null && player != null && _clipFailures < _maxClipFailures) {
      try {
        await player.play(asset).timeout(_clipTimeout);
        _clipFailures = 0;
        return gen == _generation;
      } catch (e) {
        debugPrint('Clip failed ($asset): $e — using TTS');
        // A clip cut short by stop()/a newer phrase is not a player fault.
        if (gen != _generation) return false;
        _clipFailures++;
        // A timed-out clip may still be playing; don't talk over it.
        await player.stop().catchError((Object _) {});
        if (gen != _generation) return false;
      }
    }
    await _tts.speak(part.text, lang: part.lang);
    return gen == _generation;
  }
}
