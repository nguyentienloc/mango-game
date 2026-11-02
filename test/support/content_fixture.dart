import 'dart:convert';

import 'package:xoai_castle/core/content/content_validator.dart';

Map<String, String> validFiles() => {
      'manifest.json': jsonEncode({
        'schema': 1,
        'packs': {'letters_en': 1, 'vocab_animals': 1},
        'files': {'phrases': 1, 'castle': 1, 'characters': 1, 'profile_defaults': 1},
      }),
      'packs/letters_en.json': jsonEncode({
        'id': 'letters_en',
        'version': 1,
        'items': [
          {'char': 'A', 'example': {'word': 'Apple', 'emoji': '🍎'}},
          {'char': 'B', 'example': {'word': 'Ball', 'emoji': '⚽'}},
        ],
      }),
      'packs/vocab_animals.json': jsonEncode({
        'id': 'vocab_animals',
        'version': 1,
        'title_vi': 'Con vật',
        'items': [
          for (final (id, vi) in [('cat', 'con mèo'), ('dog', 'con chó'), ('lion', 'con sư tử'), ('duck', 'con vịt')])
            {'id': id, 'word': id, 'vi': vi, 'image': 'images/vocab/$id.png', 'emoji': '🐾'},
        ],
      }),
      'phrases.json': jsonEncode({
        'version': 1,
        'items': [
          for (final id in requiredPhraseIds) {'id': id, 'lang': 'vi', 'text': 'Câu $id', 'group': 'g'},
          {'id': 'try_again_vi_1', 'lang': 'vi', 'text': 'Thử lại nha!', 'group': 'try_again'},
        ],
      }),
      'castle.json': jsonEncode({
        'version': 1,
        'items': [
          {'level': 1, 'snowflakes': 0},
          {'level': 2, 'snowflakes': 20, 'friend': 'olaf'},
        ],
      }),
      'characters.json': jsonEncode({
        'version': 1,
        'items': {
          'elsa': {'name': 'Elsa', 'emoji': '👸'},
          'olaf': {'name': 'Olaf', 'emoji': '⛄'},
        },
      }),
      'profile_defaults.json': jsonEncode({'version': 1, 'name_en': 'An', 'name_vi': 'Xoài', 'daily_limit_min': 20}),
    };

Map<String, String> withJson(Map<String, String> files, String path, Object json) =>
    {...files, path: jsonEncode(json)};

Map<String, dynamic> readJson(Map<String, String> files, String path) =>
    jsonDecode(files[path]!) as Map<String, dynamic>;
