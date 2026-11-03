import '../../core/content/models.dart';

/// Everything that differs between the English and the Vietnamese version of the
/// balloon and trace games: which letters, how mastery is keyed, what is said.
class LetterGameSpec {
  const LetterGameSpec({
    required this.letters,
    required this.keyPrefix,
    required this.sessionGame,
    required this.promptId,
    required this.vars,
    this.correctId = '',
    this.wrongThisId = '',
    this.wrongFindId = '',
    this.doneId = '',
    this.showExampleCard = true,
  });

  final List<LetterItem> Function(ContentBundle content) letters;

  /// Mastery keys are `<keyPrefix>:<char>`, e.g. `balloon_en_upper`.
  final String keyPrefix;

  /// The `game` of the session record.
  final String sessionGame;

  /// Phrase ids. Balloon uses prompt, correct, wrongThis and wrongFind; trace uses prompt and done.
  final String promptId;
  final String correctId;
  final String wrongThisId;
  final String wrongFindId;
  final String doneId;

  /// Placeholders for the phrases: [target] is the letter asked, [tapped] the one
  /// the child touched (only for the wrong-balloon phrase).
  final Map<String, String> Function(LetterItem target, {LetterItem? tapped})
  vars;

  /// Trace only: after a letter, pop up its example picture (English) or just show the big letter.
  final bool showExampleCard;

  static const balloonEn = LetterGameSpec(
    letters: _lettersEn,
    keyPrefix: 'balloon_en_upper',
    sessionGame: 'balloon',
    promptId: 'balloon_prompt',
    correctId: 'balloon_correct',
    wrongThisId: 'balloon_wrong_this',
    wrongFindId: 'balloon_wrong_find',
    vars: _varsEn,
  );

  static const balloonVi = LetterGameSpec(
    letters: _lettersVi,
    keyPrefix: 'balloon_vi_upper',
    sessionGame: 'balloon_vi',
    promptId: 'vi_balloon_prompt',
    correctId: 'vi_balloon_correct',
    wrongThisId: 'vi_balloon_wrong_this',
    wrongFindId: 'vi_balloon_wrong_find',
    vars: _varsVi,
  );

  static const traceEn = LetterGameSpec(
    letters: _lettersEn,
    keyPrefix: 'trace_en_upper',
    sessionGame: 'trace',
    promptId: 'trace_prompt',
    doneId: 'letter_example',
    vars: _varsEn,
  );

  static const traceVi = LetterGameSpec(
    letters: _lettersVi,
    keyPrefix: 'trace_vi_upper',
    sessionGame: 'trace_vi',
    promptId: 'vi_trace_prompt',
    doneId: 'vi_trace_done',
    vars: _varsVi,
    showExampleCard: false,
  );
}

List<LetterItem> _lettersEn(ContentBundle c) => c.lettersEn;
List<LetterItem> _lettersVi(ContentBundle c) => c.lettersVi;

Map<String, String> _varsEn(LetterItem target, {LetterItem? tapped}) => {
  'letter': target.char,
  'word': target.exampleWord,
  if (tapped != null) 'tapped': tapped.char,
};

String _spoken(LetterItem l) => l.spoken ?? l.lower;

Map<String, String> _varsVi(LetterItem target, {LetterItem? tapped}) => {
  'spoken': _spoken(target),
  if (tapped != null) 'tapped': _spoken(tapped),
};
