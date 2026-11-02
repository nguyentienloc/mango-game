# Giai đoạn 1 — Nền tảng + Tìm chữ cái — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Một APK Android chạy được: màn chính lâu đài băng, trò 🎈 Tìm chữ cái tiếng Anh, bông tuyết + mốc lâu đài + nhiệm vụ ngày + màn thưởng, khu bố mẹ có cửa khóa và tự cập nhật APK từ GitHub Releases, CI build/ký/phát hành.

**Architecture:** Flutter app một package `xoai_castle`. Logic thuần Dart nằm trong `lib/core/` (không import Flutter, nhận dependency qua constructor/interface để test không cần thiết bị). UI nằm trong `lib/features/` và `lib/shared/`, nối với core qua Riverpod providers trong `lib/app/`. Nội dung (chữ cái, câu nói, mốc lâu đài, nhân vật) là JSON trong `content/`, đóng gói làm asset và được kiểm tra bởi một validator dùng chung cho app + CLI + CI.

**Tech Stack:** Flutter (stable, cài qua Homebrew), Dart 3, flutter_riverpod, drift + drift_flutter (SQLite), flutter_tts, dio, package_info_plus, open_filex, path_provider; GitHub Actions; `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-11-02-xoai-ice-castle-design.md` (mục 14, giai đoạn 1).

## Global Constraints

- Package Dart: `xoai_castle`; applicationId Android: `vn.xoai.xoai_castle`; tên hiển thị: `Lâu đài Xoài`.
- Android `minSdk` ≥ 24; khóa màn hình dọc; chế độ toàn màn hình `immersiveSticky`.
- Repo GitHub: `nguyentienloc/mango-game` (public) — hằng số `kGithubRepo`.
- Phiên bản đầu: `0.1.0+1`; tag phát hành dạng `v0.1.0`.
- Tên bé: tiếng Anh `An` (dùng trong câu `lang: en`), tiếng Việt `Xoài` (dùng trong câu `lang: vi`).
- Mức thuộc 0–4; kết quả câu: `firstTry` (+1), `retry` (giữ nguyên), `hinted` (−1).
- Thưởng: +1 ❄️ mỗi câu `firstTry`, +5 ❄️ mỗi lượt, nhiệm vụ ngày = 3 lượt → +20 ❄️ (chưa có sticker ở giai đoạn này).
- Mốc lâu đài: 0/20/50/100/170/260/380/530 ❄️; bạn mở khóa: mốc 2 Olaf, 4 Anna, 6 Sven, 8 Kristoff.
- Tìm chữ cái: 8 câu/lượt; tối đa 2 mục mới/lượt; mở chữ thường khi ≥ 20/26 chữ hoa đạt mức ≥ 2; mở ghép hoa–thường khi ≥ 20/26 chữ thường đạt mức ≥ 2; 3 phương án (chữ hoa/thường), 4 phương án (ghép).
- TTS: `en-US`/`vi-VN`, speech rate 0.42, pitch 1.15.
- Cửa khu bố mẹ: giữ ổ khóa 2 giây → phép cộng hai số có hai chữ số.
- Chữ hiển thị cho bố mẹ và thông báo lỗi viết bằng tiếng Việt.
- `flutter analyze --no-fatal-infos` và `flutter test` phải sạch trước mỗi commit.
- Không commit keystore, `key.properties`, mật khẩu.

## File Structure

```
pubspec.yaml, analysis_options.yaml
android/app/build.gradle.kts            minSdk, ký release từ key.properties
android/app/src/main/AndroidManifest.xml quyền, queries TTS, nhãn, khóa dọc
content/
  manifest.json, phrases.json, castle.json, characters.json, profile_defaults.json
  packs/letters_en.json
  characters/README.md                   hướng dẫn thêm ảnh nhân vật
tool/validate_content.dart               CLI kiểm tra content/
lib/
  main.dart                              bootstrap: nội dung, DB, TTS, ProviderScope
  app/app.dart                           MaterialApp
  app/config.dart                        kGithubRepo
  app/theme.dart                         màu băng, ThemeData
  app/providers.dart                     các provider nền
  app/reward_controller.dart             AsyncNotifier trạng thái phần thưởng
  core/time.dart                         dayKey()
  core/content/models.dart               LetterItem, Phrase, CastleLevel, CharacterDef, ProfileDefaults, ContentBundle
  core/content/content_validator.dart    validateContent(), manifestPaths()
  core/content/content_repository.dart   ContentSource, ContentRepository, ContentException
  core/content/asset_content_source.dart đọc từ asset Flutter
  core/content/file_content_source.dart  đọc từ thư mục (tool + test)
  core/content/content_dir.dart          readContentDir() cho tool + test
  core/db/database.dart (+ .g.dart)      drift: ItemStats, Sessions, Rewards, Profile
  core/progress/item_stat.dart           AnswerOutcome, ItemStat.apply()
  core/progress/item_stats_store.dart    ItemStatsStore + DriftItemStatsStore
  core/progress/question_picker.dart     QuestionPicker
  core/session/session_store.dart        SessionRecord, SessionStore + Drift
  core/profile/names.dart                Names
  core/profile/profile_store.dart        ProfileStore + Drift
  core/rewards/reward_state.dart         RewardState, RewardOutcome
  core/rewards/reward_rules.dart         castleLevelFor, roundsToday, applyRound
  core/rewards/reward_store.dart         RewardStore + Drift
  core/voice/tts_engine.dart             TtsEngine interface
  core/voice/flutter_tts_engine.dart     triển khai bằng flutter_tts
  core/voice/voice_service.dart          VoiceService
  core/updater/version_compare.dart      normalizeVersion, isNewerVersion
  core/updater/app_updater.dart          ReleaseApi, GithubReleaseApi, AppUpdater, UpdateCheck
  features/home/home_screen.dart
  features/castle/castle_screen.dart
  features/reward/reward_screen.dart
  features/games/find_letter/find_letter_logic.dart   chế độ, dựng lượt, FindLetterSession
  features/games/find_letter/find_letter_screen.dart
  features/games/find_letter/falling_flakes.dart
  features/games/find_letter/example_card.dart
  features/parent/parent_lock_button.dart
  features/parent/parent_gate.dart
  features/parent/parent_screen.dart
  features/parent/update_download_dialog.dart
  shared/ice_background.dart, big_button.dart, snowflake_counter.dart,
  shared/quest_dots.dart, character_view.dart, castle_view.dart
test/
  support/fakes.dart, support/content_fixture.dart, support/test_app.dart
  core/... và features/... (tương ứng)
.github/workflows/ci.yml, release.yml
```

---

### Task 0: Cài môi trường và tạo dự án Flutter

**Files:**
- Create: toàn bộ khung do `flutter create` sinh ra
- Modify: `pubspec.yaml`, `analysis_options.yaml`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`
- Delete: `test/widget_test.dart`

**Interfaces:**
- Produces: package `xoai_castle` build được APK debug; các dependency đã thêm.

- [ ] **Step 1: Cài Flutter và trỏ JDK 17 / Android SDK**

```bash
brew install --cask flutter
flutter --version
flutter config --jdk-dir "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
flutter config --android-sdk "$HOME/Library/Android/sdk"
yes | flutter doctor --android-licenses
flutter doctor
```
Expected: `flutter doctor` báo ✓ cho Flutter và Android toolchain (Xcode/Chrome báo thiếu không sao).

- [ ] **Step 2: Tạo dự án trong thư mục repo**

```bash
cd /Users/locnguyen/orca/projects/mango-game
flutter create --org vn.xoai --project-name xoai_castle --platforms android .
rm test/widget_test.dart
```

- [ ] **Step 3: Thêm dependency**

```bash
flutter pub add flutter_riverpod drift drift_flutter flutter_tts dio package_info_plus open_filex path_provider
flutter pub add dev:drift_dev dev:build_runner
```
Nếu `pub` chọn `flutter_riverpod` 2.x thay vì 3.x thì vẫn dùng được: code trong plan chỉ dùng `Provider`, `FutureProvider`, `AsyncNotifier`, `AsyncNotifierProvider`, `overrideWithValue`, `overrideWith`, `.value`, `.when`, `ref.invalidate`, đều có ở cả hai phiên bản.

- [ ] **Step 4: Sửa `pubspec.yaml`**

Đổi dòng `version:` thành:
```yaml
version: 0.1.0+1
```
Trong khối `flutter:` (giữ `uses-material-design: true`), thêm:
```yaml
  assets:
    - content/
    - content/packs/
    - content/characters/
```
Đổi `description:` thành `Lâu đài băng của Xoài — game học cho bé.`

- [ ] **Step 5: Sửa `analysis_options.yaml`** — thêm ở cuối file:

```yaml
analyzer:
  exclude:
    - lib/**/*.g.dart
```

- [ ] **Step 6: Sửa `android/app/build.gradle.kts`**

Trong khối `defaultConfig`, đổi dòng `minSdk = flutter.minSdkVersion` thành:
```kotlin
        minSdk = maxOf(24, flutter.minSdkVersion)
```
(Phần ký release làm ở Task 11.)

- [ ] **Step 7: Sửa `android/app/src/main/AndroidManifest.xml`**

Thêm ngay sau thẻ mở `<manifest ...>`:
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```
Trong thẻ `<application ...>` đổi `android:label="xoai_castle"` thành `android:label="Lâu đài Xoài"`.
Trong thẻ `<activity android:name=".MainActivity" ...>` thêm thuộc tính `android:screenOrientation="portrait"`.
Trong khối `<queries>` có sẵn (cuối file), thêm:
```xml
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE"/>
        </intent>
```

- [ ] **Step 8: Thay `lib/main.dart` bằng bản tối thiểu** (Task 8 sẽ thay hẳn)

```dart
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Xoài')))));
```

- [ ] **Step 9: Kiểm tra build**

```bash
flutter analyze --no-fatal-infos
flutter build apk --debug
```
Expected: analyze `No issues found!` (hoặc chỉ info); build tạo `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter Android project xoai_castle"
```

---

### Task 1: Nội dung — model, validator, repository, file JSON, CLI

**Files:**
- Create: `lib/core/content/models.dart`, `lib/core/content/content_validator.dart`, `lib/core/content/content_repository.dart`, `lib/core/content/asset_content_source.dart`, `lib/core/content/file_content_source.dart`, `lib/core/content/content_dir.dart`, `tool/validate_content.dart`
- Create: `content/manifest.json`, `content/phrases.json`, `content/castle.json`, `content/characters.json`, `content/profile_defaults.json`, `content/packs/letters_en.json`, `content/characters/README.md`
- Test: `test/support/content_fixture.dart`, `test/core/content/content_validator_test.dart`, `test/core/content/content_repository_test.dart`

**Interfaces:**
- Produces:
  - `class LetterItem { String char; String exampleWord; String? exampleEmoji; String? exampleImage; String get lower; }`
  - `class Phrase { String id; String lang; String text; String group; bool priority; }`
  - `class CastleLevel { int level; int snowflakes; String? friend; }`
  - `class CharacterDef { String id; String name; String emoji; String? image; }`
  - `class ProfileDefaults { String nameEn; String nameVi; int dailyLimitMin; }`
  - `class ContentBundle { List<LetterItem> lettersEn; Map<String, Phrase> phrases; List<CastleLevel> castle; Map<String, CharacterDef> characters; ProfileDefaults profileDefaults; factory ContentBundle.fromFiles(Map<String, String>); }`
  - `List<String> validateContent(Map<String, String> files, {Set<String>? assetPaths})`; `List<String> manifestPaths(Map<String, dynamic>)`; `const Set<String> requiredPhraseIds`; `const Set<String> requiredPhraseGroups`
  - `abstract interface class ContentSource { Future<String> readText(String path); }`
  - `class ContentRepository { ContentRepository(ContentSource); Future<ContentBundle> load(); }` — ném `ContentException(List<String> errors)` khi lỗi
  - `class AssetContentSource implements ContentSource`, `class FileContentSource implements ContentSource { FileContentSource(String root); }`
  - `ContentDirSnapshot readContentDir(String root)` với `.json: Map<String,String>` và `.assets: Set<String>`

- [ ] **Step 1: Viết fixture và test validator (failing)**

`test/support/content_fixture.dart`:
```dart
import 'dart:convert';

import 'package:xoai_castle/core/content/content_validator.dart';

Map<String, String> validFiles() => {
      'manifest.json': jsonEncode({
        'schema': 1,
        'packs': {'letters_en': 1},
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
```

`test/core/content/content_validator_test.dart`:
```dart
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
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `flutter test test/core/content/content_validator_test.dart`
Expected: FAIL — lỗi biên dịch, chưa có `content_validator.dart`.

- [ ] **Step 3: Viết `lib/core/content/content_validator.dart`**

```dart
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
```

- [ ] **Step 4: Viết `lib/core/content/content_dir.dart`**

```dart
import 'dart:io';

class ContentDirSnapshot {
  ContentDirSnapshot(this.json, this.assets);

  /// JSON files keyed by path relative to the content root.
  final Map<String, String> json;

  /// Every non-JSON file path relative to the content root.
  final Set<String> assets;
}

ContentDirSnapshot readContentDir(String root) {
  final dir = Directory(root);
  final json = <String, String>{};
  final assets = <String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = entity.path.substring(dir.path.length + 1).replaceAll(r'\', '/');
    if (rel.endsWith('.json')) {
      json[rel] = entity.readAsStringSync();
    } else {
      assets.add(rel);
    }
  }
  return ContentDirSnapshot(json, assets);
}
```

- [ ] **Step 5: Tạo các file nội dung**

`content/manifest.json`:
```json
{
  "schema": 1,
  "packs": { "letters_en": 1 },
  "files": { "phrases": 1, "castle": 1, "characters": 1, "profile_defaults": 1 }
}
```

`content/profile_defaults.json`:
```json
{ "version": 1, "name_en": "An", "name_vi": "Xoài", "daily_limit_min": 20 }
```

`content/castle.json`:
```json
{
  "version": 1,
  "items": [
    { "level": 1, "snowflakes": 0 },
    { "level": 2, "snowflakes": 20, "friend": "olaf" },
    { "level": 3, "snowflakes": 50 },
    { "level": 4, "snowflakes": 100, "friend": "anna" },
    { "level": 5, "snowflakes": 170 },
    { "level": 6, "snowflakes": 260, "friend": "sven" },
    { "level": 7, "snowflakes": 380 },
    { "level": 8, "snowflakes": 530, "friend": "kristoff" }
  ]
}
```

`content/characters.json`:
```json
{
  "version": 1,
  "items": {
    "elsa": { "name": "Elsa", "emoji": "👸" },
    "olaf": { "name": "Olaf", "emoji": "⛄" },
    "anna": { "name": "Anna", "emoji": "👧" },
    "sven": { "name": "Sven", "emoji": "🦌" },
    "kristoff": { "name": "Kristoff", "emoji": "🧔" }
  }
}
```

`content/phrases.json`:
```json
{
  "version": 1,
  "items": [
    { "id": "greet_vi", "lang": "vi", "text": "Chào {name_vi}! Hôm nay mình chơi gì nào?", "group": "greet" },
    { "id": "greet_en", "lang": "en", "text": "Hi {name_en}! Let's play!", "group": "greet" },
    { "id": "praise_en_1", "lang": "en", "text": "Great job!", "group": "praise" },
    { "id": "praise_en_2", "lang": "en", "text": "Wonderful, {name_en}!", "group": "praise" },
    { "id": "praise_en_3", "lang": "en", "text": "You did it!", "group": "praise" },
    { "id": "praise_vi_1", "lang": "vi", "text": "Giỏi quá {name_vi} ơi!", "group": "praise", "priority": true },
    { "id": "praise_vi_2", "lang": "vi", "text": "{name_vi} làm đúng rồi!", "group": "praise" },
    { "id": "try_again_en_1", "lang": "en", "text": "Try again!", "group": "try_again" },
    { "id": "try_again_vi_1", "lang": "vi", "text": "Thử lại nha con!", "group": "try_again", "priority": true },
    { "id": "find_letter_prompt", "lang": "en", "text": "Find the letter {letter}!", "group": "instruction" },
    { "id": "find_letter_small_prompt", "lang": "en", "text": "Find the small {letter}!", "group": "instruction" },
    { "id": "letter_example", "lang": "en", "text": "{letter}! {letter} is for {word}!", "group": "instruction" },
    { "id": "game_find_letter", "lang": "vi", "text": "Tìm chữ cái", "group": "menu" },
    { "id": "game_trace", "lang": "vi", "text": "Tô chữ", "group": "menu" },
    { "id": "game_talk", "lang": "vi", "text": "Nói chuyện với Elsa", "group": "menu" },
    { "id": "game_vi", "lang": "vi", "text": "Chữ cái tiếng Việt", "group": "menu" },
    { "id": "game_vocab", "lang": "vi", "text": "Học từ mới", "group": "menu" },
    { "id": "game_castle", "lang": "vi", "text": "Lâu đài của {name_vi}", "group": "menu" },
    { "id": "coming_soon", "lang": "vi", "text": "Trò này sắp có rồi nha!", "group": "system" },
    { "id": "round_done", "lang": "vi", "text": "Hoàn thành rồi! {name_vi} giỏi quá!", "group": "reward", "priority": true },
    { "id": "quest_done", "lang": "vi", "text": "Xong nhiệm vụ hôm nay rồi! Mở quà nào!", "group": "reward" },
    { "id": "castle_level_up", "lang": "vi", "text": "Lâu đài lớn thêm rồi nè!", "group": "reward" },
    { "id": "friend_unlocked", "lang": "vi", "text": "Có bạn mới đến chơi với {name_vi} nè!", "group": "reward" },
    { "id": "error_home", "lang": "vi", "text": "Mình về lâu đài nha!", "group": "system" }
  ]
}
```

`content/packs/letters_en.json`:
```json
{
  "id": "letters_en",
  "version": 1,
  "items": [
    { "char": "A", "example": { "word": "Apple", "emoji": "🍎" } },
    { "char": "B", "example": { "word": "Ball", "emoji": "⚽" } },
    { "char": "C", "example": { "word": "Cat", "emoji": "🐱" } },
    { "char": "D", "example": { "word": "Dog", "emoji": "🐶" } },
    { "char": "E", "example": { "word": "Egg", "emoji": "🥚" } },
    { "char": "F", "example": { "word": "Fish", "emoji": "🐟" } },
    { "char": "G", "example": { "word": "Grapes", "emoji": "🍇" } },
    { "char": "H", "example": { "word": "Hat", "emoji": "🎩" } },
    { "char": "I", "example": { "word": "Ice cream", "emoji": "🍦" } },
    { "char": "J", "example": { "word": "Juice", "emoji": "🧃" } },
    { "char": "K", "example": { "word": "Kite", "emoji": "🪁" } },
    { "char": "L", "example": { "word": "Lion", "emoji": "🦁" } },
    { "char": "M", "example": { "word": "Moon", "emoji": "🌙" } },
    { "char": "N", "example": { "word": "Nose", "emoji": "👃" } },
    { "char": "O", "example": { "word": "Orange", "emoji": "🍊" } },
    { "char": "P", "example": { "word": "Pig", "emoji": "🐷" } },
    { "char": "Q", "example": { "word": "Queen", "emoji": "👑" } },
    { "char": "R", "example": { "word": "Rabbit", "emoji": "🐰" } },
    { "char": "S", "example": { "word": "Sun", "emoji": "☀️" } },
    { "char": "T", "example": { "word": "Tree", "emoji": "🌳" } },
    { "char": "U", "example": { "word": "Umbrella", "emoji": "☂️" } },
    { "char": "V", "example": { "word": "Van", "emoji": "🚐" } },
    { "char": "W", "example": { "word": "Watermelon", "emoji": "🍉" } },
    { "char": "X", "example": { "word": "Xmas tree", "emoji": "🎄" } },
    { "char": "Y", "example": { "word": "Yo-yo", "emoji": "🪀" } },
    { "char": "Z", "example": { "word": "Zebra", "emoji": "🦓" } }
  ]
}
```

`content/characters/README.md`:
```markdown
# Ảnh nhân vật

Đặt ảnh PNG nền trong suốt vào thư mục này (ví dụ `elsa.png`), rồi khai báo trong
`content/characters.json`:

    "elsa": { "name": "Elsa", "emoji": "👸", "image": "characters/elsa.png" }

Không có `image` thì app dùng hình tạm (Elsa vẽ bằng code, các bạn khác dùng emoji).
Ảnh nhân vật Disney chỉ dùng trong gia đình, không chia sẻ công khai.
```

- [ ] **Step 6: Chạy test validator**

Run: `flutter test test/core/content/content_validator_test.dart`
Expected: tất cả PASS (kể cả test thư mục `content/` thật).

- [ ] **Step 7: Viết test repository (failing)**

`test/core/content/content_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';

import '../../support/content_fixture.dart';

class MapContentSource implements ContentSource {
  MapContentSource(this.files);
  final Map<String, String> files;

  @override
  Future<String> readText(String path) async => files[path] ?? (throw StateError('missing $path'));
}

void main() {
  test('loads a bundle from valid files', () async {
    final bundle = await ContentRepository(MapContentSource(validFiles())).load();
    expect(bundle.lettersEn.map((l) => l.char), ['A', 'B']);
    expect(bundle.lettersEn.first.exampleEmoji, '🍎');
    expect(bundle.lettersEn.first.lower, 'a');
    expect(bundle.phrases['try_again_vi_1']!.lang, 'vi');
    expect(bundle.castle.map((l) => l.snowflakes), [0, 20]);
    expect(bundle.castle[1].friend, 'olaf');
    expect(bundle.characters['olaf']!.emoji, '⛄');
    expect(bundle.characters['elsa']!.image, isNull);
    expect(bundle.profileDefaults.nameVi, 'Xoài');
    expect(bundle.profileDefaults.dailyLimitMin, 20);
  });

  test('throws ContentException listing errors for invalid content', () async {
    final files = {...validFiles(), 'castle.json': '{oops'};
    expect(
      () => ContentRepository(MapContentSource(files)).load(),
      throwsA(isA<ContentException>().having((e) => e.errors.single, 'error', startsWith('castle.json'))),
    );
  });

  test('loads the shipped content directory', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.lettersEn, hasLength(26));
    expect(bundle.castle, hasLength(8));
  });
}
```

- [ ] **Step 8: Chạy test, xác nhận fail**

Run: `flutter test test/core/content/content_repository_test.dart`
Expected: FAIL — chưa có `content_repository.dart`.

- [ ] **Step 9: Viết `lib/core/content/models.dart`**

```dart
import 'dart:convert';

class LetterItem {
  const LetterItem({required this.char, required this.exampleWord, this.exampleEmoji, this.exampleImage});

  factory LetterItem.fromJson(Map<String, dynamic> json) {
    final example = json['example'] as Map<String, dynamic>;
    return LetterItem(
      char: json['char'] as String,
      exampleWord: example['word'] as String,
      exampleEmoji: example['emoji'] as String?,
      exampleImage: example['image'] as String?,
    );
  }

  final String char;
  final String exampleWord;
  final String? exampleEmoji;
  final String? exampleImage;

  String get lower => char.toLowerCase();
}

class Phrase {
  const Phrase({required this.id, required this.lang, required this.text, required this.group, this.priority = false});

  factory Phrase.fromJson(Map<String, dynamic> json) => Phrase(
        id: json['id'] as String,
        lang: json['lang'] as String,
        text: json['text'] as String,
        group: json['group'] as String,
        priority: json['priority'] as bool? ?? false,
      );

  final String id;
  final String lang;
  final String text;
  final String group;
  final bool priority;
}

class CastleLevel {
  const CastleLevel({required this.level, required this.snowflakes, this.friend});

  factory CastleLevel.fromJson(Map<String, dynamic> json) => CastleLevel(
        level: json['level'] as int,
        snowflakes: json['snowflakes'] as int,
        friend: json['friend'] as String?,
      );

  final int level;
  final int snowflakes;
  final String? friend;
}

class CharacterDef {
  const CharacterDef({required this.id, required this.name, required this.emoji, this.image});

  factory CharacterDef.fromJson(String id, Map<String, dynamic> json) => CharacterDef(
        id: id,
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        image: json['image'] as String?,
      );

  final String id;
  final String name;
  final String emoji;
  final String? image;
}

class ProfileDefaults {
  const ProfileDefaults({required this.nameEn, required this.nameVi, required this.dailyLimitMin});

  factory ProfileDefaults.fromJson(Map<String, dynamic> json) => ProfileDefaults(
        nameEn: json['name_en'] as String,
        nameVi: json['name_vi'] as String,
        dailyLimitMin: json['daily_limit_min'] as int,
      );

  final String nameEn;
  final String nameVi;
  final int dailyLimitMin;
}

class ContentBundle {
  const ContentBundle({
    required this.lettersEn,
    required this.phrases,
    required this.castle,
    required this.characters,
    required this.profileDefaults,
  });

  /// Builds a bundle from already-validated files (paths relative to content/).
  factory ContentBundle.fromFiles(Map<String, String> files) {
    Map<String, dynamic> read(String path) => jsonDecode(files[path]!) as Map<String, dynamic>;
    final characters = read('characters.json')['items'] as Map<String, dynamic>;
    return ContentBundle(
      lettersEn: [
        for (final j in read('packs/letters_en.json')['items'] as List) LetterItem.fromJson(j as Map<String, dynamic>),
      ],
      phrases: {
        for (final j in read('phrases.json')['items'] as List)
          (j as Map<String, dynamic>)['id'] as String: Phrase.fromJson(j),
      },
      castle: [
        for (final j in read('castle.json')['items'] as List) CastleLevel.fromJson(j as Map<String, dynamic>),
      ],
      characters: {
        for (final e in characters.entries) e.key: CharacterDef.fromJson(e.key, e.value as Map<String, dynamic>),
      },
      profileDefaults: ProfileDefaults.fromJson(read('profile_defaults.json')),
    );
  }

  final List<LetterItem> lettersEn;
  final Map<String, Phrase> phrases;
  final List<CastleLevel> castle;
  final Map<String, CharacterDef> characters;
  final ProfileDefaults profileDefaults;
}
```

- [ ] **Step 10: Viết repository và các nguồn**

`lib/core/content/content_repository.dart`:
```dart
import 'dart:convert';

import 'content_validator.dart';
import 'models.dart';

abstract interface class ContentSource {
  /// Reads a file by its path relative to content/.
  Future<String> readText(String path);
}

class ContentException implements Exception {
  ContentException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'ContentException: ${errors.join('; ')}';
}

class ContentRepository {
  ContentRepository(this.source);

  final ContentSource source;

  Future<ContentBundle> load() async {
    final manifestText = await source.readText('manifest.json');
    final files = <String, String>{'manifest.json': manifestText};
    final List<String> paths;
    try {
      paths = manifestPaths(jsonDecode(manifestText) as Map<String, dynamic>);
    } on Object {
      throw ContentException(validateContent(files));
    }
    for (final path in paths) {
      files[path] = await source.readText(path);
    }
    final errors = validateContent(files);
    if (errors.isNotEmpty) throw ContentException(errors);
    return ContentBundle.fromFiles(files);
  }
}
```

`lib/core/content/file_content_source.dart`:
```dart
import 'dart:io';

import 'content_repository.dart';

class FileContentSource implements ContentSource {
  FileContentSource(this.root);

  final String root;

  @override
  Future<String> readText(String path) => File('$root/$path').readAsString();
}
```

`lib/core/content/asset_content_source.dart`:
```dart
import 'package:flutter/services.dart';

import 'content_repository.dart';

class AssetContentSource implements ContentSource {
  @override
  Future<String> readText(String path) => rootBundle.loadString('content/$path');
}
```

- [ ] **Step 11: Viết CLI `tool/validate_content.dart`**

```dart
import 'dart:io';

import 'package:xoai_castle/core/content/content_dir.dart';
import 'package:xoai_castle/core/content/content_validator.dart';

void main(List<String> args) {
  final snapshot = readContentDir(args.isEmpty ? 'content' : args.first);
  final errors = validateContent(snapshot.json, assetPaths: snapshot.assets);
  if (errors.isEmpty) {
    stdout.writeln('Nội dung hợp lệ ✅');
    return;
  }
  for (final error in errors) {
    stderr.writeln('❌ $error');
  }
  exit(1);
}
```

- [ ] **Step 12: Chạy toàn bộ test + CLI**

```bash
flutter test test/core/content
dart run tool/validate_content.dart
flutter analyze --no-fatal-infos
```
Expected: test PASS; CLI in `Nội dung hợp lệ ✅`; analyze không có error/warning.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "feat: content models, validator, repository and starter content"
```

---

### Task 2: Cơ sở dữ liệu và các store

**Files:**
- Create: `lib/core/db/database.dart` (+ sinh `lib/core/db/database.g.dart`), `lib/core/progress/item_stat.dart`, `lib/core/progress/item_stats_store.dart`, `lib/core/session/session_store.dart`, `lib/core/profile/names.dart`, `lib/core/profile/profile_store.dart`, `lib/core/rewards/reward_state.dart`, `lib/core/rewards/reward_store.dart`
- Test: `test/core/db/stores_test.dart`, `test/support/fakes.dart`

**Interfaces:**
- Consumes: `ProfileDefaults` (Task 1).
- Produces:
  - `class AppDatabase extends _$AppDatabase { AppDatabase(QueryExecutor e); }` với các bảng `itemStats`, `sessions`, `rewards`, `profile`
  - `enum AnswerOutcome { firstTry, retry, hinted }`
  - `class ItemStat { String key; int mastery; int correct; int wrong; DateTime? lastSeen; ItemStat apply(AnswerOutcome, DateTime now); }` (`apply` viết ở Task 3; ở task này chỉ có constructor + field)
  - `abstract interface class ItemStatsStore { Future<Map<String, ItemStat>> loadByPrefix(String prefix); Future<void> save(ItemStat stat); }` + `DriftItemStatsStore(AppDatabase)`
  - `class SessionRecord { String date; String game; DateTime startedAt; int durationSec; int correct; int total; }`; `abstract interface class SessionStore { Future<void> add(SessionRecord r); }` + `DriftSessionStore(AppDatabase)`
  - `class Names { String en; String vi; }`; `abstract interface class ProfileStore { Future<Names> loadNames(ProfileDefaults defaults); }` + `DriftProfileStore(AppDatabase)`
  - `class RewardState { int snowflakesTotal = 0; int castleLevel = 1; int streakDays = 0; String? lastPlayDate; String? dailyQuestDate; int dailyRoundsDone = 0; }`
  - `class RewardOutcome { int earned; bool questCompleted; int previousLevel; int newLevel; String? friendUnlocked; RewardState state; bool get leveledUp; }`
  - `abstract interface class RewardStore { Future<RewardState> load(); Future<void> save(RewardState s); }` + `DriftRewardStore(AppDatabase)`
  - Test fakes: `FakeTts`, `MemoryItemStatsStore`, `FailingItemStatsStore`, `MemorySessionStore`, `MemoryRewardStore`

- [ ] **Step 1: Viết `lib/core/db/database.dart`**

```dart
import 'package:drift/drift.dart';

part 'database.g.dart';

@DataClassName('ItemStatRow')
class ItemStats extends Table {
  TextColumn get itemKey => text()();
  IntColumn get mastery => integer().withDefault(const Constant(0))();
  IntColumn get correct => integer().withDefault(const Constant(0))();
  IntColumn get wrong => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSeen => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {itemKey};
}

@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  TextColumn get game => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationSec => integer()();
  IntColumn get correct => integer()();
  IntColumn get total => integer()();
}

@DataClassName('RewardRow')
class Rewards extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get snowflakesTotal => integer().withDefault(const Constant(0))();
  IntColumn get castleLevel => integer().withDefault(const Constant(1))();
  IntColumn get streakDays => integer().withDefault(const Constant(0))();
  TextColumn get lastPlayDate => text().nullable()();
  TextColumn get dailyQuestDate => text().nullable()();
  IntColumn get dailyRoundsDone => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProfileRow')
class Profile extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get nameEn => text()();
  TextColumn get nameVi => text()();
  IntColumn get dailyLimitMin => integer()();
  BoolColumn get musicOn => boolean().withDefault(const Constant(true))();
  BoolColumn get testMode => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ItemStats, Sessions, Rewards, Profile])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 2: Sinh code drift**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: tạo `lib/core/db/database.g.dart`, không lỗi.

- [ ] **Step 3: Viết các lớp domain (chưa có logic)**

`lib/core/progress/item_stat.dart`:
```dart
enum AnswerOutcome { firstTry, retry, hinted }

class ItemStat {
  const ItemStat({required this.key, this.mastery = 0, this.correct = 0, this.wrong = 0, this.lastSeen});

  final String key;
  final int mastery;
  final int correct;
  final int wrong;
  final DateTime? lastSeen;
}
```

`lib/core/profile/names.dart`:
```dart
class Names {
  const Names({required this.en, required this.vi});

  final String en;
  final String vi;
}
```

`lib/core/rewards/reward_state.dart`:
```dart
class RewardState {
  const RewardState({
    this.snowflakesTotal = 0,
    this.castleLevel = 1,
    this.streakDays = 0,
    this.lastPlayDate,
    this.dailyQuestDate,
    this.dailyRoundsDone = 0,
  });

  final int snowflakesTotal;
  final int castleLevel;
  final int streakDays;
  final String? lastPlayDate;
  final String? dailyQuestDate;
  final int dailyRoundsDone;
}

class RewardOutcome {
  const RewardOutcome({
    required this.earned,
    required this.questCompleted,
    required this.previousLevel,
    required this.newLevel,
    required this.friendUnlocked,
    required this.state,
  });

  final int earned;
  final bool questCompleted;
  final int previousLevel;
  final int newLevel;
  final String? friendUnlocked;
  final RewardState state;

  bool get leveledUp => newLevel > previousLevel;
}
```

- [ ] **Step 4: Viết test store (failing)**

`test/core/db/stores_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/db/database.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('item stats are saved, updated and loaded by prefix', () async {
    final store = DriftItemStatsStore(db);
    final seen = DateTime(2026, 11, 2, 9, 30);
    await store.save(ItemStat(key: 'letter_en_upper:A', mastery: 2, correct: 3, wrong: 1, lastSeen: seen));
    await store.save(const ItemStat(key: 'word:cat', mastery: 1));
    await store.save(ItemStat(key: 'letter_en_upper:A', mastery: 3, correct: 4, wrong: 1, lastSeen: seen));

    final stats = await store.loadByPrefix('letter_en_');
    expect(stats.keys, ['letter_en_upper:A']);
    final a = stats['letter_en_upper:A']!;
    expect([a.mastery, a.correct, a.wrong], [3, 4, 1]);
    expect(a.lastSeen, seen);
  });

  test('reward store returns defaults first, then persists', () async {
    final store = DriftRewardStore(db);
    final initial = await store.load();
    expect(initial.snowflakesTotal, 0);
    expect(initial.castleLevel, 1);

    await store.save(const RewardState(
      snowflakesTotal: 42,
      castleLevel: 2,
      lastPlayDate: '2026-11-02',
      dailyQuestDate: '2026-11-02',
      dailyRoundsDone: 2,
    ));
    final loaded = await DriftRewardStore(db).load();
    expect(loaded.snowflakesTotal, 42);
    expect(loaded.castleLevel, 2);
    expect(loaded.dailyQuestDate, '2026-11-02');
    expect(loaded.dailyRoundsDone, 2);
  });

  test('session store appends records', () async {
    await DriftSessionStore(db).add(SessionRecord(
      date: '2026-11-02',
      game: 'find_letter',
      startedAt: DateTime(2026, 11, 2, 9),
      durationSec: 150,
      correct: 6,
      total: 8,
    ));
    final rows = await db.select(db.sessions).get();
    expect(rows.single.game, 'find_letter');
    expect(rows.single.durationSec, 150);
  });

  test('profile store inserts defaults once', () async {
    final store = DriftProfileStore(db);
    final first = await store.loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
    final second = await store.loadNames(const ProfileDefaults(nameEn: 'Other', nameVi: 'Khác', dailyLimitMin: 5));
    expect([first.en, first.vi], ['An', 'Xoài']);
    expect([second.en, second.vi], ['An', 'Xoài']);
  });
}
```

- [ ] **Step 5: Chạy test, xác nhận fail**

Run: `flutter test test/core/db/stores_test.dart`
Expected: FAIL — chưa có các file store.

- [ ] **Step 6: Viết các store**

`lib/core/progress/item_stats_store.dart`:
```dart
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'item_stat.dart';

abstract interface class ItemStatsStore {
  Future<Map<String, ItemStat>> loadByPrefix(String prefix);
  Future<void> save(ItemStat stat);
}

class DriftItemStatsStore implements ItemStatsStore {
  DriftItemStatsStore(this._db);

  final AppDatabase _db;

  @override
  Future<Map<String, ItemStat>> loadByPrefix(String prefix) async {
    final rows = await _db.select(_db.itemStats).get();
    return {
      for (final r in rows)
        if (r.itemKey.startsWith(prefix))
          r.itemKey: ItemStat(
            key: r.itemKey,
            mastery: r.mastery,
            correct: r.correct,
            wrong: r.wrong,
            lastSeen: r.lastSeen,
          ),
    };
  }

  @override
  Future<void> save(ItemStat stat) async {
    await _db.into(_db.itemStats).insertOnConflictUpdate(ItemStatsCompanion(
          itemKey: Value(stat.key),
          mastery: Value(stat.mastery),
          correct: Value(stat.correct),
          wrong: Value(stat.wrong),
          lastSeen: Value(stat.lastSeen),
        ));
  }
}
```

`lib/core/session/session_store.dart`:
```dart
import '../db/database.dart';

class SessionRecord {
  const SessionRecord({
    required this.date,
    required this.game,
    required this.startedAt,
    required this.durationSec,
    required this.correct,
    required this.total,
  });

  final String date;
  final String game;
  final DateTime startedAt;
  final int durationSec;
  final int correct;
  final int total;
}

abstract interface class SessionStore {
  Future<void> add(SessionRecord record);
}

class DriftSessionStore implements SessionStore {
  DriftSessionStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> add(SessionRecord r) async {
    await _db.into(_db.sessions).insert(SessionsCompanion.insert(
          date: r.date,
          game: r.game,
          startedAt: r.startedAt,
          durationSec: r.durationSec,
          correct: r.correct,
          total: r.total,
        ));
  }
}
```

`lib/core/profile/profile_store.dart`:
```dart
import 'package:drift/drift.dart';

import '../content/models.dart';
import '../db/database.dart';
import 'names.dart';

abstract interface class ProfileStore {
  /// Returns the stored names, creating the profile from [defaults] on first run.
  Future<Names> loadNames(ProfileDefaults defaults);
}

class DriftProfileStore implements ProfileStore {
  DriftProfileStore(this._db);

  final AppDatabase _db;

  @override
  Future<Names> loadNames(ProfileDefaults defaults) async {
    await _db.into(_db.profile).insert(
          ProfileCompanion.insert(
            nameEn: defaults.nameEn,
            nameVi: defaults.nameVi,
            dailyLimitMin: defaults.dailyLimitMin,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final row = await _db.select(_db.profile).getSingle();
    return Names(en: row.nameEn, vi: row.nameVi);
  }
}
```

`lib/core/rewards/reward_store.dart`:
```dart
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'reward_state.dart';

abstract interface class RewardStore {
  Future<RewardState> load();
  Future<void> save(RewardState state);
}

class DriftRewardStore implements RewardStore {
  DriftRewardStore(this._db);

  final AppDatabase _db;

  @override
  Future<RewardState> load() async {
    await _db.into(_db.rewards).insert(RewardsCompanion.insert(), mode: InsertMode.insertOrIgnore);
    final row = await (_db.select(_db.rewards)..where((t) => t.id.equals(1))).getSingle();
    return RewardState(
      snowflakesTotal: row.snowflakesTotal,
      castleLevel: row.castleLevel,
      streakDays: row.streakDays,
      lastPlayDate: row.lastPlayDate,
      dailyQuestDate: row.dailyQuestDate,
      dailyRoundsDone: row.dailyRoundsDone,
    );
  }

  @override
  Future<void> save(RewardState s) async {
    await _db.into(_db.rewards).insertOnConflictUpdate(RewardsCompanion(
          id: const Value(1),
          snowflakesTotal: Value(s.snowflakesTotal),
          castleLevel: Value(s.castleLevel),
          streakDays: Value(s.streakDays),
          lastPlayDate: Value(s.lastPlayDate),
          dailyQuestDate: Value(s.dailyQuestDate),
          dailyRoundsDone: Value(s.dailyRoundsDone),
        ));
  }
}
```

- [ ] **Step 7: Viết fake dùng chung cho test** — `test/support/fakes.dart`

```dart
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';
import 'package:xoai_castle/core/voice/tts_engine.dart';

class FakeTts implements TtsEngine {
  final calls = <String>[];
  final spoken = <({String text, String lang})>[];

  List<String> get texts => [for (final s in spoken) s.text];

  @override
  Future<void> speak(String text, {required String lang}) async {
    calls.add('speak');
    spoken.add((text: text, lang: lang));
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

class MemoryItemStatsStore implements ItemStatsStore {
  final stats = <String, ItemStat>{};

  @override
  Future<Map<String, ItemStat>> loadByPrefix(String prefix) async =>
      {for (final e in stats.entries) if (e.key.startsWith(prefix)) e.key: e.value};

  @override
  Future<void> save(ItemStat stat) async => stats[stat.key] = stat;
}

class FailingItemStatsStore implements ItemStatsStore {
  @override
  Future<Map<String, ItemStat>> loadByPrefix(String prefix) => Future.error(StateError('db broken'));

  @override
  Future<void> save(ItemStat stat) => Future.error(StateError('db broken'));
}

class MemorySessionStore implements SessionStore {
  final records = <SessionRecord>[];

  @override
  Future<void> add(SessionRecord record) async => records.add(record);
}

class MemoryRewardStore implements RewardStore {
  MemoryRewardStore([this.state = const RewardState()]);

  RewardState state;

  @override
  Future<RewardState> load() async => state;

  @override
  Future<void> save(RewardState s) async => state = s;
}
```

`FakeTts` cần interface `TtsEngine`; tạo luôn ở bước này — `lib/core/voice/tts_engine.dart`:
```dart
abstract interface class TtsEngine {
  /// Speaks [text] in [lang] ("en" or "vi"); completes when speech ends or is stopped.
  Future<void> speak(String text, {required String lang});

  Future<void> stop();
}
```

- [ ] **Step 8: Chạy test**

```bash
flutter test test/core/db/stores_test.dart
flutter analyze --no-fatal-infos
```
Expected: PASS; analyze sạch.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: drift database and stores for stats, sessions, rewards, profile"
```

---

### Task 3: Mức thuộc và chọn câu hỏi

**Files:**
- Modify: `lib/core/progress/item_stat.dart`
- Create: `lib/core/progress/question_picker.dart`
- Test: `test/core/progress/item_stat_test.dart`, `test/core/progress/question_picker_test.dart`

**Interfaces:**
- Consumes: `ItemStat`, `AnswerOutcome` (Task 2).
- Produces:
  - `ItemStat ItemStat.apply(AnswerOutcome outcome, DateTime now)`
  - `class QuestionPicker { QuestionPicker(Random random); List<String> pick({required List<String> candidates, required Map<String, ItemStat> stats, required int count, int maxNew = 2}); }`

- [ ] **Step 1: Viết test (failing)**

`test/core/progress/item_stat_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';

void main() {
  final now = DateTime(2026, 11, 2, 9);

  test('firstTry raises mastery and counts correct', () {
    final s = const ItemStat(key: 'k', mastery: 1).apply(AnswerOutcome.firstTry, now);
    expect([s.mastery, s.correct, s.wrong], [2, 1, 0]);
    expect(s.lastSeen, now);
    expect(s.key, 'k');
  });

  test('mastery is capped at 4', () {
    expect(const ItemStat(key: 'k', mastery: 4).apply(AnswerOutcome.firstTry, now).mastery, 4);
  });

  test('retry keeps mastery and counts wrong', () {
    final s = const ItemStat(key: 'k', mastery: 2).apply(AnswerOutcome.retry, now);
    expect([s.mastery, s.correct, s.wrong], [2, 0, 1]);
  });

  test('hinted lowers mastery but not below 0', () {
    expect(const ItemStat(key: 'k', mastery: 2).apply(AnswerOutcome.hinted, now).mastery, 1);
    expect(const ItemStat(key: 'k').apply(AnswerOutcome.hinted, now).mastery, 0);
  });
}
```

`test/core/progress/question_picker_test.dart`:
```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';

void main() {
  final letters = [for (final c in 'ABCDEFGHIJ'.split('')) 'k:$c'];
  Map<String, ItemStat> seenAll(int mastery) => {for (final k in letters) k: ItemStat(key: k, mastery: mastery)};

  test('returns the requested number of keys from the candidates', () {
    final picked = QuestionPicker(Random(1)).pick(candidates: letters, stats: seenAll(1), count: 8);
    expect(picked, hasLength(8));
    expect(letters, containsAll(picked));
  });

  test('never repeats the same key twice in a row', () {
    for (var seed = 0; seed < 50; seed++) {
      final picked = QuestionPicker(Random(seed)).pick(candidates: letters, stats: seenAll(2), count: 8);
      for (var i = 1; i < picked.length; i++) {
        expect(picked[i], isNot(picked[i - 1]));
      }
    }
  });

  test('introduces at most maxNew unseen keys per round', () {
    for (var seed = 0; seed < 50; seed++) {
      final picked = QuestionPicker(Random(seed)).pick(candidates: letters, stats: const {}, count: 8);
      expect(picked.toSet().length, lessThanOrEqualTo(2));
    }
  });

  test('mixes seen keys with at most two new ones', () {
    final stats = {for (final k in letters.take(5)) k: ItemStat(key: k, mastery: 1)};
    final picked = QuestionPicker(Random(3)).pick(candidates: letters, stats: stats, count: 8);
    final fresh = picked.where((k) => !stats.containsKey(k)).toSet();
    expect(fresh.length, lessThanOrEqualTo(2));
  });

  test('prefers keys with low mastery', () {
    final stats = {
      'a': const ItemStat(key: 'a', mastery: 0),
      'b': const ItemStat(key: 'b', mastery: 4),
      'c': const ItemStat(key: 'c', mastery: 4),
    };
    final picked = QuestionPicker(Random(7)).pick(candidates: ['a', 'b', 'c'], stats: stats, count: 3000);
    final a = picked.where((k) => k == 'a').length;
    final b = picked.where((k) => k == 'b').length;
    expect(a, greaterThan(b * 1.4));
  });

  test('a single candidate is repeated', () {
    expect(QuestionPicker(Random(1)).pick(candidates: ['x'], stats: const {}, count: 3), ['x', 'x', 'x']);
  });

  test('no candidates gives an empty list', () {
    expect(QuestionPicker(Random(1)).pick(candidates: const [], stats: const {}, count: 3), isEmpty);
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `flutter test test/core/progress`
Expected: FAIL — chưa có `apply` và `question_picker.dart`.

- [ ] **Step 3: Thêm `apply` vào `lib/core/progress/item_stat.dart`**

Thay toàn bộ file bằng:
```dart
import 'dart:math';

enum AnswerOutcome { firstTry, retry, hinted }

class ItemStat {
  const ItemStat({required this.key, this.mastery = 0, this.correct = 0, this.wrong = 0, this.lastSeen});

  final String key;
  final int mastery;
  final int correct;
  final int wrong;
  final DateTime? lastSeen;

  static const maxMastery = 4;

  ItemStat apply(AnswerOutcome outcome, DateTime now) {
    final delta = switch (outcome) {
      AnswerOutcome.firstTry => 1,
      AnswerOutcome.retry => 0,
      AnswerOutcome.hinted => -1,
    };
    final first = outcome == AnswerOutcome.firstTry;
    return ItemStat(
      key: key,
      mastery: max(0, min(maxMastery, mastery + delta)),
      correct: correct + (first ? 1 : 0),
      wrong: wrong + (first ? 0 : 1),
      lastSeen: now,
    );
  }
}
```

- [ ] **Step 4: Viết `lib/core/progress/question_picker.dart`**

```dart
import 'dart:math';

import 'item_stat.dart';

class QuestionPicker {
  QuestionPicker(this._random);

  final Random _random;

  /// Picks [count] keys from [candidates]. Keys with lower mastery are more
  /// likely (weight = 5 − mastery; unseen keys count as mastery 0). At most
  /// [maxNew] distinct unseen keys are used, and a key never appears twice in a row.
  List<String> pick({
    required List<String> candidates,
    required Map<String, ItemStat> stats,
    required int count,
    int maxNew = 2,
  }) {
    if (candidates.isEmpty) return const [];
    final picked = <String>[];
    final newUsed = <String>{};
    for (var i = 0; i < count; i++) {
      final last = picked.isEmpty ? null : picked.last;
      bool allowed(String k) =>
          k != last && (stats.containsKey(k) || newUsed.contains(k) || newUsed.length < maxNew);
      var pool = candidates.where(allowed).toList();
      if (pool.isEmpty) pool = candidates.where((k) => k != last).toList();
      if (pool.isEmpty) pool = candidates;
      final key = _weighted(pool, stats);
      if (!stats.containsKey(key)) newUsed.add(key);
      picked.add(key);
    }
    return picked;
  }

  String _weighted(List<String> pool, Map<String, ItemStat> stats) {
    final weights = [for (final k in pool) 5 - (stats[k]?.mastery ?? 0)];
    final total = weights.fold<int>(0, (a, b) => a + b);
    var roll = _random.nextInt(total);
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll < 0) return pool[i];
    }
    return pool.last;
  }
}
```

- [ ] **Step 5: Chạy test**

Run: `flutter test test/core/progress`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: mastery rules and weighted question picker"
```

---

### Task 4: Luật phần thưởng và RewardController

**Files:**
- Create: `lib/core/time.dart`, `lib/core/rewards/reward_rules.dart`, `lib/app/config.dart`, `lib/app/providers.dart`, `lib/app/reward_controller.dart`
- Test: `test/core/rewards/reward_rules_test.dart`, `test/app/reward_controller_test.dart`

**Interfaces:**
- Consumes: `CastleLevel`, `ContentBundle` (Task 1); `RewardState`, `RewardOutcome`, `RewardStore`, stores khác, `AppDatabase` (Task 2); `TtsEngine` (Task 2).
- Produces:
  - `String dayKey(DateTime d)` → `yyyy-MM-dd`
  - `const kRoundBonus = 5, kQuestRounds = 3, kQuestBonus = 20`
  - `int castleLevelFor(int total, List<CastleLevel> levels)`; `int roundsToday(RewardState s, String today)`; `RewardOutcome applyRound(RewardState s, {required int firstTryCorrect, required String today, required List<CastleLevel> levels})`
  - `const kGithubRepo = 'nguyentienloc/mango-game'`
  - Providers trong `lib/app/providers.dart`: `contentProvider`, `databaseProvider`, `voiceProvider`, `appVersionProvider`, `clockProvider` (`DateTime Function()`), `randomProvider` (`Random`), `itemStatsStoreProvider`, `sessionStoreProvider`, `rewardStoreProvider`, `appUpdaterProvider`, `updateCheckProvider` — hai provider cuối thêm ở Task 7
  - `rewardStateProvider` (`AsyncNotifierProvider<RewardController, RewardState>`); `Future<RewardOutcome> RewardController.completeRound(int firstTryCorrect)`

Lưu ý: `voiceProvider` cần kiểu `VoiceService` (Task 5). Ở task này khai báo `providers.dart` **không có** `voiceProvider`, `appUpdaterProvider`, `updateCheckProvider`; Task 5 và Task 7 sẽ thêm vào.

- [ ] **Step 1: Viết test luật thưởng (failing)**

`test/core/rewards/reward_rules_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_rules.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/time.dart';

const levels = [
  CastleLevel(level: 1, snowflakes: 0),
  CastleLevel(level: 2, snowflakes: 20, friend: 'olaf'),
  CastleLevel(level: 3, snowflakes: 50),
  CastleLevel(level: 4, snowflakes: 100, friend: 'anna'),
  CastleLevel(level: 5, snowflakes: 170),
  CastleLevel(level: 6, snowflakes: 260, friend: 'sven'),
  CastleLevel(level: 7, snowflakes: 380),
  CastleLevel(level: 8, snowflakes: 530, friend: 'kristoff'),
];

void main() {
  test('dayKey formats local dates', () {
    expect(dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('castleLevelFor picks the highest reached level', () {
    expect(castleLevelFor(0, levels), 1);
    expect(castleLevelFor(19, levels), 1);
    expect(castleLevelFor(20, levels), 2);
    expect(castleLevelFor(529, levels), 7);
    expect(castleLevelFor(99999, levels), 8);
  });

  test('a round earns one per first-try answer plus the round bonus', () {
    final o = applyRound(const RewardState(), firstTryCorrect: 6, today: '2026-11-02', levels: levels);
    expect(o.earned, 11);
    expect(o.questCompleted, isFalse);
    expect(o.state.snowflakesTotal, 11);
    expect(o.state.dailyRoundsDone, 1);
    expect(o.state.dailyQuestDate, '2026-11-02');
    expect(o.state.lastPlayDate, '2026-11-02');
  });

  test('the third round of the day completes the quest', () {
    const s = RewardState(snowflakesTotal: 30, castleLevel: 2, dailyQuestDate: '2026-11-02', dailyRoundsDone: 2);
    final o = applyRound(s, firstTryCorrect: 8, today: '2026-11-02', levels: levels);
    expect(o.questCompleted, isTrue);
    expect(o.earned, 8 + kRoundBonus + kQuestBonus);
    expect(o.state.dailyRoundsDone, 3);
  });

  test('a fourth round does not complete the quest again', () {
    const s = RewardState(dailyQuestDate: '2026-11-02', dailyRoundsDone: 3);
    final o = applyRound(s, firstTryCorrect: 0, today: '2026-11-02', levels: levels);
    expect(o.questCompleted, isFalse);
    expect(o.earned, kRoundBonus);
  });

  test('a new day resets the daily round count', () {
    const s = RewardState(dailyQuestDate: '2026-11-01', dailyRoundsDone: 2);
    final o = applyRound(s, firstTryCorrect: 0, today: '2026-11-02', levels: levels);
    expect(o.questCompleted, isFalse);
    expect(o.state.dailyRoundsDone, 1);
  });

  test('crossing a level with a friend unlocks it', () {
    const s = RewardState(snowflakesTotal: 15);
    final o = applyRound(s, firstTryCorrect: 0, today: '2026-11-02', levels: levels);
    expect(o.state.snowflakesTotal, 20);
    expect(o.previousLevel, 1);
    expect(o.newLevel, 2);
    expect(o.leveledUp, isTrue);
    expect(o.friendUnlocked, 'olaf');
  });

  test('crossing a level without a friend unlocks nobody', () {
    const s = RewardState(snowflakesTotal: 45, castleLevel: 2);
    final o = applyRound(s, firstTryCorrect: 0, today: '2026-11-02', levels: levels);
    expect(o.newLevel, 3);
    expect(o.friendUnlocked, isNull);
  });

  test('roundsToday ignores counts from other days', () {
    const s = RewardState(dailyQuestDate: '2026-11-01', dailyRoundsDone: 2);
    expect(roundsToday(s, '2026-11-01'), 2);
    expect(roundsToday(s, '2026-11-02'), 0);
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `flutter test test/core/rewards/reward_rules_test.dart`
Expected: FAIL — chưa có `reward_rules.dart`, `time.dart`.

- [ ] **Step 3: Viết `lib/core/time.dart` và `lib/core/rewards/reward_rules.dart`**

`lib/core/time.dart`:
```dart
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
```

`lib/core/rewards/reward_rules.dart`:
```dart
import '../content/models.dart';
import 'reward_state.dart';

const kRoundBonus = 5;
const kQuestRounds = 3;

/// Gift for finishing the daily quest while there are no stickers yet.
const kQuestBonus = 20;

/// [levels] must be sorted by snowflakes ascending.
int castleLevelFor(int total, List<CastleLevel> levels) {
  var level = 1;
  for (final l in levels) {
    if (total >= l.snowflakes) level = l.level;
  }
  return level;
}

int roundsToday(RewardState s, String today) => s.dailyQuestDate == today ? s.dailyRoundsDone : 0;

RewardOutcome applyRound(
  RewardState s, {
  required int firstTryCorrect,
  required String today,
  required List<CastleLevel> levels,
}) {
  final rounds = roundsToday(s, today) + 1;
  final questCompleted = rounds == kQuestRounds;
  final earned = firstTryCorrect + kRoundBonus + (questCompleted ? kQuestBonus : 0);
  final total = s.snowflakesTotal + earned;
  final newLevel = castleLevelFor(total, levels);
  String? friend;
  for (final l in levels) {
    if (l.level > s.castleLevel && l.level <= newLevel && l.friend != null) friend = l.friend;
  }
  return RewardOutcome(
    earned: earned,
    questCompleted: questCompleted,
    previousLevel: s.castleLevel,
    newLevel: newLevel,
    friendUnlocked: friend,
    state: RewardState(
      snowflakesTotal: total,
      castleLevel: newLevel,
      streakDays: s.streakDays,
      lastPlayDate: today,
      dailyQuestDate: today,
      dailyRoundsDone: rounds,
    ),
  );
}
```

- [ ] **Step 4: Chạy test luật thưởng**

Run: `flutter test test/core/rewards/reward_rules_test.dart`
Expected: PASS.

- [ ] **Step 5: Viết test RewardController (failing)**

`test/app/reward_controller_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/app/providers.dart';
import 'package:xoai_castle/app/reward_controller.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';

import '../support/fakes.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  test('completeRound applies rules, saves and updates state', () async {
    final store = MemoryRewardStore();
    final container = ProviderContainer(overrides: [
      contentProvider.overrideWithValue(content),
      rewardStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 9)),
    ]);
    addTearDown(container.dispose);

    await container.read(rewardStateProvider.future);
    final outcome = await container.read(rewardStateProvider.notifier).completeRound(6);

    expect(outcome.earned, 11);
    expect(store.state.snowflakesTotal, 11);
    expect(store.state.dailyQuestDate, '2026-11-02');
    expect(container.read(rewardStateProvider).value!.snowflakesTotal, 11);
  });
}
```

- [ ] **Step 6: Chạy test, xác nhận fail**

Run: `flutter test test/app/reward_controller_test.dart`
Expected: FAIL — chưa có `providers.dart`, `reward_controller.dart`.

- [ ] **Step 7: Viết config, providers, controller**

`lib/app/config.dart`:
```dart
/// GitHub repo (owner/name) that hosts releases and content.
const kGithubRepo = 'nguyentienloc/mango-game';
```

`lib/app/providers.dart`:
```dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/models.dart';
import '../core/db/database.dart';
import '../core/progress/item_stats_store.dart';
import '../core/rewards/reward_store.dart';
import '../core/session/session_store.dart';

/// Overridden in main() after bootstrapping.
final contentProvider = Provider<ContentBundle>((ref) => throw UnimplementedError('contentProvider'));
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('databaseProvider'));
final appVersionProvider = Provider<String>((ref) => throw UnimplementedError('appVersionProvider'));

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final randomProvider = Provider<Random>((ref) => Random());

final itemStatsStoreProvider = Provider<ItemStatsStore>((ref) => DriftItemStatsStore(ref.watch(databaseProvider)));
final sessionStoreProvider = Provider<SessionStore>((ref) => DriftSessionStore(ref.watch(databaseProvider)));
final rewardStoreProvider = Provider<RewardStore>((ref) => DriftRewardStore(ref.watch(databaseProvider)));
```

`lib/app/reward_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rewards/reward_rules.dart';
import '../core/rewards/reward_state.dart';
import '../core/time.dart';
import 'providers.dart';

final rewardStateProvider = AsyncNotifierProvider<RewardController, RewardState>(RewardController.new);

class RewardController extends AsyncNotifier<RewardState> {
  @override
  Future<RewardState> build() => ref.watch(rewardStoreProvider).load();

  Future<RewardOutcome> completeRound(int firstTryCorrect) async {
    final current = state.value ?? await future;
    final outcome = applyRound(
      current,
      firstTryCorrect: firstTryCorrect,
      today: dayKey(ref.read(clockProvider)()),
      levels: ref.read(contentProvider).castle,
    );
    await ref.read(rewardStoreProvider).save(outcome.state);
    state = AsyncData(outcome.state);
    return outcome;
  }
}
```

- [ ] **Step 8: Chạy test**

```bash
flutter test test/core/rewards test/app
flutter analyze --no-fatal-infos
```
Expected: PASS; analyze sạch.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: reward rules (snowflakes, castle levels, daily quest) and controller"
```

---

### Task 5: Giọng nói — VoiceService + FlutterTtsEngine

**Files:**
- Create: `lib/core/voice/voice_service.dart`, `lib/core/voice/flutter_tts_engine.dart`
- Modify: `lib/app/providers.dart` (thêm `voiceProvider`)
- Test: `test/core/voice/voice_service_test.dart`

**Interfaces:**
- Consumes: `TtsEngine` (Task 2), `Phrase` (Task 1), `Names` (Task 2).
- Produces:
  - `class VoiceService { VoiceService({required TtsEngine tts, required Map<String, Phrase> phrases, required Names names, Random? random}); String render(String template, [Map<String, String> vars]); Future<void> say(String phraseId, {Map<String, String> vars}); Future<void> sayGroup(String group, {Map<String, String> vars}); Future<void> stop(); }`
  - `class FlutterTtsEngine implements TtsEngine { static Future<FlutterTtsEngine> create(); }`
  - `final voiceProvider = Provider<VoiceService>(...)` (override trong main)

- [ ] **Step 1: Viết test (failing)**

`test/core/voice/voice_service_test.dart`:
```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/voice_service.dart';

import '../../support/fakes.dart';

const phrases = {
  'hello': Phrase(id: 'hello', lang: 'vi', text: 'Chào {name_vi}!', group: 'greet'),
  'find': Phrase(id: 'find', lang: 'en', text: 'Find the letter {letter}, {name_en}!', group: 'instruction'),
  'try_a': Phrase(id: 'try_a', lang: 'en', text: 'Try again!', group: 'try_again'),
  'try_b': Phrase(id: 'try_b', lang: 'vi', text: 'Thử lại nha!', group: 'try_again'),
};

VoiceService voice(FakeTts tts, [int seed = 1]) =>
    VoiceService(tts: tts, phrases: phrases, names: const Names(en: 'An', vi: 'Xoài'), random: Random(seed));

void main() {
  test('render fills names and vars and keeps unknown placeholders', () {
    final v = voice(FakeTts());
    expect(v.render('Hi {name_en}, {name_vi}, {letter}', {'letter': 'B'}), 'Hi An, Xoài, B');
    expect(v.render('{nope}'), '{nope}');
  });

  test('say stops current speech then speaks the phrase in its language', () async {
    final tts = FakeTts();
    await voice(tts).say('find', vars: {'letter': 'B'});
    expect(tts.calls, ['stop', 'speak']);
    expect(tts.spoken.single, (text: 'Find the letter B, An!', lang: 'en'));
  });

  test('say with Vietnamese phrase uses vi', () async {
    final tts = FakeTts();
    await voice(tts).say('hello');
    expect(tts.spoken.single, (text: 'Chào Xoài!', lang: 'vi'));
  });

  test('say throws for unknown phrase ids', () {
    expect(() => voice(FakeTts()).say('missing'), throwsArgumentError);
  });

  test('sayGroup only picks phrases from the group and varies them', () async {
    final seen = <String>{};
    for (var seed = 0; seed < 20; seed++) {
      final tts = FakeTts();
      await voice(tts, seed).sayGroup('try_again');
      seen.add(tts.texts.single);
    }
    expect(seen, {'Try again!', 'Thử lại nha!'});
  });

  test('sayGroup throws for unknown groups', () {
    expect(() => voice(FakeTts()).sayGroup('nope'), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `flutter test test/core/voice`
Expected: FAIL — chưa có `voice_service.dart`.

- [ ] **Step 3: Viết `lib/core/voice/voice_service.dart`**

```dart
import 'dart:math';

import '../content/models.dart';
import '../profile/names.dart';
import 'tts_engine.dart';

/// Single entry point for everything the game says out loud.
class VoiceService {
  VoiceService({
    required TtsEngine tts,
    required Map<String, Phrase> phrases,
    required Names names,
    Random? random,
  })  : _tts = tts,
        _phrases = phrases,
        _names = names,
        _random = random ?? Random();

  final TtsEngine _tts;
  final Map<String, Phrase> _phrases;
  final Names _names;
  final Random _random;

  static final _placeholder = RegExp(r'\{(\w+)\}');

  String render(String template, [Map<String, String> vars = const {}]) {
    final all = {'name_en': _names.en, 'name_vi': _names.vi, ...vars};
    return template.replaceAllMapped(_placeholder, (m) => all[m[1]] ?? m[0]!);
  }

  Future<void> say(String phraseId, {Map<String, String> vars = const {}}) {
    final phrase = _phrases[phraseId];
    if (phrase == null) throw ArgumentError.value(phraseId, 'phraseId', 'Không có câu này');
    return _speak(phrase, vars);
  }

  Future<void> sayGroup(String group, {Map<String, String> vars = const {}}) {
    final options = _phrases.values.where((p) => p.group == group).toList();
    if (options.isEmpty) throw ArgumentError.value(group, 'group', 'Không có nhóm câu này');
    return _speak(options[_random.nextInt(options.length)], vars);
  }

  Future<void> stop() => _tts.stop();

  Future<void> _speak(Phrase phrase, Map<String, String> vars) async {
    await _tts.stop();
    await _tts.speak(render(phrase.text, vars), lang: phrase.lang);
  }
}
```

- [ ] **Step 4: Viết `lib/core/voice/flutter_tts_engine.dart`**

```dart
import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Android Google TTS. Completion is tracked with our own completer so that
/// stop() or an engine error always ends the pending speak() future.
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine._(this._tts);

  final FlutterTts _tts;
  Completer<void>? _current;
  String? _locale;

  static Future<FlutterTtsEngine> create() async {
    final tts = FlutterTts();
    final engine = FlutterTtsEngine._(tts);
    await tts.awaitSpeakCompletion(false);
    await tts.setSpeechRate(0.42);
    await tts.setPitch(1.15);
    tts.setCompletionHandler(engine._finish);
    tts.setCancelHandler(engine._finish);
    tts.setErrorHandler((_) => engine._finish());
    return engine;
  }

  void _finish() {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> speak(String text, {required String lang}) async {
    _finish();
    final locale = lang == 'vi' ? 'vi-VN' : 'en-US';
    if (_locale != locale) {
      await _tts.setLanguage(locale);
      _locale = locale;
    }
    final c = Completer<void>();
    _current = c;
    await _tts.speak(text);
    await c.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _finish();
  }
}
```

- [ ] **Step 5: Thêm `voiceProvider` vào `lib/app/providers.dart`**

Thêm import:
```dart
import '../core/voice/voice_service.dart';
```
Thêm sau `appVersionProvider`:
```dart
final voiceProvider = Provider<VoiceService>((ref) => throw UnimplementedError('voiceProvider'));
```

- [ ] **Step 6: Chạy test**

```bash
flutter test test/core/voice
flutter analyze --no-fatal-infos
```
Expected: PASS; analyze sạch.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: VoiceService with phrase templates and flutter_tts engine"
```

---

### Task 6: Logic trò Tìm chữ cái

**Files:**
- Create: `lib/features/games/find_letter/find_letter_logic.dart`
- Test: `test/features/find_letter/find_letter_logic_test.dart`

**Interfaces:**
- Consumes: `LetterItem` (Task 1), `ItemStat`, `AnswerOutcome`, `QuestionPicker` (Task 3).
- Produces:
  - `enum FindLetterMode { upper, lower, match }`
  - `String findLetterKey(FindLetterMode mode, LetterItem item)` — `letter_en_upper:B`, `letter_en_lower:b`, `letter_en_match:B`
  - `FindLetterMode highestUnlockedMode(List<LetterItem> letters, Map<String, ItemStat> stats)`
  - `class FindLetterQuestion { FindLetterMode mode; LetterItem item; List<String> options; String get key; String get answer; String? get shownLetter; String get promptPhraseId; Map<String, String> get promptVars; }`
  - `List<FindLetterQuestion> buildFindLetterRound({required List<LetterItem> letters, required Map<String, ItemStat> stats, required QuestionPicker picker, required Random random, int count = 8, int reviewCount = 2})`
  - `enum TapResult { correct, wrong, ignored }`
  - `class FindLetterSession { FindLetterSession(List<FindLetterQuestion>); List<FindLetterQuestion> questions; FindLetterQuestion get current; int get index; bool get isFinished; bool get showHint; List<AnswerOutcome> outcomes; int get firstTryCount; TapResult tap(String option); void next(); }`

- [ ] **Step 1: Viết test (failing)**

`test/features/find_letter/find_letter_logic_test.dart`:
```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/find_letter/find_letter_logic.dart';

final letters = [
  for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) LetterItem(char: c, exampleWord: 'W$c', exampleEmoji: '⭐'),
];

Map<String, ItemStat> mastered(FindLetterMode mode, int n) => {
      for (final l in letters.take(n)) findLetterKey(mode, l): ItemStat(key: findLetterKey(mode, l), mastery: 2),
    };

List<FindLetterQuestion> round(Map<String, ItemStat> stats, [int seed = 1]) => buildFindLetterRound(
      letters: letters,
      stats: stats,
      picker: QuestionPicker(Random(seed)),
      random: Random(seed),
    );

void main() {
  group('keys and modes', () {
    test('keys per mode', () {
      final b = letters[1];
      expect(findLetterKey(FindLetterMode.upper, b), 'letter_en_upper:B');
      expect(findLetterKey(FindLetterMode.lower, b), 'letter_en_lower:b');
      expect(findLetterKey(FindLetterMode.match, b), 'letter_en_match:B');
    });

    test('unlocks lower case after 20 mastered upper case letters', () {
      expect(highestUnlockedMode(letters, const {}), FindLetterMode.upper);
      expect(highestUnlockedMode(letters, mastered(FindLetterMode.upper, 19)), FindLetterMode.upper);
      expect(highestUnlockedMode(letters, mastered(FindLetterMode.upper, 20)), FindLetterMode.lower);
    });

    test('unlocks matching after 20 mastered lower case letters', () {
      final stats = {...mastered(FindLetterMode.upper, 20), ...mastered(FindLetterMode.lower, 20)};
      expect(highestUnlockedMode(letters, stats), FindLetterMode.match);
    });
  });

  group('round building', () {
    test('fresh player gets 8 upper-case questions with 3 unique options', () {
      final qs = round(const {});
      expect(qs, hasLength(8));
      for (final q in qs) {
        expect(q.mode, FindLetterMode.upper);
        expect(q.options, hasLength(3));
        expect(q.options.toSet(), hasLength(3));
        expect(q.options, contains(q.answer));
        expect(q.answer, q.item.char);
        expect(q.shownLetter, isNull);
        expect(q.promptPhraseId, 'find_letter_prompt');
        expect(q.promptVars, {'letter': q.item.char});
      }
      for (var i = 1; i < qs.length; i++) {
        expect(qs[i].key, isNot(qs[i - 1].key));
      }
    });

    test('lower mode mixes in two upper-case review questions', () {
      final qs = round(mastered(FindLetterMode.upper, 20));
      expect(qs.where((q) => q.mode == FindLetterMode.lower), hasLength(6));
      expect(qs.where((q) => q.mode == FindLetterMode.upper), hasLength(2));
      final lower = qs.firstWhere((q) => q.mode == FindLetterMode.lower);
      expect(lower.answer, lower.item.lower);
      expect(lower.options.every((o) => o == o.toLowerCase()), isTrue);
    });

    test('match mode shows the capital and offers 4 lower-case options', () {
      final stats = {...mastered(FindLetterMode.upper, 20), ...mastered(FindLetterMode.lower, 20)};
      final q = round(stats).firstWhere((q) => q.mode == FindLetterMode.match);
      expect(q.options, hasLength(4));
      expect(q.shownLetter, q.item.char);
      expect(q.answer, q.item.lower);
      expect(q.promptPhraseId, 'find_letter_small_prompt');
      expect(q.promptVars, {'letter': q.item.lower});
    });
  });

  group('session', () {
    FindLetterSession session() => FindLetterSession(round(const {}));

    test('correct first tap is firstTry', () {
      final s = session();
      expect(s.tap(s.current.answer), TapResult.correct);
      expect(s.outcomes, [AnswerOutcome.firstTry]);
    });

    test('one wrong tap then correct is retry', () {
      final s = session();
      final wrong = s.current.options.firstWhere((o) => o != s.current.answer);
      expect(s.tap(wrong), TapResult.wrong);
      expect(s.showHint, isFalse);
      s.tap(s.current.answer);
      expect(s.outcomes, [AnswerOutcome.retry]);
    });

    test('two wrong taps show the hint and the answer counts as hinted', () {
      final s = session();
      final wrong = s.current.options.firstWhere((o) => o != s.current.answer);
      s.tap(wrong);
      s.tap(wrong);
      expect(s.showHint, isTrue);
      s.tap(s.current.answer);
      expect(s.outcomes, [AnswerOutcome.hinted]);
    });

    test('taps after a correct answer are ignored until next()', () {
      final s = session();
      s.tap(s.current.answer);
      expect(s.tap(s.current.answer), TapResult.ignored);
      expect(s.outcomes, hasLength(1));
      s.next();
      expect(s.index, 1);
      expect(s.showHint, isFalse);
    });

    test('finishes after the last question and counts first tries', () {
      final s = session();
      for (var i = 0; i < 8; i++) {
        if (i.isEven) s.tap(s.current.options.firstWhere((o) => o != s.current.answer));
        s.tap(s.current.answer);
        s.next();
      }
      expect(s.isFinished, isTrue);
      expect(s.firstTryCount, 4);
      expect(s.tap('A'), TapResult.ignored);
    });
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `flutter test test/features/find_letter/find_letter_logic_test.dart`
Expected: FAIL — chưa có `find_letter_logic.dart`.

- [ ] **Step 3: Viết `lib/features/games/find_letter/find_letter_logic.dart`**

```dart
import 'dart:math';

import '../../../core/content/models.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';

enum FindLetterMode { upper, lower, match }

const kUnlockCount = 20;
const kUnlockMastery = 2;

String findLetterKey(FindLetterMode mode, LetterItem item) => switch (mode) {
      FindLetterMode.upper => 'letter_en_upper:${item.char}',
      FindLetterMode.lower => 'letter_en_lower:${item.lower}',
      FindLetterMode.match => 'letter_en_match:${item.char}',
    };

FindLetterMode highestUnlockedMode(List<LetterItem> letters, Map<String, ItemStat> stats) {
  int mastered(FindLetterMode m) =>
      letters.where((l) => (stats[findLetterKey(m, l)]?.mastery ?? 0) >= kUnlockMastery).length;
  if (mastered(FindLetterMode.upper) < kUnlockCount) return FindLetterMode.upper;
  if (mastered(FindLetterMode.lower) < kUnlockCount) return FindLetterMode.lower;
  return FindLetterMode.match;
}

class FindLetterQuestion {
  const FindLetterQuestion({required this.mode, required this.item, required this.options});

  final FindLetterMode mode;
  final LetterItem item;

  /// Letters written on the falling snowflakes, answer included.
  final List<String> options;

  String get key => findLetterKey(mode, item);
  String get answer => mode == FindLetterMode.upper ? item.char : item.lower;

  /// Big capital shown on screen in match mode.
  String? get shownLetter => mode == FindLetterMode.match ? item.char : null;

  String get promptPhraseId => mode == FindLetterMode.match ? 'find_letter_small_prompt' : 'find_letter_prompt';
  Map<String, String> get promptVars => {'letter': answer};
}

List<FindLetterQuestion> buildFindLetterRound({
  required List<LetterItem> letters,
  required Map<String, ItemStat> stats,
  required QuestionPicker picker,
  required Random random,
  int count = 8,
  int reviewCount = 2,
}) {
  final mode = highestUnlockedMode(letters, stats);
  final review = mode == FindLetterMode.upper ? 0 : reviewCount;
  final previous = mode == FindLetterMode.match ? FindLetterMode.lower : FindLetterMode.upper;

  List<FindLetterQuestion> make(FindLetterMode m, int n) {
    final byKey = {for (final l in letters) findLetterKey(m, l): l};
    final keys = picker.pick(candidates: byKey.keys.toList(), stats: stats, count: n);
    final optionCount = m == FindLetterMode.match ? 4 : 3;
    return [for (final k in keys) _question(m, byKey[k]!, letters, optionCount, random)];
  }

  final questions = make(mode, count - review);
  for (final q in make(previous, review)) {
    questions.insert(random.nextInt(questions.length + 1), q);
  }
  return questions;
}

FindLetterQuestion _question(
  FindLetterMode mode,
  LetterItem item,
  List<LetterItem> letters,
  int optionCount,
  Random random,
) {
  String show(LetterItem l) => mode == FindLetterMode.upper ? l.char : l.lower;
  final others = letters.where((l) => l.char != item.char).toList()..shuffle(random);
  final options = [show(item), ...others.take(optionCount - 1).map(show)]..shuffle(random);
  return FindLetterQuestion(mode: mode, item: item, options: options);
}

enum TapResult { correct, wrong, ignored }

class FindLetterSession {
  FindLetterSession(this.questions);

  final List<FindLetterQuestion> questions;
  final List<AnswerOutcome> outcomes = [];
  int _index = 0;
  int _wrong = 0;
  bool _answered = false;

  int get index => _index;
  bool get isFinished => _index >= questions.length;
  FindLetterQuestion get current => questions[_index];
  bool get showHint => _wrong >= 2;
  int get firstTryCount => outcomes.where((o) => o == AnswerOutcome.firstTry).length;

  TapResult tap(String option) {
    if (isFinished || _answered) return TapResult.ignored;
    if (option != current.answer) {
      _wrong++;
      return TapResult.wrong;
    }
    _answered = true;
    outcomes.add(switch (_wrong) {
      0 => AnswerOutcome.firstTry,
      1 => AnswerOutcome.retry,
      _ => AnswerOutcome.hinted,
    });
    return TapResult.correct;
  }

  /// Moves to the next question after the correct-answer celebration.
  void next() {
    _index++;
    _wrong = 0;
    _answered = false;
  }
}
```

- [ ] **Step 4: Chạy test**

Run: `flutter test test/features/find_letter/find_letter_logic_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: find-letter game logic (modes, round building, session)"
```

---

### Task 7: Cập nhật APK — so phiên bản và kiểm tra GitHub Releases

**Files:**
- Create: `lib/core/updater/version_compare.dart`, `lib/core/updater/app_updater.dart`
- Modify: `lib/app/providers.dart` (thêm `appUpdaterProvider`, `updateCheckProvider`)
- Test: `test/core/updater/version_compare_test.dart`, `test/core/updater/app_updater_test.dart`

**Interfaces:**
- Consumes: `kGithubRepo`, `appVersionProvider` (Task 4).
- Produces:
  - `String normalizeVersion(String v)`; `bool isNewerVersion(String candidate, String current)`
  - `class ReleaseInfo { String version; String apkUrl; int sizeBytes; }`
  - `sealed class UpdateCheck`; `UpToDate()`; `UpdateAvailable(ReleaseInfo release)`; `CheckFailed(String message)`
  - `abstract interface class ReleaseApi { Future<Map<String, dynamic>> latestRelease(); }`; `GithubReleaseApi(Dio dio, String repo)`
  - `class AppUpdater { AppUpdater({required ReleaseApi api, required Dio dio, required String currentVersion}); String currentVersion; Future<UpdateCheck> check(); Future<String> download(ReleaseInfo r, String dir, {void Function(int, int)? onProgress, CancelToken? cancelToken}); }`
  - `appUpdaterProvider`, `updateCheckProvider` (`FutureProvider<UpdateCheck>`)

- [ ] **Step 1: Viết test (failing)**

`test/core/updater/version_compare_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/updater/version_compare.dart';

void main() {
  test('normalizeVersion strips v prefix and build/pre-release suffixes', () {
    expect(normalizeVersion('v1.2.3'), '1.2.3');
    expect(normalizeVersion('1.2.3+7'), '1.2.3');
    expect(normalizeVersion(' V0.1.0-beta '), '0.1.0');
  });

  test('isNewerVersion compares numerically', () {
    expect(isNewerVersion('1.2.0', '1.1.9'), isTrue);
    expect(isNewerVersion('v1.2.0', '1.2.0'), isFalse);
    expect(isNewerVersion('1.10.0', '1.9.9'), isTrue);
    expect(isNewerVersion('1.2.0+5', '1.2.0'), isFalse);
    expect(isNewerVersion('0.2', '0.1.9'), isTrue);
    expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
  });

  test('unparseable versions are never newer', () {
    expect(isNewerVersion('latest', '0.1.0'), isFalse);
    expect(isNewerVersion('1.0.0', 'abc'), isFalse);
  });
}
```

`test/core/updater/app_updater_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';

class FakeReleaseApi implements ReleaseApi {
  FakeReleaseApi(this.result);
  final Object result;

  @override
  Future<Map<String, dynamic>> latestRelease() async {
    if (result is Exception) throw result;
    return result as Map<String, dynamic>;
  }
}

Map<String, dynamic> release(String tag, {bool withApk = true}) => {
      'tag_name': tag,
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://x/notes.txt', 'size': 10},
        if (withApk) {'name': 'xoai-$tag.apk', 'browser_download_url': 'https://x/xoai.apk', 'size': 20971520},
      ],
    };

AppUpdater updater(Object result) =>
    AppUpdater(api: FakeReleaseApi(result), dio: Dio(), currentVersion: '0.1.0');

void main() {
  test('newer release with an APK is available', () async {
    final check = await updater(release('v0.2.0')).check();
    expect(check, isA<UpdateAvailable>());
    final info = (check as UpdateAvailable).release;
    expect(info.version, '0.2.0');
    expect(info.apkUrl, 'https://x/xoai.apk');
    expect(info.sizeBytes, 20971520);
  });

  test('same version is up to date', () async {
    expect(await updater(release('v0.1.0')).check(), isA<UpToDate>());
  });

  test('newer release without an APK fails with a message', () async {
    final check = await updater(release('v0.2.0', withApk: false)).check();
    expect(check, isA<CheckFailed>());
    expect((check as CheckFailed).message, contains('0.2.0'));
  });

  test('API errors become CheckFailed', () async {
    expect(await updater(Exception('offline')).check(), isA<CheckFailed>());
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `flutter test test/core/updater`
Expected: FAIL — chưa có file updater.

- [ ] **Step 3: Viết `lib/core/updater/version_compare.dart`**

```dart
String normalizeVersion(String v) {
  var s = v.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  return s.split(RegExp(r'[+-]')).first;
}

List<int>? _parts(String v) {
  final parts = normalizeVersion(v).split('.');
  if (parts.length > 3) return null;
  final nums = parts.map(int.tryParse).toList();
  if (nums.contains(null)) return null;
  return [...nums.cast<int>(), ...List.filled(3 - nums.length, 0)];
}

/// True when [candidate] is a strictly higher major.minor.patch than [current].
bool isNewerVersion(String candidate, String current) {
  final a = _parts(candidate);
  final b = _parts(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}
```

- [ ] **Step 4: Viết `lib/core/updater/app_updater.dart`**

```dart
import 'package:dio/dio.dart';

import 'version_compare.dart';

class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.apkUrl, required this.sizeBytes});

  final String version;
  final String apkUrl;
  final int sizeBytes;
}

sealed class UpdateCheck {
  const UpdateCheck();
}

class UpToDate extends UpdateCheck {
  const UpToDate();
}

class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(this.release);

  final ReleaseInfo release;
}

class CheckFailed extends UpdateCheck {
  const CheckFailed(this.message);

  final String message;
}

abstract interface class ReleaseApi {
  Future<Map<String, dynamic>> latestRelease();
}

class GithubReleaseApi implements ReleaseApi {
  GithubReleaseApi(this._dio, this.repo);

  final Dio _dio;
  final String repo;

  @override
  Future<Map<String, dynamic>> latestRelease() async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/$repo/releases/latest',
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    return res.data!;
  }
}

class AppUpdater {
  AppUpdater({required ReleaseApi api, required Dio dio, required this.currentVersion})
      : _api = api,
        _dio = dio;

  final ReleaseApi _api;
  final Dio _dio;
  final String currentVersion;

  Future<UpdateCheck> check() async {
    try {
      final json = await _api.latestRelease();
      final version = normalizeVersion(json['tag_name'] as String);
      if (!isNewerVersion(version, currentVersion)) return const UpToDate();
      final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
      final apk = assets.where((a) => (a['name'] as String).endsWith('.apk')).firstOrNull;
      if (apk == null) return CheckFailed('Bản $version không có file APK');
      return UpdateAvailable(ReleaseInfo(
        version: version,
        apkUrl: apk['browser_download_url'] as String,
        sizeBytes: apk['size'] as int,
      ));
    } catch (e) {
      return CheckFailed('Không kiểm tra được cập nhật (mất mạng hoặc chưa có bản phát hành): $e');
    }
  }

  /// Downloads the APK into [dir] and returns its path.
  Future<String> download(
    ReleaseInfo r,
    String dir, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final path = '$dir/xoai-${r.version}.apk';
    await _dio.download(r.apkUrl, path, onReceiveProgress: onProgress, cancelToken: cancelToken);
    return path;
  }
}
```

- [ ] **Step 5: Thêm provider vào `lib/app/providers.dart`**

Thêm import:
```dart
import 'package:dio/dio.dart';

import '../core/updater/app_updater.dart';
import 'config.dart';
```
Thêm cuối file:
```dart
final appUpdaterProvider = Provider<AppUpdater>((ref) {
  final dio = Dio();
  return AppUpdater(api: GithubReleaseApi(dio, kGithubRepo), dio: dio, currentVersion: ref.watch(appVersionProvider));
});

final updateCheckProvider = FutureProvider<UpdateCheck>((ref) => ref.watch(appUpdaterProvider).check());
```

- [ ] **Step 6: Chạy test**

```bash
flutter test test/core/updater
flutter analyze --no-fatal-infos
```
Expected: PASS; analyze sạch.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: GitHub release update check and APK download"
```

---

### Task 8: Khung app, widget dùng chung, màn chính

**Files:**
- Create: `lib/app/app.dart`, `lib/app/theme.dart`, `lib/shared/ice_background.dart`, `lib/shared/big_button.dart`, `lib/shared/snowflake_counter.dart`, `lib/shared/quest_dots.dart`, `lib/shared/character_view.dart`, `lib/shared/castle_view.dart`, `lib/features/home/home_screen.dart`, `lib/features/castle/castle_screen.dart`, `lib/features/parent/parent_lock_button.dart`, `lib/features/parent/parent_gate.dart`, `lib/features/parent/parent_screen.dart`, `lib/features/parent/update_download_dialog.dart`, `lib/features/games/find_letter/find_letter_screen.dart` (tạm thời — Task 9 viết thật)
- Modify: `lib/main.dart`
- Test: `test/support/test_app.dart`, `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: mọi provider ở Task 4/5/7; `rewardStateProvider`; `roundsToday`, `dayKey`; `UpdateAvailable`.
- Produces:
  - `class XoaiApp extends StatelessWidget`
  - `class IceColors { sky, ice, frost, deep, glow }`, `ThemeData buildTheme()`
  - `IceBackground({required Widget child})`, `BigButton({required String emoji, required VoidCallback onTap, double size = 88, bool enabled = true})`, `SnowflakeCounter({required int count})` (hiển thị `'❄️ $count'`), `QuestDots({required int done})`, `CharacterView({required String id, double size = 140})`, `CastleView({required int level, double width = 260})`
  - `HomeScreen`, `CastleScreen`, `ParentLockButton({required bool hasUpdate})` (key `parent-lock`, chấm đỏ key `update-dot`), `Future<bool> showParentGate(BuildContext, {Random? random})` (key `parent-gate-question`, `parent-gate-input`), `ParentScreen`, `UpdateDownloadDialog({required ReleaseInfo release})`
  - Test helper `Widget testApp({...})`

- [ ] **Step 1: Viết test helper và test màn chính (failing)**

`test/support/test_app.dart`:
```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xoai_castle/app/providers.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/core/voice/voice_service.dart';

import 'fakes.dart';

Widget testApp({
  required ContentBundle content,
  required FakeTts tts,
  required Widget home,
  ItemStatsStore? itemStats,
  SessionStore? sessions,
  RewardStore? rewards,
  UpdateCheck update = const UpToDate(),
}) {
  return ProviderScope(
    overrides: [
      contentProvider.overrideWithValue(content),
      voiceProvider.overrideWithValue(VoiceService(
        tts: tts,
        phrases: content.phrases,
        names: const Names(en: 'An', vi: 'Xoài'),
        random: Random(1),
      )),
      itemStatsStoreProvider.overrideWithValue(itemStats ?? MemoryItemStatsStore()),
      sessionStoreProvider.overrideWithValue(sessions ?? MemorySessionStore()),
      rewardStoreProvider.overrideWithValue(rewards ?? MemoryRewardStore()),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 9)),
      randomProvider.overrideWithValue(Random(42)),
      appVersionProvider.overrideWithValue('0.1.0'),
      updateCheckProvider.overrideWith((ref) async => update),
    ],
    child: MaterialApp(home: home),
  );
}
```

`test/features/home/home_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/features/castle/castle_screen.dart';
import 'package:xoai_castle/features/games/find_letter/find_letter_screen.dart';
import 'package:xoai_castle/features/home/home_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<FakeTts> pumpHome(WidgetTester tester, {RewardState rewards = const RewardState(), UpdateCheck update = const UpToDate()}) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const HomeScreen(),
      rewards: MemoryRewardStore(rewards),
      update: update,
    ));
    await tester.pump();
    await tester.pump();
    return tts;
  }

  testWidgets('shows snowflakes and greets the child', (tester) async {
    final tts = await pumpHome(tester, rewards: const RewardState(snowflakesTotal: 12));
    expect(find.text('❄️ 12'), findsOneWidget);
    expect(tts.texts, contains('Chào Xoài! Hôm nay mình chơi gì nào?'));
    expect(find.byKey(const Key('update-dot')), findsNothing);
  });

  testWidgets('a coming-soon game says its name and stays on home', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('✏️'));
    await tester.pump();
    await tester.pump();
    expect(tts.texts, containsAllInOrder(['Tô chữ', 'Trò này sắp có rồi nha!']));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the balloon button opens the find-letter game', (tester) async {
    final tts = await pumpHome(tester);
    await tester.tap(find.text('🎈'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tts.texts, contains('Tìm chữ cái'));
    expect(find.byType(FindLetterScreen), findsOneWidget);
  });

  testWidgets('tapping the castle opens the castle screen', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-castle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CastleScreen), findsOneWidget);
  });

  testWidgets('shows a red dot on the lock when an update is available', (tester) async {
    await pumpHome(
      tester,
      update: const UpdateAvailable(ReleaseInfo(version: '0.2.0', apkUrl: 'https://x/a.apk', sizeBytes: 1)),
    );
    expect(find.byKey(const Key('update-dot')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `flutter test test/features/home/home_screen_test.dart`
Expected: FAIL — chưa có các màn hình.

- [ ] **Step 3: Viết theme và widget dùng chung**

`lib/app/theme.dart`:
```dart
import 'package:flutter/material.dart';

class IceColors {
  static const sky = Color(0xFFE6F6FF);
  static const ice = Color(0xFFBDE7FF);
  static const frost = Color(0xFF8FD3FF);
  static const deep = Color(0xFF1E5AA8);
  static const glow = Color(0xFFFFF59D);
}

ThemeData buildTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: IceColors.deep),
      scaffoldBackgroundColor: IceColors.sky,
      useMaterial3: true,
    );
```

`lib/shared/ice_background.dart`:
```dart
import 'package:flutter/material.dart';

import '../app/theme.dart';

class IceBackground extends StatelessWidget {
  const IceBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [IceColors.sky, IceColors.ice],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
```

`lib/shared/big_button.dart`:
```dart
import 'package:flutter/material.dart';

import '../app/theme.dart';

class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.emoji, required this.onTap, this.size = 88, this.enabled = true});

  final String emoji;
  final VoidCallback onTap;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Colors.white, IceColors.frost]),
            boxShadow: [
              BoxShadow(color: IceColors.deep.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Text(emoji, style: TextStyle(fontSize: size * 0.45)),
        ),
      ),
    );
  }
}
```

`lib/shared/snowflake_counter.dart`:
```dart
import 'package:flutter/material.dart';

import '../app/theme.dart';

class SnowflakeCounter extends StatelessWidget {
  const SnowflakeCounter({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(24)),
      child: Text(
        '❄️ $count',
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: IceColors.deep),
      ),
    );
  }
}
```

`lib/shared/quest_dots.dart`:
```dart
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/rewards/reward_rules.dart';

class QuestDots extends StatelessWidget {
  const QuestDots({super.key, required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('⭐', style: TextStyle(fontSize: 24)),
        for (var i = 0; i < kQuestRounds; i++)
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? IceColors.glow : Colors.white,
              border: Border.all(color: IceColors.deep, width: 2),
            ),
          ),
      ],
    );
  }
}
```

`lib/shared/character_view.dart`:
```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Shows a character: the configured image if any, otherwise a placeholder
/// (a painted ice princess for Elsa, the emoji for everyone else).
class CharacterView extends ConsumerWidget {
  const CharacterView({super.key, required this.id, this.size = 140});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = ref.watch(contentProvider).characters[id];
    final image = def?.image;
    if (image != null) {
      return Image.asset('content/$image', width: size, height: size, fit: BoxFit.contain);
    }
    if (id == 'elsa') {
      return CustomPaint(size: Size.square(size), painter: const PrincessPainter());
    }
    return SizedBox.square(
      dimension: size,
      child: Center(child: Text(def?.emoji ?? '❓', style: TextStyle(fontSize: size * 0.6))),
    );
  }
}

class PrincessPainter extends CustomPainter {
  const PrincessPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dress = Path()
      ..moveTo(w * 0.5, h * 0.42)
      ..lineTo(w * 0.18, h * 0.98)
      ..quadraticBezierTo(w * 0.5, h * 1.02, w * 0.82, h * 0.98)
      ..close();
    canvas.drawPath(
      dress,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB3E5FC), Color(0xFF4FC3F7)],
        ).createShader(Offset.zero & size),
    );
    final hair = Paint()..color = const Color(0xFFFFF3C4);
    canvas.drawOval(Rect.fromLTWH(w * 0.52, h * 0.22, w * 0.16, h * 0.40), hair);
    canvas.drawCircle(Offset(w * 0.5, h * 0.26), w * 0.15, Paint()..color = const Color(0xFFFFE0CC));
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.5, h * 0.24), radius: w * 0.17), pi, pi, true, hair);
    final eye = Paint()..color = const Color(0xFF1E5AA8);
    canvas.drawCircle(Offset(w * 0.45, h * 0.27), w * 0.018, eye);
    canvas.drawCircle(Offset(w * 0.55, h * 0.27), w * 0.018, eye);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.31), width: w * 0.08, height: h * 0.04),
      0,
      pi,
      false,
      Paint()
        ..color = const Color(0xFFE57373)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012,
    );
    final sparkle = Paint()..color = Colors.white;
    for (final p in [
      Offset(w * 0.35, h * 0.75),
      Offset(w * 0.6, h * 0.65),
      Offset(w * 0.5, h * 0.88),
      Offset(w * 0.68, h * 0.85),
    ]) {
      canvas.drawCircle(p, w * 0.015, sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

`lib/shared/castle_view.dart`:
```dart
import 'dart:math';

import 'package:flutter/material.dart';

/// Placeholder ice castle drawn in code; each level adds a part.
class CastleView extends StatelessWidget {
  const CastleView({super.key, required this.level, this.width = 260});

  final int level;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, width * 0.85), painter: CastlePainter(level));
  }
}

class CastlePainter extends CustomPainter {
  CastlePainter(this.level);

  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ice = Paint()..color = const Color(0xFFBFE9FF);
    final iceDark = Paint()..color = const Color(0xFF7CC8F2);

    canvas.drawOval(Rect.fromLTWH(w * 0.05, h * 0.82, w * 0.9, h * 0.16), iceDark);
    if (level >= 2) canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.45, w * 0.5, h * 0.42), ice);
    if (level >= 3) {
      final door = Path()
        ..moveTo(w * 0.43, h * 0.87)
        ..lineTo(w * 0.43, h * 0.70)
        ..arcToPoint(Offset(w * 0.57, h * 0.70), radius: Radius.circular(w * 0.07))
        ..lineTo(w * 0.57, h * 0.87)
        ..close();
      canvas.drawPath(door, iceDark);
    }

    void tower(double x) {
      canvas.drawRect(Rect.fromLTWH(x, h * 0.30, w * 0.16, h * 0.57), ice);
      final roof = Path()
        ..moveTo(x - w * 0.02, h * 0.30)
        ..lineTo(x + w * 0.08, h * 0.08)
        ..lineTo(x + w * 0.18, h * 0.30)
        ..close();
      canvas.drawPath(roof, iceDark);
    }

    if (level >= 4) tower(w * 0.10);
    if (level >= 5) {
      final step = Paint()..color = Colors.white;
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(Rect.fromLTWH(w * (0.38 - i * 0.03), h * (0.87 + i * 0.025), w * (0.24 + i * 0.06), h * 0.025), step);
      }
    }
    if (level >= 6) {
      final light = Paint()..color = const Color(0xFFFFF59D);
      final center = Offset(w * 0.5, h * 0.56);
      canvas.drawCircle(center, w * 0.045, light);
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3;
        canvas.drawCircle(center + Offset(cos(a), sin(a)) * w * 0.07, w * 0.012, light);
      }
    }
    if (level >= 7) tower(w * 0.74);
    if (level >= 8) {
      const colors = [Color(0xFFFF8A80), Color(0xFFFFD180), Color(0xFFB388FF)];
      final centers = [Offset(w * 0.2, h * 0.08), Offset(w * 0.8, h * 0.1), Offset(w * 0.5, h * 0.04)];
      for (var c = 0; c < centers.length; c++) {
        final paint = Paint()
          ..color = colors[c]
          ..strokeWidth = w * 0.01
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          final dir = Offset(cos(a), sin(a));
          canvas.drawLine(centers[c] + dir * w * 0.02, centers[c] + dir * w * 0.06, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CastlePainter oldDelegate) => oldDelegate.level != level;
}
```

- [ ] **Step 4: Viết khu bố mẹ (khóa, cửa, màn hình, hộp thoại tải)**

`lib/features/parent/parent_gate.dart`:
```dart
import 'dart:math';

import 'package:flutter/material.dart';

/// Asks a two-digit addition; resolves true only for the right answer.
Future<bool> showParentGate(BuildContext context, {Random? random}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => ParentGateDialog(random: random ?? Random()),
  );
  return ok ?? false;
}

class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key, required this.random});

  final Random random;

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  final _controller = TextEditingController();
  late int _a;
  late int _b;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _newQuestion() {
    _a = 10 + widget.random.nextInt(40);
    _b = 10 + widget.random.nextInt(40);
    _controller.clear();
  }

  void _submit() {
    if (int.tryParse(_controller.text.trim()) == _a + _b) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _wrong = true;
      _newQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dành cho bố mẹ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_a + $_b = ?', key: const Key('parent-gate-question'), style: const TextStyle(fontSize: 32)),
          TextField(
            key: const Key('parent-gate-input'),
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_wrong) const Text('Chưa đúng, thử lại nhé', style: TextStyle(color: Colors.red)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
```

`lib/features/parent/parent_lock_button.dart`:
```dart
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'parent_gate.dart';
import 'parent_screen.dart';

/// Small lock in the corner: hold for 2 seconds to reach the parent gate.
class ParentLockButton extends StatefulWidget {
  const ParentLockButton({super.key, required this.hasUpdate});

  final bool hasUpdate;

  @override
  State<ParentLockButton> createState() => _ParentLockButtonState();
}

class _ParentLockButtonState extends State<ParentLockButton> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _open();
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    _hold.reset();
    final ok = await showParentGate(context);
    if (!ok || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ParentScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const Key('parent-lock'),
      onPointerDown: (_) => _hold.forward(from: 0),
      onPointerUp: (_) => _hold.reset(),
      onPointerCancel: (_) => _hold.reset(),
      child: SizedBox.square(
        dimension: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _hold,
              builder: (_, __) => CircularProgressIndicator(value: _hold.value, color: IceColors.deep),
            ),
            const Text('🔒', style: TextStyle(fontSize: 24)),
            if (widget.hasUpdate)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  key: const Key('update-dot'),
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/parent/parent_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/updater/app_updater.dart';
import 'update_download_dialog.dart';

class ParentScreen extends ConsumerWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khu bố mẹ')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Phiên bản app'),
            subtitle: Text(ref.watch(appVersionProvider)),
          ),
          const UpdateTile(),
        ],
      ),
    );
  }
}

class UpdateTile extends ConsumerWidget {
  const UpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget retry(String message) => ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.orange),
          title: Text(message),
          trailing: TextButton(
            onPressed: () => ref.invalidate(updateCheckProvider),
            child: const Text('Kiểm tra lại'),
          ),
        );

    return ref.watch(updateCheckProvider).when(
          loading: () => const ListTile(
            leading: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text('Đang kiểm tra cập nhật…'),
          ),
          error: (e, _) => retry('Lỗi kiểm tra cập nhật: $e'),
          data: (check) => switch (check) {
            UpToDate() => ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Đang dùng bản mới nhất'),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(updateCheckProvider),
                  child: const Text('Kiểm tra lại'),
                ),
              ),
            CheckFailed(:final message) => retry(message),
            UpdateAvailable(:final release) => ListTile(
                leading: const Icon(Icons.system_update, color: Colors.red),
                title: Text('Có bản mới ${release.version}'),
                subtitle: Text('${(release.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'),
                trailing: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => UpdateDownloadDialog(release: release),
                  ),
                  child: const Text('Cập nhật'),
                ),
              ),
          },
        );
  }
}
```

`lib/features/parent/update_download_dialog.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../core/updater/app_updater.dart';

/// Downloads the release APK with progress, then opens the Android installer.
class UpdateDownloadDialog extends ConsumerStatefulWidget {
  const UpdateDownloadDialog({super.key, required this.release});

  final ReleaseInfo release;

  @override
  ConsumerState<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends ConsumerState<UpdateDownloadDialog> {
  final _cancel = CancelToken();
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final dir = await getTemporaryDirectory();
      final path = await ref.read(appUpdaterProvider).download(
        widget.release,
        dir.path,
        cancelToken: _cancel,
        onProgress: (received, total) {
          if (mounted && total > 0) setState(() => _progress = received / total);
        },
      );
      final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      if (!mounted) return;
      if (result.type == ResultType.done) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = 'Không mở được trình cài đặt: ${result.message}');
      }
    } catch (e) {
      if (mounted && !_cancel.isCancelled) setState(() => _error = 'Tải bản cập nhật lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return AlertDialog(
      title: Text('Cập nhật ${widget.release.version}'),
      content: _error != null
          ? Text(_error!)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(progress == null ? 'Đang tải…' : 'Đang tải ${(progress * 100).round()}%'),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () {
            _cancel.cancel();
            Navigator.of(context).pop();
          },
          child: Text(_error != null ? 'Đóng' : 'Hủy'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Viết màn lâu đài, màn chính, màn tìm chữ tạm**

`lib/features/castle/castle_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/reward_controller.dart';
import '../../core/rewards/reward_state.dart';
import '../../shared/big_button.dart';
import '../../shared/castle_view.dart';
import '../../shared/character_view.dart';
import '../../shared/ice_background.dart';
import '../../shared/snowflake_counter.dart';

class CastleScreen extends ConsumerWidget {
  const CastleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardStateProvider).value ?? const RewardState();
    final levels = ref.watch(contentProvider).castle;
    final current = levels.firstWhere((l) => l.level == rewards.castleLevel);
    final next = levels.where((l) => l.level == rewards.castleLevel + 1).firstOrNull;
    final progress = next == null
        ? 1.0
        : (rewards.snowflakesTotal - current.snowflakes) / (next.snowflakes - current.snowflakes);
    final friends = [
      for (final l in levels)
        if (l.level <= rewards.castleLevel && l.friend != null) l.friend!,
    ];
    return Scaffold(
      body: IceBackground(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: BigButton(emoji: '🏠', size: 64, onTap: () => Navigator.of(context).pop()),
              ),
            ),
            Expanded(child: Center(child: CastleView(level: rewards.castleLevel, width: 320))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 16,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            SnowflakeCounter(count: rewards.snowflakesTotal),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                const CharacterView(id: 'elsa', size: 72),
                for (final f in friends) CharacterView(id: f, size: 72),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/games/find_letter/find_letter_screen.dart` (tạm thời, Task 9 thay):
```dart
import 'package:flutter/material.dart';

class FindLetterScreen extends StatelessWidget {
  const FindLetterScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}
```

`lib/features/home/home_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/reward_controller.dart';
import '../../core/rewards/reward_rules.dart';
import '../../core/rewards/reward_state.dart';
import '../../core/time.dart';
import '../../core/updater/app_updater.dart';
import '../../shared/big_button.dart';
import '../../shared/castle_view.dart';
import '../../shared/character_view.dart';
import '../../shared/ice_background.dart';
import '../../shared/quest_dots.dart';
import '../../shared/snowflake_counter.dart';
import '../castle/castle_screen.dart';
import '../games/find_letter/find_letter_screen.dart';
import '../parent/parent_lock_button.dart';

class _GameEntry {
  const _GameEntry(this.emoji, this.phraseId, [this.builder]);

  final String emoji;
  final String phraseId;
  final WidgetBuilder? builder;

  bool get enabled => builder != null;
}

final _games = <_GameEntry>[
  _GameEntry('🎈', 'game_find_letter', (_) => const FindLetterScreen()),
  const _GameEntry('✏️', 'game_trace'),
  const _GameEntry('🗣️', 'game_talk'),
  const _GameEntry('🇻🇳', 'game_vi'),
  const _GameEntry('🐶', 'game_vocab'),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(voiceProvider).say('greet_vi'));
  }

  Future<void> _openGame(_GameEntry game) async {
    final voice = ref.read(voiceProvider);
    final builder = game.builder;
    if (builder == null) {
      await voice.say(game.phraseId);
      await voice.say('coming_soon');
      return;
    }
    voice.say(game.phraseId);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  void _openCastle() {
    ref.read(voiceProvider).say('game_castle');
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CastleScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final rewards = ref.watch(rewardStateProvider).value ?? const RewardState();
    final today = dayKey(ref.watch(clockProvider)());
    final hasUpdate = ref.watch(updateCheckProvider).value is UpdateAvailable;
    return Scaffold(
      body: IceBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SnowflakeCounter(count: rewards.snowflakesTotal),
                  QuestDots(done: roundsToday(rewards, today)),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  GestureDetector(
                    key: const Key('home-castle'),
                    onTap: _openCastle,
                    child: CastleView(level: rewards.castleLevel, width: 300),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => ref.read(voiceProvider).say('greet_en'),
                      child: const CharacterView(id: 'elsa', size: 150),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final g in _games) BigButton(emoji: g.emoji, enabled: g.enabled, onTap: () => _openGame(g)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ParentLockButton(hasUpdate: hasUpdate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Viết `lib/app/app.dart` và `lib/main.dart`**

`lib/app/app.dart`:
```dart
import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import 'theme.dart';

class XoaiApp extends StatelessWidget {
  const XoaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lâu đài Xoài',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
```

`lib/main.dart`:
```dart
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/content/asset_content_source.dart';
import 'core/content/content_repository.dart';
import 'core/db/database.dart';
import 'core/profile/profile_store.dart';
import 'core/voice/flutter_tts_engine.dart';
import 'core/voice/voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final content = await ContentRepository(AssetContentSource()).load();
  final db = AppDatabase(driftDatabase(name: 'xoai'));
  final names = await DriftProfileStore(db).loadNames(content.profileDefaults);
  final tts = await FlutterTtsEngine.create();
  final info = await PackageInfo.fromPlatform();

  runApp(ProviderScope(
    overrides: [
      contentProvider.overrideWithValue(content),
      databaseProvider.overrideWithValue(db),
      voiceProvider.overrideWithValue(VoiceService(tts: tts, phrases: content.phrases, names: names)),
      appVersionProvider.overrideWithValue(info.version),
    ],
    child: const XoaiApp(),
  ));
}
```

- [ ] **Step 7: Chạy test**

```bash
flutter test test/features/home
flutter analyze --no-fatal-infos
```
Expected: PASS; analyze sạch.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: home screen, castle screen, shared widgets, parent area shell"
```

---

### Task 9: Màn chơi Tìm chữ cái và màn thưởng

**Files:**
- Create: `lib/features/games/find_letter/falling_flakes.dart`, `lib/features/games/find_letter/example_card.dart`, `lib/features/reward/reward_screen.dart`
- Modify: `lib/features/games/find_letter/find_letter_screen.dart` (thay bản tạm)
- Test: `test/features/find_letter/find_letter_screen_test.dart`

**Interfaces:**
- Consumes: `buildFindLetterRound`, `FindLetterSession`, `TapResult` (Task 6); `QuestionPicker`, `ItemStat` (Task 3); providers (Task 4/5); `rewardStateProvider.notifier.completeRound` (Task 4); `SessionRecord` (Task 2); `dayKey`; widget dùng chung (Task 8).
- Produces: `FindLetterScreen` (thật), `RewardScreen({required RewardOutcome outcome})` (hiển thị `'+${earned} ❄️'`, nút ✅ quay về), `FallingFlakes`, `ExampleCard`.

- [ ] **Step 1: Viết test (failing)**

`test/features/find_letter/find_letter_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/find_letter/find_letter_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

final _prompt = RegExp(r'^Find the letter (\w)!$');

List<String> prompts(FakeTts tts) => [
      for (final t in tts.texts)
        if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!,
    ];

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  testWidgets('a full round of correct taps saves progress and shows the reward', (tester) async {
    final tts = FakeTts();
    final stats = MemoryItemStatsStore();
    final sessions = MemorySessionStore();
    final rewards = MemoryRewardStore();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: const FindLetterScreen(),
      itemStats: stats,
      sessions: sessions,
      rewards: rewards,
    ));
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 8; i++) {
      final asked = prompts(tts);
      expect(asked, hasLength(i + 1), reason: 'question ${i + 1} should have been asked');
      await tester.tap(find.text(asked.last));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+13 ❄️'), findsOneWidget);
    expect(rewards.state.snowflakesTotal, 13);
    expect(sessions.records.single.correct, 8);
    expect(sessions.records.single.game, 'find_letter');
    expect(stats.stats.values.fold<int>(0, (sum, s) => sum + s.correct), 8);
    expect(stats.stats.values.every((s) => s.mastery >= 1 && s.wrong == 0), isTrue);
    expect(tts.texts, contains('Hoàn thành rồi! Xoài giỏi quá!'));
  });

  testWidgets('a wrong tap says try again and lowers nothing yet', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const FindLetterScreen()));
    await tester.pump();
    await tester.pump();

    final answer = prompts(tts).single;
    final wrong = tester
        .widgetList<Text>(find.byKey(const Key('flake-letter')))
        .map((t) => t.data!)
        .firstWhere((l) => l != answer);
    await tester.tap(find.text(wrong));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tts.texts.where((t) => t == 'Try again!' || t == 'Thử lại nha con!'), hasLength(1));
    expect(prompts(tts), hasLength(1));
  });

  testWidgets('a storage failure sends the child back home', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      itemStats: FailingItemStatsStore(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FindLetterScreen())),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tts.texts, contains('Mình về lâu đài nha!'));
    expect(find.byType(FindLetterScreen), findsNothing);
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `flutter test test/features/find_letter/find_letter_screen_test.dart`
Expected: FAIL — chưa có `reward_screen.dart`; màn tìm chữ đang là bản tạm.

- [ ] **Step 3: Viết `lib/features/games/find_letter/falling_flakes.dart`**

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Snowflakes carrying letters drift down in lanes and loop back to the top.
/// They always stay fully on screen so a child (or a test) can tap them.
class FallingFlakes extends StatefulWidget {
  const FallingFlakes({super.key, required this.options, required this.onTap, this.hint, this.shaking, this.burst});

  final List<String> options;
  final ValueChanged<String> onTap;

  /// Option that glows (after two wrong taps).
  final String? hint;

  /// Option that wiggles (just tapped wrong).
  final String? shaking;

  /// Option that bursts (just tapped right).
  final String? burst;

  @override
  State<FallingFlakes> createState() => _FallingFlakesState();
}

class _FallingFlakesState extends State<FallingFlakes> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = widget.options.length;
        final lane = constraints.maxWidth / n;
        final size = min(104.0, lane - 8);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            children: [
              for (var i = 0; i < n; i++) _flake(i, lane, size, constraints.maxHeight),
            ],
          ),
        );
      },
    );
  }

  Widget _flake(int i, double lane, double size, double height) {
    final option = widget.options[i];
    final phase = (_controller.value + i * 0.37) % 1.0;
    final fade = phase < 0.08 ? phase / 0.08 : (phase > 0.92 ? (1 - phase) / 0.08 : 1.0);
    final shake = widget.shaking == option ? sin(_controller.value * 9 * 2 * pi * 6) * 8 : 0.0;
    final glow = widget.hint == option;
    final burst = widget.burst == option;
    return Positioned(
      left: (i + 0.5) * lane - size / 2 + shake,
      top: phase * max(0.0, height - size),
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0).toDouble(),
        child: AnimatedOpacity(
          opacity: burst ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: AnimatedScale(
            scale: burst ? 1.6 : (glow ? 1.15 : 1.0),
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => widget.onTap(option),
              child: _FlakeFace(letter: option, size: size, glow: glow),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlakeFace extends StatelessWidget {
  const _FlakeFace({required this.letter, required this.size, required this.glow});

  final String letter;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Colors.white, IceColors.frost]),
        boxShadow: glow
            ? const [BoxShadow(color: IceColors.glow, blurRadius: 24, spreadRadius: 8)]
            : [BoxShadow(color: IceColors.deep.withValues(alpha: 0.2), blurRadius: 6)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('❄', style: TextStyle(fontSize: size * 0.9, color: Colors.white.withValues(alpha: 0.6))),
          Text(
            letter,
            key: const Key('flake-letter'),
            style: TextStyle(fontSize: size * 0.48, fontWeight: FontWeight.w900, color: IceColors.deep),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Viết `lib/features/games/find_letter/example_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/content/models.dart';

/// Pops up after a correct answer: the example picture and word.
class ExampleCard extends StatelessWidget {
  const ExampleCard({super.key, required this.item});

  final LetterItem item;

  @override
  Widget build(BuildContext context) {
    final image = item.exampleImage;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                Image.asset('content/$image', width: 120, height: 120)
              else
                Text(item.exampleEmoji ?? '', style: const TextStyle(fontSize: 96)),
              Text(
                item.exampleWord,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: IceColors.deep),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Viết `lib/features/reward/reward_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/rewards/reward_state.dart';
import '../../shared/big_button.dart';
import '../../shared/castle_view.dart';
import '../../shared/character_view.dart';
import '../../shared/ice_background.dart';

class RewardScreen extends ConsumerStatefulWidget {
  const RewardScreen({super.key, required this.outcome});

  final RewardOutcome outcome;

  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
  }

  Future<void> _celebrate() async {
    final voice = ref.read(voiceProvider);
    final o = widget.outcome;
    await voice.say('round_done');
    if (o.questCompleted) await voice.say('quest_done');
    if (o.leveledUp) await voice.say('castle_level_up');
    if (o.friendUnlocked != null) await voice.say('friend_unlocked');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outcome;
    final friend = o.friendUnlocked;
    return Scaffold(
      body: IceBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: o.leveledUp ? 0.7 : 1, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: CastleView(level: o.newLevel, width: 280),
              ),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: o.earned),
                duration: const Duration(milliseconds: 1200),
                builder: (context, value, _) => Text(
                  '+$value ❄️',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: IceColors.deep),
                ),
              ),
              if (o.questCompleted) const Text('🎁', style: TextStyle(fontSize: 72)),
              if (friend != null) CharacterView(id: friend, size: 96),
              BigButton(emoji: '✅', size: 96, onTap: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Viết `lib/features/games/find_letter/find_letter_screen.dart` (thay bản tạm)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reward_controller.dart';
import '../../../app/theme.dart';
import '../../../core/content/models.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../../../core/session/session_store.dart';
import '../../../core/time.dart';
import '../../../core/voice/voice_service.dart';
import '../../../shared/big_button.dart';
import '../../../shared/character_view.dart';
import '../../../shared/ice_background.dart';
import '../../reward/reward_screen.dart';
import 'example_card.dart';
import 'falling_flakes.dart';
import 'find_letter_logic.dart';

class FindLetterScreen extends ConsumerStatefulWidget {
  const FindLetterScreen({super.key});

  @override
  ConsumerState<FindLetterScreen> createState() => _FindLetterScreenState();
}

class _FindLetterScreenState extends ConsumerState<FindLetterScreen> {
  FindLetterSession? _session;
  Map<String, ItemStat> _stats = {};
  late final DateTime _startedAt;
  bool _busy = true;
  String? _shaking;
  String? _burst;
  LetterItem? _celebrating;

  VoiceService get _voice => ref.read(voiceProvider);

  @override
  void initState() {
    super.initState();
    _startedAt = ref.read(clockProvider)();
    _guard(_start);
  }

  /// Any unexpected error: Elsa says we go home, and we leave the game.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('FindLetter error: $e\n$st');
      if (!mounted) return;
      await _voice.say('error_home');
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    final random = ref.read(randomProvider);
    _stats = await ref.read(itemStatsStoreProvider).loadByPrefix('letter_en_');
    final questions = buildFindLetterRound(
      letters: ref.read(contentProvider).lettersEn,
      stats: _stats,
      picker: QuestionPicker(random),
      random: random,
    );
    if (!mounted) return;
    setState(() => _session = FindLetterSession(questions));
    await _ask();
  }

  Future<void> _ask() async {
    final q = _session!.current;
    setState(() => _busy = false);
    await _voice.say(q.promptPhraseId, vars: q.promptVars);
  }

  void _onTap(String option) {
    if (_busy) return;
    _guard(() => _handleTap(option));
  }

  Future<void> _handleTap(String option) async {
    final session = _session!;
    final result = session.tap(option);
    if (result == TapResult.wrong) {
      setState(() => _shaking = option);
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shaking = null);
      });
      await _voice.sayGroup('try_again');
      if (session.showHint && mounted) {
        setState(() {});
        await _voice.say(session.current.promptPhraseId, vars: session.current.promptVars);
      }
      return;
    }
    if (result != TapResult.correct) return;

    final q = session.current;
    setState(() {
      _busy = true;
      _burst = option;
      _celebrating = q.item;
    });
    final stat = (_stats[q.key] ?? ItemStat(key: q.key)).apply(session.outcomes.last, ref.read(clockProvider)());
    _stats[q.key] = stat;
    await ref.read(itemStatsStoreProvider).save(stat);
    await Future.wait([
      _voice.say('letter_example', vars: {'letter': q.item.char, 'word': q.item.exampleWord}),
      Future<void>.delayed(const Duration(milliseconds: 800)),
    ]);
    if (!mounted) return;
    session.next();
    setState(() {
      _burst = null;
      _celebrating = null;
    });
    if (session.isFinished) {
      await _finish();
    } else {
      await _ask();
    }
  }

  Future<void> _finish() async {
    final session = _session!;
    final now = ref.read(clockProvider)();
    await ref.read(sessionStoreProvider).add(SessionRecord(
          date: dayKey(_startedAt),
          game: 'find_letter',
          startedAt: _startedAt,
          durationSec: now.difference(_startedAt).inSeconds,
          correct: session.firstTryCount,
          total: session.questions.length,
        ));
    final outcome = await ref.read(rewardStateProvider.notifier).completeRound(session.firstTryCount);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => RewardScreen(outcome: outcome)));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null || session.isFinished) {
      return const Scaffold(body: IceBackground(child: Center(child: CircularProgressIndicator())));
    }
    final q = session.current;
    final shown = q.shownLetter;
    final celebrating = _celebrating;
    return Scaffold(
      body: IceBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  BigButton(emoji: '🏠', size: 64, onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  Text(
                    '${session.index + 1}/${session.questions.length}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: IceColors.deep),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _voice.say(q.promptPhraseId, vars: q.promptVars),
                    child: const CharacterView(id: 'elsa', size: 110),
                  ),
                  if (shown != null)
                    Text(
                      shown,
                      style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: IceColors.deep),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FallingFlakes(
                    key: ValueKey(session.index),
                    options: q.options,
                    onTap: _onTap,
                    hint: session.showHint ? q.answer : null,
                    shaking: _shaking,
                    burst: _burst,
                  ),
                  if (celebrating != null) Center(child: ExampleCard(item: celebrating)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Chạy toàn bộ test**

```bash
flutter test
flutter analyze --no-fatal-infos
```
Expected: mọi test PASS; analyze sạch. Nếu test "full round" fail vì số lượng prompt không khớp, kiểm tra thứ tự `_ask()` sau `session.next()` và số lần `pump` trong test — không sửa test để bỏ qua kiểm tra.

- [ ] **Step 8: Chạy thử trên emulator hoặc điện thoại (nếu có)**

```bash
flutter devices
flutter run -d <device-id>
```
Kiểm tra bằng mắt: Elsa chào, bấm 🎈 vào trò, bông tuyết rơi chậm, chạm đúng thì hiện hình + đọc, chạm sai thì rung + "Try again", xong 8 câu thì sang màn thưởng, bấm ✅ về lâu đài và số ❄️ tăng. Nếu không có thiết bị thì ghi rõ "chưa chạy thử trên máy thật" khi báo cáo.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: find-letter game screen with falling snowflakes and reward screen"
```

---

### Task 10: Test khu bố mẹ

**Files:**
- Test: `test/features/parent/parent_gate_test.dart`

**Interfaces:**
- Consumes: `HomeScreen`, `ParentLockButton`, `ParentGateDialog`, `ParentScreen` (Task 8).

- [ ] **Step 1: Viết test**

`test/features/parent/parent_gate_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/parent/parent_gate.dart';
import 'package:xoai_castle/features/parent/parent_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> holdLock(WidgetTester tester, Duration duration) async {
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const HomeScreen()));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('parent-lock'))));
    await tester.pump(duration);
    await gesture.up();
    await settle(tester);
  }

  int answer(WidgetTester tester) {
    final q = tester.widget<Text>(find.byKey(const Key('parent-gate-question'))).data!;
    final m = RegExp(r'(\d+) \+ (\d+)').firstMatch(q)!;
    return int.parse(m[1]!) + int.parse(m[2]!);
  }

  testWidgets('a short press does not open the gate', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 500));
    expect(find.byType(ParentGateDialog), findsNothing);
  });

  testWidgets('holding 2s and answering correctly opens the parent area', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 2100));
    expect(find.byType(ParentGateDialog), findsOneWidget);

    await tester.enterText(find.byKey(const Key('parent-gate-input')), '${answer(tester)}');
    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(find.byType(ParentScreen), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('Đang dùng bản mới nhất'), findsOneWidget);
  });

  testWidgets('a wrong answer keeps the gate closed and asks again', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 2100));
    final first = answer(tester);
    await tester.enterText(find.byKey(const Key('parent-gate-input')), '${first + 1}');
    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(find.byType(ParentScreen), findsNothing);
    expect(find.text('Chưa đúng, thử lại nhé'), findsOneWidget);
    expect(find.byType(ParentGateDialog), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test**

Run: `flutter test test/features/parent/parent_gate_test.dart`
Expected: PASS (code đã viết ở Task 8). Nếu FAIL, sửa code trong `lib/features/parent/` cho đúng hành vi đã mô tả, không nới lỏng test.

- [ ] **Step 3: Chạy toàn bộ test + analyze**

```bash
flutter test
flutter analyze --no-fatal-infos
```
Expected: PASS; analyze sạch.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: parent gate hold-to-open and math check"
```

---

### Task 11: Ký release, CI, repo GitHub, phát hành v0.1.0

**Files:**
- Modify: `android/app/build.gradle.kts`
- Create: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `README.md` (thay README do `flutter create` sinh)
- Ngoài repo: `~/.xoai-keystore/xoai-release.jks`, `~/.xoai-keystore/key.properties`, `android/key.properties` (bị gitignore)

**Interfaces:**
- Produces: tag `v*` → GitHub Release kèm `xoai-v*.apk` đã ký; app đọc release qua `kGithubRepo`.

- [ ] **Step 1: Cấu hình ký trong `android/app/build.gradle.kts`**

Thêm ở **dòng đầu file**:
```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```
Trong khối `android { ... }`, thêm ngay trước khối `buildTypes`:
```kotlin
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
```
Trong `buildTypes { release { ... } }`, thay dòng `signingConfig = signingConfigs.getByName("debug")` bằng:
```kotlin
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
```

- [ ] **Step 2: Kiểm tra `.gitignore` của Android đã bỏ qua keystore**

Run: `grep -nE "key.properties|\.jks" android/.gitignore`
Expected: có cả `key.properties` và `**/*.jks`. Nếu thiếu, thêm hai dòng đó vào `android/.gitignore`.

- [ ] **Step 3: Tạo keystore (một lần, ngoài repo)**

```bash
mkdir -p ~/.xoai-keystore
PASS=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkeypair -v \
  -keystore ~/.xoai-keystore/xoai-release.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias xoai \
  -storepass "$PASS" -keypass "$PASS" -dname "CN=Xoai Castle, O=Family, C=VN"
printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=xoai\nstoreFile=%s\n' \
  "$PASS" "$PASS" "$HOME/.xoai-keystore/xoai-release.jks" > ~/.xoai-keystore/key.properties
chmod 600 ~/.xoai-keystore/*
cp ~/.xoai-keystore/key.properties android/key.properties
```
Báo người dùng: **sao lưu thư mục `~/.xoai-keystore/`** (mất keystore = không cập nhật đè được app đã cài).

- [ ] **Step 4: Build release cục bộ để kiểm tra ký**

```bash
flutter build apk --release
"$HOME/Library/Android/sdk/build-tools/35.0.0/apksigner" verify --print-certs build/app/outputs/flutter-apk/app-release.apk | head -3
```
Expected: build thành công; `apksigner` in `Signer #1 certificate DN: CN=Xoai Castle, O=Family, C=VN`.

- [ ] **Step 5: Viết `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev
      - run: flutter pub get
      - run: dart run tool/validate_content.dart
      - run: flutter analyze --no-fatal-infos
      - run: flutter test
```

- [ ] **Step 6: Viết `.github/workflows/release.yml`**

```yaml
name: Release APK

on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev
      - run: flutter pub get
      - run: dart run tool/validate_content.dart
      - run: flutter test
      - name: Set up signing
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: |
          echo "$KEYSTORE_BASE64" | base64 -d > android/app/release.jks
          {
            echo "storePassword=$KEYSTORE_PASSWORD"
            echo "keyPassword=$KEY_PASSWORD"
            echo "keyAlias=$KEY_ALIAS"
            echo "storeFile=release.jks"
          } > android/key.properties
      - name: Build APK
        run: flutter build apk --release --build-name="${GITHUB_REF_NAME#v}" --build-number="${{ github.run_number }}"
      - name: Publish release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          cp build/app/outputs/flutter-apk/app-release.apk "xoai-${GITHUB_REF_NAME}.apk"
          gh release create "$GITHUB_REF_NAME" "xoai-${GITHUB_REF_NAME}.apk" --title "$GITHUB_REF_NAME" --generate-notes
```

- [ ] **Step 7: Viết `README.md`**

```markdown
# Lâu đài băng của Xoài

Game học tiếng Anh/tiếng Việt cho bé Xoài (Flutter, Android).

- Thiết kế: `docs/superpowers/specs/2026-11-02-xoai-ice-castle-design.md`
- Chạy test: `flutter test`
- Kiểm tra nội dung: `dart run tool/validate_content.dart`
- Sinh code DB sau khi sửa `lib/core/db/database.dart`: `dart run build_runner build --delete-conflicting-outputs`

## Phát hành bản mới

1. Tăng `version:` trong `pubspec.yaml`.
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. GitHub Actions build APK đã ký và tạo Release; app trên điện thoại báo chấm đỏ ở ổ khóa.

Keystore nằm ở `~/.xoai-keystore/` (không commit). Mất keystore thì không cập nhật đè được app đã cài.
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "ci: signed release builds, CI workflow and README"
```

- [ ] **Step 9: Tạo repo GitHub và đẩy code — HỎI NGƯỜI DÙNG TRƯỚC**

Đây là thao tác công khai (repo public). Xác nhận với người dùng trước khi chạy:
```bash
gh repo create nguyentienloc/mango-game --public --source=. --remote=origin --push
```
Expected: repo được tạo, nhánh `main` được đẩy, workflow CI chạy. Kiểm tra: `gh run watch` → CI xanh.

- [ ] **Step 10: Lưu secrets ký — HỎI NGƯỜI DÙNG TRƯỚC**

```bash
source <(sed 's/^/export /' ~/.xoai-keystore/key.properties)
base64 -i ~/.xoai-keystore/xoai-release.jks | gh secret set KEYSTORE_BASE64
gh secret set KEYSTORE_PASSWORD --body "$storePassword"
gh secret set KEY_PASSWORD --body "$keyPassword"
gh secret set KEY_ALIAS --body "$keyAlias"
gh secret list
```
Expected: `gh secret list` có đủ 4 secret.

- [ ] **Step 11: Phát hành v0.1.0 — HỎI NGƯỜI DÙNG TRƯỚC**

```bash
git tag v0.1.0
git push origin v0.1.0
gh run watch
gh release view v0.1.0
```
Expected: workflow "Release APK" xanh; release `v0.1.0` có file `xoai-v0.1.0.apk`.

- [ ] **Step 12: Cài lên điện thoại (người dùng làm cùng)**

Cài **bản APK từ Release** (đã ký bằng keystore release) để các bản sau cập nhật đè được:
```bash
gh release download v0.1.0 --pattern '*.apk' --dir /tmp/xoai
adb devices
adb install -r /tmp/xoai/xoai-v0.1.0.apk
```
Nếu máy đã có bản debug cài từ `flutter run`, gỡ trước: `adb uninstall vn.xoai.xoai_castle`.

Danh sách kiểm tra trên máy thật:
- [ ] Elsa chào bằng giọng tiếng Việt; chạm Elsa nói tiếng Anh (nếu không có giọng vi-VN: Cài đặt → Hệ thống → Ngôn ngữ → Chuyển văn bản thành giọng nói → Google → cài dữ liệu giọng Tiếng Việt).
- [ ] Chơi hết một lượt 🎈, số ❄️ tăng, chấm nhiệm vụ ngày sáng 1/3.
- [ ] Giữ 🔒 2 giây → phép cộng → khu bố mẹ hiện "Đang dùng bản mới nhất".
- [ ] Màn hình luôn dọc, thanh điều hướng ẩn.

- [ ] **Step 13: Kiểm tra luồng tự cập nhật (tùy chọn nhưng nên làm)**

Đổi `version: 0.1.1+2` trong `pubspec.yaml`, commit, tag `v0.1.1`, push (hỏi người dùng trước). Mở app trên điện thoại → ổ khóa có chấm đỏ → vào khu bố mẹ → "Cập nhật" → tải xong → Android hỏi cài → cài thành công, khu bố mẹ hiện phiên bản `0.1.1`. Lần đầu Android sẽ yêu cầu bật "Cho phép cài ứng dụng từ nguồn này".
