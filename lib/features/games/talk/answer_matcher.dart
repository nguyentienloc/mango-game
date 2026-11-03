import '../../../core/content/models.dart';

/// Lenient check of what the child said against a [ConversationItem].
class AnswerMatcher {
  const AnswerMatcher._();

  /// Lower-cases, drops apostrophes ("i'm" becomes "im"), turns every other
  /// punctuation into a space and collapses whitespace. Letters of any script
  /// and digits are kept.
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp("['’‘`]"), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .join(' ');

  /// True if any of [transcripts] contains, for at least one accept group of
  /// [item], every word of the group (or one of that word's aliases).
  /// [childName] is also accepted as an answer to the `name` question.
  static bool matches(
    ConversationItem item,
    List<String> transcripts, {
    String? childName,
  }) {
    final heard = [
      for (final t in transcripts)
        if (normalize(t).isNotEmpty) ' ${normalize(t)} ',
    ];
    if (heard.isEmpty) return false;
    final groups = [...item.accept];
    final name = childName == null ? '' : normalize(childName);
    if (item.id == 'name' && name.isNotEmpty) {
      groups.add([name]);
    }
    bool hasWord(String text, String word) {
      final candidates = [word, ...(item.aliases[word] ?? const <String>[])];
      return candidates.any((c) {
        final n = normalize(c);
        return n.isNotEmpty && text.contains(' $n ');
      });
    }

    return heard.any(
      (text) =>
          groups.any((g) => g.isNotEmpty && g.every((w) => hasWord(text, w))),
    );
  }
}
