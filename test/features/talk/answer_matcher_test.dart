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

  test('the shipped pack has the 8 questions in order', () {
    expect(items.keys, ['name', 'age', 'how_are_you', 'hello', 'goodbye', 'color', 'apples', 'flower']);
    expect(items['name']!.question, "What's your name?");
    expect(items['hello']!.question, 'Hello, {name_en}!');
    expect(items['name']!.model, 'My name is {name_en}.');
    expect(items['color']!.accept, hasLength(9));
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

  group('how_are_you', () {
    test('accepts many feelings', () {
      expect(ok('how_are_you', ['I am fine']), isTrue);
      expect(ok('how_are_you', ["I'm fine thank you"]), isTrue);
      expect(ok('how_are_you', ['great!']), isTrue);
      expect(ok('how_are_you', ['Okay']), isTrue);
      expect(ok('how_are_you', ['i am find']), isTrue);
      expect(ok('how_are_you', ['fun']), isFalse);
      expect(ok('how_are_you', ['happy']), isTrue);
    });
    test('rejects other answers', () {
      expect(ok('how_are_you', ['banana']), isFalse);
      expect(ok('how_are_you', ['thank you']), isFalse);
    });
  });

  test('hello and goodbye', () {
    expect(ok('hello', ['Hello Elsa']), isTrue);
    expect(ok('hello', ['yellow']), isFalse);
    expect(ok('hello', ['hi']), isTrue);
    expect(ok('hello', ['bye']), isFalse);
    expect(ok('goodbye', ['bye bye']), isTrue);
    expect(ok('goodbye', ['good bye']), isTrue);
    expect(ok('goodbye', ['goodbye']), isTrue);
    expect(ok('goodbye', ['buy']), isFalse);
    expect(ok('goodbye', ['by the way']), isFalse);
    expect(ok('goodbye', ['hello']), isFalse);
  });

  test('color accepts any of the nine colours, and aliases', () {
    for (final c in ['red', 'blue', 'pink', 'green', 'yellow', 'purple', 'orange', 'white', 'black']) {
      expect(ok('color', ['I like $c']), isTrue, reason: c);
    }
    expect(ok('color', ['read']), isTrue);
    expect(ok('color', ['blew']), isTrue);
    expect(ok('color', ['brown']), isFalse);
  });

  test('apples accepts yes or no', () {
    expect(ok('apples', ['yes']), isTrue);
    expect(ok('apples', ['yep']), isTrue);
    expect(ok('apples', ['No!']), isTrue);
    expect(ok('apples', ['I like apples']), isTrue);
    expect(ok('apples', ['banana']), isFalse);
    expect(ok('apples', ['I like bananas']), isFalse);
    expect(ok('apples', ['I like apple']), isTrue);
  });

  test('flower accepts thank you', () {
    expect(ok('flower', ['thank you']), isTrue);
    expect(ok('flower', ['thanks']), isTrue);
    expect(ok('flower', ['tank you']), isTrue);
    expect(ok('flower', ['thankyou']), isTrue);
    expect(ok('flower', ['flower']), isFalse);
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
      expect(ok('how_are_you', ['  I’M   FINE!!! ']), isTrue);
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
