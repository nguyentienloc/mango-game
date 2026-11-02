abstract interface class TtsEngine {
  /// Speaks [text] in [lang] ("en" or "vi"); completes when speech ends or is stopped.
  Future<void> speak(String text, {required String lang});

  Future<void> stop();
}
