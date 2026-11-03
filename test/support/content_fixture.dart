import 'dart:convert';

import 'package:xoai_castle/core/content/content_validator.dart';

Map<String, String> validFiles() => {
      'manifest.json': jsonEncode({
        'schema': 1,
        'packs': {'letters_en': 1, 'letters_vi': 1, 'conversation': 1, 'stories': 1, 'vocab_animals': 1},
        'files': {'phrases': 1, 'castle': 1, 'characters': 1, 'profile_defaults': 1},
      }),
      'packs/letters_en.json': jsonEncode({
        'id': 'letters_en',
        'version': 1,
        'items': [
          {'char': 'A', 'example': {'word': 'Apple', 'emoji': '🍎'}, 'strokes': [[{'line': [[0.5, 0.1], [0.15, 0.9]]}]]},
          {'char': 'B', 'example': {'word': 'Ball', 'emoji': '⚽'}, 'strokes': [[{'line': [[0.25, 0.1], [0.25, 0.9]]}]]},
        ],
      }),
      'packs/letters_vi.json': jsonEncode({
        'id': 'letters_vi',
        'version': 1,
        'items': [
          {'char': 'A', 'spoken': 'a', 'strokes': [[{'line': [[0.5, 0.1], [0.15, 0.9]]}]]},
          {'char': 'Ă', 'spoken': 'á', 'strokes': [[{'line': [[0.5, 0.3], [0.15, 0.9]]}]]},
        ],
      }),
      'packs/conversation.json': jsonEncode({
        'id': 'conversation',
        'version': 1,
        'items': [
          {
            'id': 'age',
            'question': 'How old are you?',
            'model': 'I am five.',
            'accept': [['five'], ['4']],
            'aliases': {'five': ['fine']},
          },
          {
            'id': 'hello',
            'question': 'Hello, {name_en}!',
            'model': 'Hello, Elsa!',
            'accept': [['hello']],
          },
        ],
      }),
      'packs/stories.json': jsonEncode({
        'id': 'stories',
        'version': 1,
        'items': [
          {'id': 'yt:aaaaaaaaaaa', 'videoId': 'aaaaaaaaaaa', 'title': 'Tấm Cám', 'topic': 'fairy_vi', 'durationSec': 600},
          {'id': 'yt:bbbbbbbbbbb', 'videoId': 'bbbbbbbbbbb', 'title': 'Frozen story', 'topic': 'princess', 'durationSec': 900},
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
