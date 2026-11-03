import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_dir.dart';
import 'package:xoai_castle/core/content/content_validator.dart';

import '../../support/content_fixture.dart';

void main() {
  test('valid content has no errors', () {
    expect(validateContent(validFiles()), isEmpty);
  });

  test('missing manifest is reported', () {
    final files = validFiles()..remove('manifest.json');
    expect(validateContent(files), contains('manifest.json: thiếu file'));
  });

  test('invalid JSON is reported', () {
    final files = {...validFiles(), 'castle.json': '{oops'};
    expect(validateContent(files).single, startsWith('castle.json: JSON lỗi'));
  });

  test('version mismatch with manifest is reported', () {
    final castle = readJson(validFiles(), 'castle.json')..['version'] = 2;
    final errors = validateContent(withJson(validFiles(), 'castle.json', castle));
    expect(errors, contains('castle.json: version 2 khác với manifest (1)'));
  });

  test('duplicate letters are reported', () {
    final letters = readJson(validFiles(), 'packs/letters_en.json');
    (letters['items'] as List).add({'char': 'A', 'example': {'word': 'Ant', 'emoji': '🐜'}});
    final errors = validateContent(withJson(validFiles(), 'packs/letters_en.json', letters));
    expect(errors, contains('packs/letters_en.json items[2]: chữ "A" bị trùng'));
  });

  test('letter without emoji or image is reported', () {
    final letters = readJson(validFiles(), 'packs/letters_en.json');
    (letters['items'] as List)[0] = {'char': 'A', 'example': {'word': 'Apple'}};
    final errors = validateContent(withJson(validFiles(), 'packs/letters_en.json', letters));
    expect(errors, contains('packs/letters_en.json items[0]: cần "example.emoji" hoặc "example.image"'));
  });

  test('castle snowflakes must increase', () {
    final castle = readJson(validFiles(), 'castle.json');
    (castle['items'] as List)[1] = {'level': 2, 'snowflakes': 0};
    final errors = validateContent(withJson(validFiles(), 'castle.json', castle));
    expect(errors, contains('castle.json items[1]: "snowflakes" phải tăng dần'));
  });

  test('castle friends must exist in characters', () {
    final characters = readJson(validFiles(), 'characters.json');
    (characters['items'] as Map).remove('olaf');
    final errors = validateContent(withJson(validFiles(), 'characters.json', characters));
    expect(errors, contains('characters.json: thiếu nhân vật "olaf"'));
  });

  test('missing required phrase id is reported', () {
    final phrases = readJson(validFiles(), 'phrases.json');
    (phrases['items'] as List).removeWhere((p) => (p as Map)['id'] == 'error_home');
    final errors = validateContent(withJson(validFiles(), 'phrases.json', phrases));
    expect(errors, contains('phrases.json: thiếu câu bắt buộc "error_home"'));
  });

  test('image references are checked when asset paths are given', () {
    final characters = readJson(validFiles(), 'characters.json');
    (characters['items'] as Map)['elsa'] = {'name': 'Elsa', 'emoji': '👸', 'image': 'characters/elsa.png'};
    final files = withJson(validFiles(), 'characters.json', characters);
    expect(validateContent(files), isEmpty);
    expect(validateContent(files, assetPaths: {}), contains('characters.json elsa: không tìm thấy ảnh "characters/elsa.png"'));
    expect(
      validateContent(files, assetPaths: {'characters/elsa.png', ..._vocabImages}),
      isEmpty,
    );
  });

  test('vocabulary ids must be unique across packs', () {
    final files = validFiles();
    final manifest = readJson(files, 'manifest.json');
    (manifest['packs'] as Map)['vocab_more'] = 1;
    final more = {
      'id': 'vocab_more',
      'version': 1,
      'title_vi': 'Thêm',
      'items': [
        {'id': 'cat', 'word': 'cat', 'vi': 'con mèo', 'image': 'images/vocab/cat.png', 'emoji': '🐱'},
      ],
    };
    final errors = validateContent(withJson(withJson(files, 'manifest.json', manifest), 'packs/vocab_more.json', more));
    expect(errors, contains('packs/vocab_more.json items[0]: id "cat" đã có ở gói khác'));
  });

  test('vocabulary items need word, vi and emoji', () {
    final pack = readJson(validFiles(), 'packs/vocab_animals.json');
    (pack['items'] as List)[0] = {'id': 'cat', 'word': 'cat', 'image': 'images/vocab/cat.png'};
    final errors = validateContent(withJson(validFiles(), 'packs/vocab_animals.json', pack));
    expect(errors, containsAll([
      'packs/vocab_animals.json items[0]: thiếu "vi"',
      'packs/vocab_animals.json items[0]: thiếu "emoji"',
    ]));
  });

  test('at least four vocabulary words are required', () {
    final pack = readJson(validFiles(), 'packs/vocab_animals.json');
    (pack['items'] as List).removeLast();
    final errors = validateContent(withJson(validFiles(), 'packs/vocab_animals.json', pack));
    expect(errors, contains('Cần ít nhất 4 từ vựng (hiện có 3)'));
  });

  test('vocabulary images are checked against asset paths', () {
    final errors = validateContent(validFiles(), assetPaths: {'images/vocab/cat.png'});
    expect(errors, contains('packs/vocab_animals.json items[1]: không tìm thấy ảnh "images/vocab/dog.png"'));
  });

  group('conversation pack', () {
    const path = 'packs/conversation.json';
    List<String> check(void Function(List items) edit) {
      final pack = readJson(validFiles(), path);
      edit(pack['items'] as List);
      return validateContent(withJson(validFiles(), path, pack));
    }

    test('the pack is required', () {
      final manifest = readJson(validFiles(), 'manifest.json');
      (manifest['packs'] as Map).remove('conversation');
      final files = withJson(validFiles(), 'manifest.json', manifest)..remove(path);
      expect(validateContent(files), contains('manifest.json: thiếu gói "conversation"'));
    });

    test('duplicate ids are reported', () {
      final errors = check((items) => (items[1] as Map)['id'] = 'age');
      expect(errors, contains('$path items[1]: id "age" bị trùng'));
    });

    test('empty question or model is reported', () {
      final errors = check((items) {
        (items[0] as Map)['question'] = '  ';
        (items[0] as Map).remove('model');
      });
      expect(errors, containsAll(['$path items[0]: thiếu "question"', '$path items[0]: thiếu "model"']));
    });

    test('accept needs at least one non-empty group of words', () {
      expect(check((items) => (items[0] as Map)['accept'] = []), contains('$path items[0]: "accept" cần ít nhất một nhóm'));
      expect(check((items) => (items[0] as Map)['accept'] = [[]]),
          contains('$path items[0] accept[0]: nhóm phải là danh sách từ không rỗng'));
      expect(check((items) => (items[0] as Map)['accept'] = [['five', '']]),
          contains('$path items[0] accept[0]: nhóm phải là danh sách từ không rỗng'));
      expect(check((items) => (items[0] as Map).remove('accept')), contains('$path items[0]: "accept" cần ít nhất một nhóm'));
    });

    test('aliases must map a word to a list of words', () {
      expect(check((items) => (items[0] as Map)['aliases'] = {'five': 'fine'}),
          contains('$path items[0] aliases.five: phải là danh sách từ không rỗng'));
      expect(check((items) => (items[0] as Map)['aliases'] = {'five': ['fine', 3]}),
          contains('$path items[0] aliases.five: phải là danh sách từ không rỗng'));
      expect(check((items) => (items[0] as Map)['aliases'] = ['fine']),
          contains('$path items[0]: "aliases" phải là object'));
    });

    test('aliases are optional', () {
      expect(check((items) {}), isEmpty);
    });
  });

  test('multi-part phrases are validated', () {
    final phrases = readJson(validFiles(), 'phrases.json');
    (phrases['items'] as List).add({
      'id': 'two',
      'group': 'g',
      'parts': [
        {'lang': 'en', 'text': 'Hi!'},
        {'lang': 'fr', 'text': ''},
      ],
    });
    final errors = validateContent(withJson(validFiles(), 'phrases.json', phrases));
    expect(errors, containsAll([
      'phrases.json items[${(phrases['items'] as List).length - 1}] parts[1]: "lang" phải là "en" hoặc "vi"',
      'phrases.json items[${(phrases['items'] as List).length - 1}] parts[1]: thiếu "text"',
    ]));
  });

  test('audio index files must exist and no clip may be orphaned', () {
    const index = '{"clips": {"vi|A": "a.ogg", "vi|B": "b.ogg"}}';
    expect(validateAudioIndex(index, {'audio/a.ogg', 'audio/b.ogg'}), isEmpty);
    expect(validateAudioIndex(index, {'audio/a.ogg'}), contains('audio/index.json: thiếu file "audio/b.ogg"'));
    expect(validateAudioIndex(index, {'audio/a.ogg', 'audio/b.ogg', 'audio/c.ogg'}),
        contains('audio/c.ogg: không có câu nào dùng file này'));
  });

  test('the shipped content/ directory is valid', () {
    final snapshot = readContentDir('content');
    expect(validateContent(snapshot.json, assetPaths: snapshot.assets), isEmpty);
  });

  test('letters need valid strokes', () {
    final letters = readJson(validFiles(), 'packs/letters_en.json');
    (letters['items'] as List)[0] = {
      'char': 'A',
      'example': {'word': 'Apple', 'emoji': '🍎'},
      'strokes': [
        [ {'line': [[0.5, 0.1]]} ],
        [ {'arc': [0.5, 0.5, 0, 0.2, 0, 90]} ],
        [ {'line': [[0.5, 1.5], [0.2, 0.2]]} ],
      ],
    };
    final errors = validateContent(withJson(validFiles(), 'packs/letters_en.json', letters));
    expect(errors, containsAll([
      'packs/letters_en.json items[0] strokes[0][0]: "line" cần ít nhất 2 điểm',
      'packs/letters_en.json items[0] strokes[1][0]: "arc" cần rx, ry > 0 và sweep khác 0',
      'packs/letters_en.json items[0] strokes[2][0]: tọa độ phải trong khoảng 0–1',
    ]));
  });

  test('letters without strokes are reported', () {
    final letters = readJson(validFiles(), 'packs/letters_en.json');
    ((letters['items'] as List)[0] as Map).remove('strokes');
    final errors = validateContent(withJson(validFiles(), 'packs/letters_en.json', letters));
    expect(errors, contains('packs/letters_en.json items[0]: thiếu "strokes"'));
  });

  group('letters_vi', () {
    Map<String, String> withVi(void Function(List items) edit) {
      final letters = readJson(validFiles(), 'packs/letters_vi.json');
      edit(letters['items'] as List);
      return withJson(validFiles(), 'packs/letters_vi.json', letters);
    }

    test('the pack is required', () {
      final manifest = readJson(validFiles(), 'manifest.json');
      (manifest['packs'] as Map).remove('letters_vi');
      final errors = validateContent(withJson(validFiles(), 'manifest.json', manifest));
      expect(errors, contains('manifest.json: thiếu gói "letters_vi"'));
    });

    test('letters need no example, only a spoken name', () {
      expect(validateContent(withVi((_) {})), isEmpty);
    });

    test('a missing or blank spoken name is reported', () {
      final errors = validateContent(withVi((items) {
        (items[0] as Map).remove('spoken');
        (items[1] as Map)['spoken'] = ' ';
      }));
      expect(errors, contains('packs/letters_vi.json items[0]: thiếu "spoken"'));
      expect(errors, contains('packs/letters_vi.json items[1]: thiếu "spoken"'));
    });

    test('a char outside the 29 Vietnamese capitals is reported', () {
      final errors = validateContent(withVi((items) {
        (items[0] as Map)['char'] = 'F'; // Vietnamese has no F
        (items[1] as Map)['char'] = 'ă'; // lowercase
      }));
      expect(errors, contains('packs/letters_vi.json items[0]: "char" phải là một trong 29 chữ in hoa tiếng Việt'));
      expect(errors, contains('packs/letters_vi.json items[1]: "char" phải là một trong 29 chữ in hoa tiếng Việt'));
    });

    test('duplicate letters are reported', () {
      final errors = validateContent(withVi((items) => (items[1] as Map)['char'] = 'A'));
      expect(errors, contains('packs/letters_vi.json items[1]: chữ "A" bị trùng'));
    });

    test('letters need strokes', () {
      final errors = validateContent(withVi((items) => (items[0] as Map).remove('strokes')));
      expect(errors, contains('packs/letters_vi.json items[0]: thiếu "strokes"'));
    });

    test('letters_en still requires an example', () {
      final letters = readJson(validFiles(), 'packs/letters_en.json');
      ((letters['items'] as List)[0] as Map).remove('example');
      final errors = validateContent(withJson(validFiles(), 'packs/letters_en.json', letters));
      expect(errors, contains('packs/letters_en.json items[0]: thiếu "example.word"'));
    });
  });
}

const _vocabImages = {
  'images/vocab/cat.png',
  'images/vocab/dog.png',
  'images/vocab/lion.png',
  'images/vocab/duck.png',
};
