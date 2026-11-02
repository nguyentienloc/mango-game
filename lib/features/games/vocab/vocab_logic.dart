import 'dart:math';

import '../../../core/content/models.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../pick_session.dart';

class VocabQuestion implements PickQuestion {
  const VocabQuestion({required this.item, required this.options});

  final VocabItem item;

  /// Pictures on the four cards, answer included, in display order.
  final List<VocabItem> options;

  @override
  String get key => 'word:${item.id}';

  @override
  String get answer => item.id;
}

List<VocabQuestion> buildVocabRound({
  required List<VocabItem> words,
  required Map<String, ItemStat> stats,
  required QuestionPicker picker,
  required Random random,
  int count = 8,
  int optionCount = 4,
  int maxNew = 3,
}) {
  final byKey = {for (final w in words) 'word:${w.id}': w};
  final keys = picker.pick(candidates: byKey.keys.toList(), stats: stats, count: count, maxNew: maxNew);
  return [
    for (final k in keys)
      () {
        final item = byKey[k]!;
        final others = words.where((w) => w.id != item.id).toList()..shuffle(random);
        final options = [item, ...others.take(optionCount - 1)]..shuffle(random);
        return VocabQuestion(item: item, options: options);
      }(),
  ];
}
