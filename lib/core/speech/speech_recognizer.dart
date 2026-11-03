/// Listens to the child through the microphone. Kept behind an interface so
/// screens and tests never depend on the platform plugin.
abstract class SpeechRecognizer {
  /// Prepares recognition; the first call asks for the microphone permission.
  /// True when listening is possible (permission granted, a recogniser exists).
  Future<bool> init();

  /// True after a successful [init] and until the recogniser breaks for good
  /// (e.g. the permission is withdrawn).
  bool get available;

  /// Starts one listening session. [onResult] gets every transcript heard so
  /// far (best first, then the alternates); exactly one call per session has
  /// `isFinal` true, and it may carry an empty list when nothing was heard.
  /// Does nothing when not [available].
  Future<void> start({required void Function(List<String> transcripts, bool isFinal) onResult});

  /// Ends the session; the final result follows through [start]'s callback.
  Future<void> stop();

  /// Drops the session without a final result.
  Future<void> cancel();
}
