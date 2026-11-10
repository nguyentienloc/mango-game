import 'package:flutter/widgets.dart';

import '../../core/content/models.dart';
import '../../core/progress/item_stat.dart';
import 'trace/number_face.dart';
import 'trace/number_trace.dart';

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
    this.tryAgainId,
    this.showExampleCard = true,
    this.popToRootOnExit = false,
    this.available,
    this.level,
    this.levelUpId = '',
    this.doneView,
  });

  final List<LetterItem> Function(ContentBundle content) letters;

  /// Trace only: the part of [letters] open to the child, given the stats keyed
  /// `<keyPrefix>:` (e.g. numbers of the unlocked levels). Null: all of them.
  final List<LetterItem> Function(List<LetterItem> letters, Map<String, ItemStat> stats)? available;

  /// Trace only: the child's level given the same stats. When a round ends on a
  /// higher level than it started, [levelUpId] is said before the reward. Null: no levels.
  final int Function(Map<String, ItemStat> stats)? level;
  final String levelUpId;

  /// Trace only: shown over the pad once an item is traced. Null: [showExampleCard] decides.
  final Widget Function(LetterItem item)? doneView;

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

  /// Trace only: the phrase said after a wrong stroke. Null: a random one of the `try_again` group.
  final String? tryAgainId;

  /// True when the game was opened from a chooser: 🏠, back and the reward's ✅ go all the way
  /// home instead of back to the chooser.
  final bool popToRootOnExit;

  /// Leaves the game (or the reward screen after it) the way this spec wants.
  void leave(BuildContext context) {
    final nav = Navigator.of(context);
    if (popToRootOnExit) {
      nav.popUntil((r) => r.isFirst);
    } else {
      nav.pop();
    }
  }

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
    popToRootOnExit: true,
  );

  static const traceEn = LetterGameSpec(
    letters: _lettersEn,
    keyPrefix: _traceEnPrefix,
    sessionGame: _traceEnSession,
    promptId: _traceEnPrompt,
    doneId: _traceEnDone,
    vars: _varsEn,
  );

  /// [traceEn] opened from the tracing chooser: leaving goes all the way home.
  static const traceEnFromChooser = LetterGameSpec(
    letters: _lettersEn,
    keyPrefix: _traceEnPrefix,
    sessionGame: _traceEnSession,
    promptId: _traceEnPrompt,
    doneId: _traceEnDone,
    vars: _varsEn,
    popToRootOnExit: true,
  );

  /// Numbers 0–99, opened level by level; each traced number shows its [NumberFace].
  static const traceNumbers = LetterGameSpec(
    letters: _numbers,
    available: unlockedNumbers,
    level: unlockedNumberLevel,
    levelUpId: 'trace_num_unlock',
    keyPrefix: 'trace_num',
    sessionGame: 'trace_num',
    promptId: 'trace_num_prompt',
    doneId: 'trace_num_done',
    vars: _varsNumber,
    doneView: _numberFace,
    popToRootOnExit: true,
  );

  static const traceVi = LetterGameSpec(
    letters: _lettersVi,
    keyPrefix: 'trace_vi_upper',
    sessionGame: 'trace_vi',
    promptId: 'vi_trace_prompt',
    doneId: 'vi_trace_done',
    tryAgainId: 'try_again_vi_1',
    vars: _varsVi,
    showExampleCard: false,
    popToRootOnExit: true,
  );
}

// Shared by traceEn and traceEnFromChooser so the two can't drift apart.
const _traceEnPrefix = 'trace_en_upper';
const _traceEnSession = 'trace';
const _traceEnPrompt = 'trace_prompt';
const _traceEnDone = 'letter_example';

List<LetterItem> _lettersEn(ContentBundle c) => c.lettersEn;
List<LetterItem> _lettersVi(ContentBundle c) => c.lettersVi;
List<LetterItem> _numbers(ContentBundle c) => buildNumberItems(c.digits);

Map<String, String> _varsNumber(LetterItem target, {LetterItem? tapped}) => {'number': target.char};

Widget _numberFace(LetterItem item) => NumberFace(int.parse(item.char));

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
