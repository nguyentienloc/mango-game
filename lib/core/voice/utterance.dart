import '../content/models.dart';
import '../profile/names.dart';

class UtterancePart {
  const UtterancePart(this.lang, this.text);

  final String lang;
  final String text;

  /// Lookup key of this part's pre-generated clip, e.g. `en|Lion!`.
  String get key => '$lang|$text';
}

/// Everything spoken for one phrase: one or more parts, each in one language.
class Utterance {
  const Utterance(this.parts);

  final List<UtterancePart> parts;

  /// Stable lookup key for pre-generated audio, e.g. `en|Lion! || vi|Con sư tử!`.
  String get key => parts.map((p) => p.key).join(' || ');

  String get spokenText => parts.map((p) => p.text).join(' ');
}

final _placeholder = RegExp(r'\{(\w+)\}');

/// Fills `{name_en}`, `{name_vi}` and [vars] into [template]; unknown placeholders stay.
String renderTemplate(String template, Names names, Map<String, String> vars) {
  final all = {'name_en': names.en, 'name_vi': names.vi, ...vars};
  return template.replaceAllMapped(_placeholder, (m) => all[m[1]] ?? m[0]!);
}

/// The ONE place a phrase becomes what is spoken. Both the runtime (VoiceService)
/// and the clip generator (enumerateUtterances) use it, so their keys always match.
Utterance buildUtterance(Phrase phrase, Names names, Map<String, String> vars) =>
    Utterance([for (final p in phrase.allParts) UtterancePart(p.lang, renderTemplate(p.text, names, vars))]);
