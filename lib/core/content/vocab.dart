import 'models.dart';

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Template variables for phrases about one vocabulary word.
Map<String, String> vocabVars(VocabItem w) => {
      'word': w.word,
      'Word': _capitalise(w.word),
      'vi': w.vi,
      'Vi': _capitalise(w.vi),
    };
