import '../../../core/content/models.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import 'answer_matcher.dart';

/// Mastery key of a conversation item.
String talkKey(ConversationItem i) => 'conv:${i.id}';

/// Picks [count] different questions for one round, at most [maxNew] unseen
/// ones ([QuestionPicker] only avoids back-to-back repeats).
List<ConversationItem> buildTalkRound({
  required List<ConversationItem> items,
  required Map<String, ItemStat> stats,
  required QuestionPicker picker,
  int count = 5,
  int maxNew = 3,
}) {
  final byKey = {for (final i in items) talkKey(i): i};
  final remaining = byKey.keys.toList();
  final round = <ConversationItem>[];
  var newCount = 0;
  while (round.length < count && remaining.isNotEmpty) {
    final seen = remaining.where(stats.containsKey).toList();
    final pool = newCount >= maxNew && seen.isNotEmpty ? seen : remaining;
    final k = picker.pick(candidates: pool, stats: stats, count: 1).single;
    remaining.remove(k);
    if (!stats.containsKey(k)) newCount++;
    round.add(byKey[k]!);
  }
  return round;
}

/// [normal]: the child answers by voice. [followAlong]: speech recognition is
/// unavailable, so the child repeats after Elsa and taps a button.
enum TalkMode { normal, followAlong }

/// What Elsa should do after one spoken attempt.
class TalkFeedback {
  const TalkFeedback({
    this.correct = false,
    this.tryAgain = false,
    this.sayAfter = false,
    this.moveOn = false,
  });

  /// The answer was understood: praise.
  final bool correct;

  /// First miss: "Hmm, can you say it again?"
  final bool tryAgain;

  /// Second miss: Elsa says the model answer for the child to repeat.
  final bool sayAfter;

  /// Third attempt that still missed: the turn ends WITHOUT praise (a wrong
  /// answer must never sound right), and the round moves on.
  final bool moveOn;
}

/// One question: up to three spoken attempts; after the third the turn ends either way.
class TalkTurn {
  TalkTurn(this.item, {this.mode = TalkMode.normal, this.childName});

  final ConversationItem item;
  final TalkMode mode;

  /// The child's English name, accepted for the `name` question.
  final String? childName;

  int _attempts = 0;
  bool _done = false;
  AnswerOutcome? _outcome;

  int get attempts => _attempts;
  bool get isDone => _done;

  /// Null until the turn is done, and always null in [TalkMode.followAlong]
  /// (those turns do not change mastery).
  AnswerOutcome? get outcome => _outcome;

  /// +1 snowflake: first-try answers, or any confirmed follow-along turn.
  bool get earnsSnowflake =>
      _done &&
      (mode == TalkMode.followAlong || _outcome == AnswerOutcome.firstTry);

  static const _ignored = TalkFeedback();

  /// Judges one spoken attempt ([transcripts]: final result plus alternates).
  TalkFeedback submit(List<String> transcripts) {
    if (_done || mode == TalkMode.followAlong) return _ignored;
    _attempts++;
    final matched = AnswerMatcher.matches(
      item,
      transcripts,
      childName: childName,
    );
    if (_attempts >= 3) {
      _finish(AnswerOutcome.hinted);
      return TalkFeedback(correct: matched, moveOn: !matched);
    }
    if (matched) {
      _finish(_attempts == 1 ? AnswerOutcome.firstTry : AnswerOutcome.retry);
      return const TalkFeedback(correct: true);
    }
    return _attempts == 1
        ? const TalkFeedback(tryAgain: true)
        : const TalkFeedback(sayAfter: true);
  }

  /// Follow-along mode: the child repeated after Elsa and tapped the button.
  /// Returns false if there was nothing to confirm.
  bool confirm() {
    if (_done || mode != TalkMode.followAlong) return false;
    _done = true;
    return true;
  }

  /// Nothing was heard three releases in a row: end the turn (hinted, no
  /// snowflake, no praise) so the child is never stuck. False if already done.
  bool passUnheard() {
    if (_done || mode == TalkMode.followAlong) return false;
    _finish(AnswerOutcome.hinted);
    return true;
  }

  void _finish(AnswerOutcome outcome) {
    _done = true;
    _outcome = outcome;
  }
}
