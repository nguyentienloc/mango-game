import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

import '../../../tool/src/voice_gen.dart' show distinctParts;

void main() {
  late ContentBundle content;
  late List<PlannedUtterance> planned;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
    planned = enumerateUtterances(content, const Names(en: 'An', vi: 'Xoài'));
  });

  Iterable<String> keys(UtteranceKind kind) => planned.where((p) => p.kind == kind).map((p) => p.utterance.key);

  test('keys are unique and every placeholder is filled', () {
    final all = planned.map((p) => p.utterance.key).toList();
    expect(all.toSet(), hasLength(all.length));
    for (final p in planned) {
      expect(p.utterance.spokenText, isNot(contains('{')), reason: p.utterance.key);
    }
  });

  test('fixed phrases use the child names', () {
    expect(keys(UtteranceKind.fixed), contains('vi|Chào Xoài! Hôm nay mình chơi gì nào?'));
    expect(keys(UtteranceKind.fixed), contains('en|Hi An! Let\'s play!'));
    expect(keys(UtteranceKind.fixed).any((k) => k.contains('{word}') || k.contains('Find the letter')), isFalse);
  });

  test('every vocabulary word gets prompt, correct and hint utterances', () {
    final vocab = keys(UtteranceKind.vocab).toSet();
    expect(vocab, hasLength(content.vocab.length * 3));
    expect(vocab, containsAll([
      'en|Find the lion!',
      'en|Lion! || vi|Con sư tử!',
      'vi|Con sư tử ở đây nè! || en|Lion!',
    ]));
  });

  test('letters cover upper and lower prompts and small prompts', () {
    final letters = keys(UtteranceKind.letters).toSet();
    expect(letters, containsAll(['en|Find the letter B!', 'en|Find the letter b!', 'en|Find the small b!']));
    expect(letters, hasLength(26 * 3));
  });

  test('tracing needs a prompt and an example for every letter', () {
    final trace = keys(UtteranceKind.trace).toSet();
    expect(trace, containsAll(['en|Let\'s write B!', 'en|B! B is for Ball!']));
    expect(trace, hasLength(26 * 2));
  });

  test('the snowflake count is not a fixed phrase; numbers 0..999 get one utterance each', () {
    expect(keys(UtteranceKind.fixed).any((k) => k.contains('bông tuyết rồi')), isFalse);
    final numbers = keys(UtteranceKind.numbers).toList();
    expect(numbers, hasLength(1000));
    expect(numbers.first, 'vi|Xoài đã kiếm được || vi|0 || vi|bông tuyết rồi, giỏi quá nè!');
    expect(numbers, contains('vi|Xoài đã kiếm được || vi|999 || vi|bông tuyết rồi, giỏi quá nè!'));
  });

  test('only the number part differs between counts', () {
    final parts = distinctParts([for (final p in planned.where((p) => p.kind == UtteranceKind.numbers)) p.utterance]);
    expect(parts, hasLength(1002));
  });
}
