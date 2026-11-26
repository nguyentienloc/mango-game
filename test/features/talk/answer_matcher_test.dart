import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/talk/answer_matcher.dart';

void main() {
  late Map<String, ConversationItem> items;

  setUpAll(() async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    items = {for (final i in bundle.conversation) i.id: i};
  });

  bool ok(String id, List<String> transcripts, {String? childName}) =>
      AnswerMatcher.matches(items[id]!, transcripts, childName: childName);

  test('the shipped pack has the 18 questions in order', () {
    expect(items.keys, [
      'name', 'age', 'merry_christmas', 'who_brings_gifts', 'christmas_wish', 'like_snow', 'snowman_color',
      'what_tree', 'what_gift', 'how_many_stars', 'good_morning', 'good_night', 'cold_today', 'sing_song',
      'thank_you', 'where_live', 'love_mommy', 'favorite_animal',
    ]);
    expect(items['name']!.question, "What's your name?");
    expect(items['merry_christmas']!.question, 'Merry Christmas, {name_en}!');
    expect(items['name']!.model, 'My name is {name_en}.');
    expect(items['what_tree']!.question, items['what_gift']!.question);
    expect(items['favorite_animal']!.accept, hasLength(17));
  });

  test('every model answer is accepted', () {
    for (final i in items.values) {
      final model = i.model.replaceAll('{name_en}', 'An');
      expect(AnswerMatcher.matches(i, [model]), isTrue, reason: i.id);
    }
  });

  test('no question takes an unrelated answer', () {
    for (final i in items.values) {
      expect(ok(i.id, ['banana']), isFalse, reason: i.id);
      expect(ok(i.id, ['I like apples']), isFalse, reason: i.id);
    }
  });

  group('name', () {
    test('accepts the name, with common mishearings', () {
      expect(ok('name', ['my name is an']), isTrue);
      expect(ok('name', ['my name is and']), isTrue);
      expect(ok('name', ['Ann']), isTrue);
      expect(ok('name', ['Anne']), isTrue);
      expect(ok('name', ['swine']), isTrue);
      expect(ok('name', ['xoài']), isTrue);
    });
    test('rejects unrelated speech', () {
      expect(ok('name', ['banana']), isFalse);
      expect(ok('name', ['my name is']), isFalse);
    });
    test('common words that sound like An only count after "my name is"', () {
      expect(ok('name', ['cats and dogs']), isFalse);
      expect(ok('name', ['and']), isFalse);
      expect(ok('name', ["I'm en"]), isFalse);
      expect(ok('name', ['my name is un']), isFalse);
      expect(ok('name', ['my name is banana']), isFalse);
    });
    test('accepts a custom child name when given', () {
      expect(ok('name', ['my name is Lily']), isFalse);
      expect(ok('name', ['my name is Lily'], childName: 'Lily'), isTrue);
      expect(ok('name', ['banana'], childName: 'Lily'), isFalse);
    });
  });

  group('age', () {
    test('accepts five/four in several forms', () {
      expect(ok('age', ["I'm five"]), isTrue);
      expect(ok('age', ['I am 5']), isTrue);
      expect(ok('age', ['four']), isTrue);
      expect(ok('age', ['I am fourth']), isTrue);
    });
    test('does not take look-alike common words for the number', () {
      expect(ok('age', ['fine']), isFalse);
      expect(ok('age', ["I'm fine thank you"]), isFalse);
      expect(ok('age', ['this is for you']), isFalse);
      expect(ok('age', ['I am six']), isFalse);
    });
    test('rejects other answers', () {
      expect(ok('age', ['six']), isFalse);
      expect(ok('age', ['6']), isFalse);
    });
    test('does not match digits inside other numbers', () {
      expect(ok('age', ['45']), isFalse);
    });
  });

  test('merry christmas and santa', () {
    expect(ok('merry_christmas', ['Merry Christmas Elsa']), isTrue);
    expect(ok('merry_christmas', ['merry xmas']), isTrue);
    expect(ok('merry_christmas', ['merry']), isTrue);
    expect(ok('merry_christmas', ['Mary']), isTrue, reason: 'the recogniser often hears "merry" as "Mary"');
    expect(ok('merry_christmas', ['hello']), isFalse);
    expect(ok('who_brings_gifts', ['Santa']), isTrue);
    expect(ok('who_brings_gifts', ["Santa's sleigh"]), isTrue);
    expect(ok('who_brings_gifts', ['father christmas']), isTrue);
    expect(ok('who_brings_gifts', ['christmas']), isFalse);
    expect(ok('who_brings_gifts', ['mommy']), isFalse);
  });

  test('christmas wish accepts toys and presents', () {
    for (final toy in [
      'a teddy bear', 'a ball', 'a kite', 'a yo-yo', 'a yoyo', 'a robot', 'balloons', 'a puzzle', 'a drum', 'a guitar',
      'a skateboard', 'crayons', 'a trumpet', 'a doll', 'a car', 'a bike', 'a bicycle', 'a gift', 'presents',
    ]) {
      expect(ok('christmas_wish', ['I want $toy']), isTrue, reason: toy);
    }
    expect(ok('christmas_wish', ['I want']), isFalse);
    expect(ok('christmas_wish', ['candy']), isFalse);
  });

  test('yes/no questions', () {
    for (final id in ['like_snow', 'cold_today', 'sing_song', 'love_mommy']) {
      expect(ok(id, ['yes']), isTrue, reason: id);
      expect(ok(id, ['yep']), isTrue, reason: id);
      expect(ok(id, ['yeah']), isTrue, reason: id);
    }
    expect(ok('like_snow', ['no']), isTrue);
    expect(ok('like_snow', ['I do']), isTrue);
    expect(ok('like_snow', ['yes I like snow']), isTrue);
    expect(ok('like_snow', ['snow']), isFalse);
    expect(ok('cold_today', ['no']), isTrue);
    expect(ok('cold_today', ['it is cold']), isTrue);
    expect(ok('cold_today', ["it's cold"]), isTrue);
    expect(ok('cold_today', ['hot']), isFalse);
    expect(ok('sing_song', ['no']), isTrue);
    expect(ok('sing_song', ['I can sing']), isTrue);
    expect(ok('sing_song', ["I can't"]), isFalse);
    expect(ok('love_mommy', ['I love mommy']), isTrue);
    expect(ok('love_mommy', ['mommy']), isFalse);
  });

  test('repeating Elsa\'s yes/no question is not an answer', () {
    for (final (id, echo) in [
      ('like_snow', 'Do you like snow?'),
      ('sing_song', 'Can you sing a song?'),
      ('love_mommy', 'Do you love your mommy?'),
      ('cold_today', 'Is it cold today?'),
    ]) {
      expect(ok(id, [echo]), isFalse, reason: id);
      expect(ok(id, [echo.replaceAll('?', '')]), isFalse, reason: id);
    }
    // Bits of the question are not answers either.
    expect(ok('like_snow', ['like snow']), isFalse);
    expect(ok('sing_song', ['sing']), isFalse);
    expect(ok('sing_song', ['can']), isFalse);
    expect(ok('love_mommy', ['love']), isFalse);
    expect(ok('cold_today', ['cold']), isFalse);
    expect(ok('cold_today', ['very cold']), isFalse);
  });

  test('snowman color is white only', () {
    expect(ok('snowman_color', ['white']), isTrue);
    expect(ok('snowman_color', ["it's white"]), isTrue);
    expect(ok('snowman_color', ['blue']), isFalse);
  });

  test('the two "What\'s this?" pictures', () {
    expect(ok('what_tree', ["It's a Christmas tree"]), isTrue);
    expect(ok('what_tree', ['tree']), isTrue);
    expect(ok('what_tree', ['present']), isFalse);
    expect(ok('what_gift', ["It's a present"]), isTrue);
    expect(ok('what_gift', ['a gift']), isTrue);
    expect(ok('what_gift', ['box']), isTrue);
    expect(ok('what_gift', ['Christmas tree']), isFalse);
  });

  test('how many stars', () {
    expect(ok('how_many_stars', ['three']), isTrue);
    expect(ok('how_many_stars', ['3']), isTrue);
    expect(ok('how_many_stars', ['tree']), isTrue, reason: 'a small child\'s "three" is often heard as "tree"');
    expect(ok('how_many_stars', ['two']), isFalse);
    expect(ok('how_many_stars', ['33']), isFalse);
  });

  test('good morning and good night', () {
    expect(ok('good_morning', ['Good morning Elsa']), isTrue);
    expect(ok('good_morning', ['good night']), isFalse);
    expect(ok('good_night', ['good night']), isTrue);
    expect(ok('good_night', ['goodnight']), isTrue);
    expect(ok('good_night', ['good morning']), isFalse);
  });

  test('thank you', () {
    expect(ok('thank_you', ['thank you']), isTrue);
    expect(ok('thank_you', ['thanks']), isTrue);
    expect(ok('thank_you', ['tank you']), isTrue);
    expect(ok('thank_you', ['thankyou']), isTrue);
    expect(ok('thank_you', ['gift']), isFalse);
  });

  test('where do you live', () {
    expect(ok('where_live', ['I live in Vietnam']), isTrue);
    expect(ok('where_live', ['Viet Nam']), isTrue);
    expect(ok('where_live', ['Việt Nam']), isTrue);
    expect(ok('where_live', ['Hanoi']), isTrue);
    expect(ok('where_live', ['Ha Noi']), isTrue);
    expect(ok('where_live', ['Hà Nội']), isTrue);
    expect(ok('where_live', ['in a house']), isFalse);
  });

  test('favorite animal accepts common animals, singular or plural', () {
    for (final a in [
      'cat', 'cats', 'dogs', 'lion', 'rabbit', 'bunny', 'bear', 'fish', 'birds', 'duck', 'cow', 'pig', 'horse',
      'tiger', 'elephant', 'monkey', 'panda', 'penguin', 'unicorn',
    ]) {
      expect(ok('favorite_animal', ['I like $a']), isTrue, reason: a);
    }
    expect(ok('favorite_animal', ['I like pizza']), isFalse);
  });

  group('transcripts', () {
    test('empty or blank never matches', () {
      expect(ok('age', []), isFalse);
      expect(ok('age', ['']), isFalse);
      expect(ok('age', ['   ', '...']), isFalse);
    });
    test('the best two alternates may match, later guesses do not', () {
      expect(ok('age', ['banana', 'I am five']), isTrue);
      expect(ok('age', ['I am six', 'I am sex', 'I am five']), isFalse);
    });
    test('case, punctuation and apostrophes are ignored', () {
      expect(ok('snowman_color', ['  IT’S   WHITE!!! ']), isTrue);
      expect(ok('name', ["I'm AN."]), isTrue);
    });
    test('a group needs all its words', () {
      const item = ConversationItem(
        id: 'x',
        question: 'q',
        model: 'm',
        accept: [
          ['good', 'morning'],
        ],
      );
      expect(AnswerMatcher.matches(item, ['good']), isFalse);
      expect(AnswerMatcher.matches(item, ['morning good']), isTrue);
    });
  });

  test('normalize', () {
    expect(AnswerMatcher.normalize("  I'm   Five!  "), 'im five');
    expect(AnswerMatcher.normalize('Xoài, 5.'), 'xoài 5');
    expect(AnswerMatcher.normalize(''), '');
  });
}
