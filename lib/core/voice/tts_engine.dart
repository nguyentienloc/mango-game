abstract interface class TtsEngine {
  /// Speaks [text] in [lang] ("en" or "vi") at [speed] (1.0 = normal rate);
  /// completes when speech ends or is stopped.
  Future<void> speak(String text, {required String lang, double speed = 1.0});

  Future<void> stop();
}
