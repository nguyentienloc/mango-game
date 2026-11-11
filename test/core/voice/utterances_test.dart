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

  test('balloon covers prompt, correct and both wrong-tap phrases for every letter', () {
    final balloon = keys(UtteranceKind.balloon).toSet();
    expect(balloon, containsAll([
      'vi|Xoài tìm chữ || en|B || vi|nào!',
      'vi|Đúng rồi! || en|B!',
      'vi|Chưa đúng rồi, đây là chữ || en|C',
      'vi|Tìm chữ || en|C || vi|nha!',
    ]));
    // 26 each of prompt, correct, wrong_this (tapped) and wrong_find (target).
    expect(balloon, hasLength(26 * 4));
  });

  test('talk: every question and model answer, names filled in, say-after in two parts', () {
    final talk = keys(UtteranceKind.talk).toSet();
    expect(talk, hasLength(content.conversation.length * 2));
    expect(talk, containsAll([
      "en|What's your name?",
      'en|Hello, An!',
      'en|Goodbye, An!',
      'vi|Con nói theo Elsa nhé: || en|My name is An.',
      "vi|Con nói theo Elsa nhé: || en|I'm fine, thank you!",
    ]));
    final fixed = keys(UtteranceKind.fixed);
    expect(fixed, containsAll(['en|Hmm, can you say it again?', 'vi|Bấm giữ nút micro rồi nói nha!']));
    expect(fixed.any((k) => k.contains('{question}') || k.contains('{model}')), isFalse);
  });

  test('Vietnamese letters: every phrase for all 29 letters, single vi part, names embedded', () {
    final vi = keys(UtteranceKind.viLetters).toSet();
    expect(vi, hasLength(29 * 6));
    expect(vi, containsAll([
      'vi|Xoài tìm chữ bờ nào!',
      'vi|Đúng rồi! Chữ i dài!',
      'vi|Chưa đúng rồi, đây là chữ ớ.',
      'vi|Tìm chữ ca nha!',
      'vi|Mình cùng viết chữ đờ nào!',
      'vi|Giỏi quá! Chữ ơ!',
    ]));
    for (final p in planned.where((p) => p.kind == UtteranceKind.viLetters)) {
      expect(p.utterance.parts, hasLength(1));
    }
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

  test('number tracing: prompt and done for 0..99, the number said in vi then en', () {
    final nums = keys(UtteranceKind.traceNumbers).toList();
    expect(nums, hasLength(100 * 2));
    expect(nums, containsAll([
      'vi|Mình cùng viết số || vi|0 || en|0',
      'vi|Mình cùng viết số || vi|23 || en|23',
      'vi|Giỏi quá! Số || vi|99 || en|99',
    ]));
    final fixed = keys(UtteranceKind.fixed);
    expect(fixed, containsAll(['vi|Mở khóa số mới rồi nè!', 'vi|Chữ cái', 'vi|Chữ số']));
    expect(fixed.any((k) => k.contains('{number}')), isFalse);
    final parts = distinctParts([for (final p in planned.where((p) => p.kind == UtteranceKind.traceNumbers)) p.utterance]);
    // Two fixed openings, 100 vi numbers (shared with the snowflake count) and 100 en numbers.
    expect(parts, hasLength(202));
  });

  test('tone marks: the prompt for each of the 5 tones and the done line for each tone on a, e, o, u, i', () {
    final tones = keys(UtteranceKind.viTones).toList();
    expect(tones, hasLength(5 + 25));
    expect(tones, containsAll([
      'vi|Mình cùng tô dấu sắc nào!',
      'vi|Mình cùng tô dấu nặng nào!',
      'vi|Giỏi quá! a, sắc, á!',
      'vi|Giỏi quá! e, huyền, è!',
      'vi|Giỏi quá! o, hỏi, ỏ!',
      'vi|Giỏi quá! u, ngã, ũ!',
      'vi|Giỏi quá! i, nặng, ị!',
    ]));
    for (final p in planned.where((p) => p.kind == UtteranceKind.viTones)) {
      expect(p.utterance.parts, hasLength(1));
    }
    expect(keys(UtteranceKind.fixed), contains('vi|Tô dấu'));
    expect(keys(UtteranceKind.fixed).any((k) => k.contains('{tone}') || k.contains('{combined}')), isFalse);
  });

  test('compare: every number part for {a} and {b}, pictures 1..10 and numbers 0..99', () {
    final compare = planned.where((p) => p.kind == UtteranceKind.compare).toList();
    // Each phrase runs {a} over the range with {b} fixed and the other way round (one pair shared).
    expect(compare, hasLength(2 * (10 + 9) + 4 * (100 + 99)));
    final parts = {for (final p in compare) for (final part in p.utterance.parts) part.key};
    for (var n = 0; n <= 99; n++) {
      expect(parts, contains('vi|$n'));
    }
    expect(parts, containsAll(['vi|và', 'vi|Chọn dấu nào nhỉ?', 'vi|Đúng rồi!', 'vi|nhiều hơn', 'vi|ít hơn', 'vi|lớn hơn', 'vi|bé hơn', 'vi|bằng']));
    expect(keys(UtteranceKind.compare), containsAll([
      'vi|3 || vi|và || vi|0 || vi|Chọn dấu nào nhỉ?',
      'vi|Đúng rồi! || vi|7 || vi|nhiều hơn || vi|1',
      'vi|Đúng rồi! || vi|0 || vi|bé hơn || vi|99',
    ]));
    expect(keys(UtteranceKind.fixed), containsAll(['vi|So sánh', 'vi|Bên nào nhiều hơn?', 'vi|Bên nào ít hơn?', 'vi|Thử lại nha!', 'vi|Lên cấp rồi! Giỏi quá!']));
    expect(keys(UtteranceKind.fixed).any((k) => k.contains('{a}') || k.contains('{b}')), isFalse);
  });
}
