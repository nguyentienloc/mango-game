import 'dart:convert';

const requiredPacks = ['letters_en'];
const requiredFiles = ['phrases', 'castle', 'characters', 'profile_defaults'];

/// Phrase ids the app code refers to directly.
const requiredPhraseIds = {
  'greet_vi',
  'greet_en',
  'find_letter_prompt',
  'find_letter_small_prompt',
  'letter_example',
  'game_find_letter',
  'game_trace',
  'game_talk',
  'game_vi',
  'game_vocab',
  'game_castle',
  'coming_soon',
  'round_done',
  'quest_done',
  'castle_level_up',
  'friend_unlocked',
  'error_home',
};

/// Phrase groups the app picks from at random.
const requiredPhraseGroups = {'try_again'};

/// Paths (relative to content/) referenced by a manifest.
List<String> manifestPaths(Map<String, dynamic> manifest) => [
      for (final name in (manifest['packs'] as Map<String, dynamic>).keys) 'packs/$name.json',
      for (final name in (manifest['files'] as Map<String, dynamic>).keys) '$name.json',
    ];

/// Validates content files. [files] maps paths relative to content/ to JSON
/// text. When [assetPaths] is given, image references must exist in it.
/// Returns human-readable errors; an empty list means the content is valid.
List<String> validateContent(Map<String, String> files, {Set<String>? assetPaths}) {
  final errors = <String>[];
  final manifest = _decode(files, 'manifest.json', errors);
  if (manifest == null) return errors;
  final packs = manifest['packs'];
  final others = manifest['files'];
  if (packs is! Map<String, dynamic> || others is! Map<String, dynamic>) {
    return [...errors, 'manifest.json: thiếu "packs" hoặc "files"'];
  }
  for (final name in requiredPacks) {
    if (!packs.containsKey(name)) errors.add('manifest.json: thiếu gói "$name"');
  }
  for (final name in requiredFiles) {
    if (!others.containsKey(name)) errors.add('manifest.json: thiếu file "$name"');
  }
  final declared = <String, Object?>{
    for (final e in packs.entries) 'packs/${e.key}.json': e.value,
    for (final e in others.entries) '${e.key}.json': e.value,
  };
  final docs = <String, Map<String, dynamic>>{};
  for (final entry in declared.entries) {
    final json = _decode(files, entry.key, errors);
    if (json == null) continue;
    docs[entry.key] = json;
    final version = entry.value;
    if (version is! int || version < 1) {
      errors.add('manifest.json: version của ${entry.key} phải là số nguyên dương');
    } else if (json['version'] != version) {
      errors.add('${entry.key}: version ${json['version']} khác với manifest ($version)');
    }
  }
  if (errors.isNotEmpty) return errors;

  void checkImage(String where, Object? image) {
    if (image == null || assetPaths == null) return;
    if (image is! String || !assetPaths.contains(image)) {
      errors.add('$where: không tìm thấy ảnh "$image"');
    }
  }

  _checkLetters(docs['packs/letters_en.json']!, errors, checkImage);
  _checkPhrases(docs['phrases.json']!, errors);
  final friends = _checkCastle(docs['castle.json']!, errors);
  _checkCharacters(docs['characters.json']!, friends, errors, checkImage);
  _checkProfile(docs['profile_defaults.json']!, errors);
  return errors;
}

Map<String, dynamic>? _decode(Map<String, String> files, String path, List<String> errors) {
  final text = files[path];
  if (text == null) {
    errors.add('$path: thiếu file');
    return null;
  }
  try {
    final json = jsonDecode(text);
    if (json is Map<String, dynamic>) return json;
    errors.add('$path: phải là một object JSON');
  } on FormatException catch (e) {
    errors.add('$path: JSON lỗi — ${e.message}');
  }
  return null;
}

bool _nonEmpty(Object? v) => v is String && v.trim().isNotEmpty;

void _checkLetters(
  Map<String, dynamic> doc,
  List<String> errors,
  void Function(String where, Object? image) checkImage,
) {
  final items = doc['items'];
  if (items is! List || items.isEmpty) {
    errors.add('packs/letters_en.json: "items" phải là danh sách không rỗng');
    return;
  }
  final seen = <String>{};
  for (final (i, item) in items.indexed) {
    final where = 'packs/letters_en.json items[$i]';
    if (item is! Map<String, dynamic>) {
      errors.add('$where: phải là object');
      continue;
    }
    final char = item['char'];
    if (char is! String || !RegExp(r'^[A-Z]$').hasMatch(char)) {
      errors.add('$where: "char" phải là một chữ in hoa A–Z');
    } else if (!seen.add(char)) {
      errors.add('$where: chữ "$char" bị trùng');
    }
    final example = item['example'];
    if (example is! Map<String, dynamic> || !_nonEmpty(example['word'])) {
      errors.add('$where: thiếu "example.word"');
      continue;
    }
    if (!_nonEmpty(example['emoji']) && !_nonEmpty(example['image'])) {
      errors.add('$where: cần "example.emoji" hoặc "example.image"');
    }
    checkImage(where, example['image']);
  }
}

void _checkPhrases(Map<String, dynamic> doc, List<String> errors) {
  final items = doc['items'];
  if (items is! List || items.isEmpty) {
    errors.add('phrases.json: "items" phải là danh sách không rỗng');
    return;
  }
  final ids = <String>{};
  final groups = <String>{};
  for (final (i, item) in items.indexed) {
    final where = 'phrases.json items[$i]';
    if (item is! Map<String, dynamic>) {
      errors.add('$where: phải là object');
      continue;
    }
    final id = item['id'];
    if (!_nonEmpty(id)) {
      errors.add('$where: thiếu "id"');
    } else if (!ids.add(id as String)) {
      errors.add('$where: id "$id" bị trùng');
    }
    if (item['lang'] != 'en' && item['lang'] != 'vi') {
      errors.add('$where: "lang" phải là "en" hoặc "vi"');
    }
    if (!_nonEmpty(item['text'])) errors.add('$where: thiếu "text"');
    final group = item['group'];
    if (!_nonEmpty(group)) {
      errors.add('$where: thiếu "group"');
    } else {
      groups.add(group as String);
    }
  }
  for (final id in requiredPhraseIds) {
    if (!ids.contains(id)) errors.add('phrases.json: thiếu câu bắt buộc "$id"');
  }
  for (final group in requiredPhraseGroups) {
    if (!groups.contains(group)) errors.add('phrases.json: thiếu nhóm câu "$group"');
  }
}

Set<String> _checkCastle(Map<String, dynamic> doc, List<String> errors) {
  final friends = <String>{};
  final items = doc['items'];
  if (items is! List || items.isEmpty) {
    errors.add('castle.json: "items" phải là danh sách không rỗng');
    return friends;
  }
  var previous = -1;
  for (final (i, item) in items.indexed) {
    final where = 'castle.json items[$i]';
    if (item is! Map<String, dynamic>) {
      errors.add('$where: phải là object');
      continue;
    }
    if (item['level'] != i + 1) errors.add('$where: "level" phải là ${i + 1}');
    final flakes = item['snowflakes'];
    if (flakes is! int) {
      errors.add('$where: "snowflakes" phải là số nguyên');
      continue;
    }
    if (i == 0 && flakes != 0) errors.add('$where: mốc đầu tiên phải là 0 bông tuyết');
    if (i > 0 && flakes <= previous) errors.add('$where: "snowflakes" phải tăng dần');
    previous = flakes;
    final friend = item['friend'];
    if (friend == null) continue;
    if (_nonEmpty(friend)) {
      friends.add(friend as String);
    } else {
      errors.add('$where: "friend" không hợp lệ');
    }
  }
  return friends;
}

void _checkCharacters(
  Map<String, dynamic> doc,
  Set<String> friends,
  List<String> errors,
  void Function(String where, Object? image) checkImage,
) {
  final items = doc['items'];
  if (items is! Map<String, dynamic>) {
    errors.add('characters.json: "items" phải là object');
    return;
  }
  for (final id in {'elsa', ...friends}) {
    if (!items.containsKey(id)) errors.add('characters.json: thiếu nhân vật "$id"');
  }
  for (final entry in items.entries) {
    final where = 'characters.json ${entry.key}';
    final c = entry.value;
    if (c is! Map<String, dynamic>) {
      errors.add('$where: phải là object');
      continue;
    }
    if (!_nonEmpty(c['name'])) errors.add('$where: thiếu "name"');
    if (!_nonEmpty(c['emoji'])) errors.add('$where: thiếu "emoji"');
    checkImage(where, c['image']);
  }
}

void _checkProfile(Map<String, dynamic> doc, List<String> errors) {
  if (!_nonEmpty(doc['name_en'])) errors.add('profile_defaults.json: thiếu "name_en"');
  if (!_nonEmpty(doc['name_vi'])) errors.add('profile_defaults.json: thiếu "name_vi"');
  final limit = doc['daily_limit_min'];
  if (limit is! int || limit < 0) {
    errors.add('profile_defaults.json: "daily_limit_min" phải là số nguyên ≥ 0');
  }
}
