import 'dart:math';

import '../content/models.dart';
import '../profile/names.dart';
import 'tts_engine.dart';
import 'utterance.dart';

/// Single entry point for everything the game says out loud.
class VoiceService {
  VoiceService({
    required TtsEngine tts,
    required Map<String, Phrase> phrases,
    required Names names,
    Random? random,
  })  : _tts = tts,
        _phrases = phrases,
        _names = names,
        _random = random ?? Random();

  final TtsEngine _tts;
  final Map<String, Phrase> _phrases;
  final Names _names;
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
  Future<void> stop() {
    _generation++;
    return _tts.stop();
  }

  Utterance _build(Phrase phrase, Map<String, String> vars) =>
      Utterance([for (final p in phrase.allParts) UtterancePart(p.lang, render(p.text, vars))]);

  Future<void> _speak(Phrase phrase, Map<String, String> vars) => _play(_build(phrase, vars));

  Future<void> _play(Utterance u) async {
    final gen = ++_generation;
    await _tts.stop();
    for (final part in u.parts) {
      if (gen != _generation) return;
      await _tts.speak(part.text, lang: part.lang);
    }
  }
}
