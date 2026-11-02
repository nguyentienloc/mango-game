import '../../core/progress/item_stat.dart';

/// A question with one correct option, shared by the pick-one games.
abstract interface class PickQuestion {
  /// Mastery key, e.g. `word:lion`.
  String get key;

  /// The option value that counts as correct.
  String get answer;
}

enum TapResult { correct, wrong, ignored }

class PickSession<Q extends PickQuestion> {
  PickSession(this.questions);

  final List<Q> questions;
  final List<AnswerOutcome> outcomes = [];
  int _index = 0;
  int _wrong = 0;
  bool _answered = false;

  int get index => _index;
  bool get isFinished => _index >= questions.length;
  Q get current => questions[_index];
  bool get showHint => _wrong >= 2;
  int get firstTryCount => outcomes.where((o) => o == AnswerOutcome.firstTry).length;

  TapResult tap(String option) {
    if (isFinished || _answered) return TapResult.ignored;
    if (option != current.answer) {
      _wrong++;
      return TapResult.wrong;
    }
    _answered = true;
    outcomes.add(switch (_wrong) {
      0 => AnswerOutcome.firstTry,
      1 => AnswerOutcome.retry,
      _ => AnswerOutcome.hinted,
    });
    return TapResult.correct;
  }

  /// Moves to the next question after the correct-answer celebration.
  void next() {
    _index++;
    _wrong = 0;
    _answered = false;
  }
}
