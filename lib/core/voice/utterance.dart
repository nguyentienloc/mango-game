class UtterancePart {
  const UtterancePart(this.lang, this.text);

  final String lang;
  final String text;
}

/// Everything spoken for one phrase: one or more parts, each in one language.
class Utterance {
  const Utterance(this.parts);

  final List<UtterancePart> parts;

  /// Stable lookup key for pre-generated audio, e.g. `en|Lion! || vi|Con sư tử!`.
  String get key => parts.map((p) => '${p.lang}|${p.text}').join(' || ');

  String get spokenText => parts.map((p) => p.text).join(' ');
}
