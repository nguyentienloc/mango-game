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
    expect(validateContent(files, assetPaths: {'characters/elsa.png'}), isEmpty);
  });

  test('the shipped content/ directory is valid', () {
    final snapshot = readContentDir('content');
    expect(validateContent(snapshot.json, assetPaths: snapshot.assets), isEmpty);
  });
}
