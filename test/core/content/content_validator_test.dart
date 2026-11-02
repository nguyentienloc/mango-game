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

  test('the shipped content/ directory is valid', () {
    final snapshot = readContentDir('content');
    expect(validateContent(snapshot.json, assetPaths: snapshot.assets), isEmpty);
  });
}

const _vocabImages = {
  'images/vocab/cat.png',
  'images/vocab/dog.png',
  'images/vocab/lion.png',
  'images/vocab/duck.png',
};
