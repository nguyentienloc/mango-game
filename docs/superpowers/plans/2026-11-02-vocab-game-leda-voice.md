# Nhìn hình đoán từ + giọng Leda — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bản v0.2.0: trò chính 🐾 "Nhìn hình đoán từ" (4 thẻ ảnh Fluent Emoji 3D, 45 từ), giọng Leda (Gemini TTS) tạo sẵn và đóng gói, ẩn trò 🎈 sau công tắc của bố mẹ.

**Architecture:** Nội dung từ vựng là các gói JSON `vocab_*` + ảnh PNG trong `content/`. Một hàm Dart thuần `enumerateUtterances` liệt kê mọi câu app có thể nói; công cụ `tool/gen_voice.dart` dùng chính hàm đó gọi Gemini TTS, lưu Opus/OGG + `content/audio/index.json`. `VoiceService` tra `ClipLibrary` trước, phát bằng `ClipPlayer` (just_audio), không có clip thì dùng giọng máy đọc từng đoạn. Trò từ vựng dùng chung `PickSession` (tách từ `FindLetterSession`), `QuestionPicker`, phần thưởng.

**Tech Stack:** Flutter 3.47.9, Dart 3, flutter_riverpod 3.4.3, drift (schema v2), flutter_tts, just_audio, audio_session, crypto (dev, tool), ffmpeg (máy dev), Gemini API `gemini-3.8-flash-tts`.

**Spec:** `docs/superpowers/specs/2026-11-02-vocab-game-leda-voice-design.md`

## Global Constraints

- Nhánh: `feat/vocab-leda-voice`. Package `xoai_castle`, applicationId `vn.xoai.xoai_castle`.
- Phiên bản phát hành: `0.2.0+2`, tag `v0.2.0` (tag là nguồn chính của versionName/versionCode).
- Trò từ vựng: 8 câu/lượt, 4 thẻ/câu, tối đa 3 từ mới/lượt (`maxNew: 3`), khóa mức thuộc `word:<id>`, phiên lưu `game: 'vocab'`.
- Kết quả câu: `firstTry` (+1 mức, +1 ❄️), `retry` (giữ nguyên), `hinted` (−1); +5 ❄️/lượt; nhiệm vụ ngày 3 lượt.
- Câu nói: `vocab_prompt` = en "Find the {word}!"; `vocab_correct` = [en "{Word}!", vi "{Vi}!"]; `vocab_hint` = [vi "{Vi} ở đây nè!", en "{Word}!"]; `game_vocab` = vi "Nhìn hình đoán từ".
- Biến từ vựng: `{word}` (viết thường), `{Word}` (viết hoa chữ đầu), `{vi}`, `{Vi}` (viết hoa chữ đầu).
- Khóa câu nói: mỗi đoạn `lang|text`, các đoạn nối bằng `" || "`.
- Giọng: Vbee (async API), tiếng Việt `hn_female_ngochuyen_full_48k-fhg` (HN – Ngọc Huyền), tiếng Anh `en-US-Neural2-G-Premium` (Sophia), tốc độ 0.9; mỗi đoạn đọc riêng rồi nối (~0,25 s im lặng); file `content/audio/<sha1(key) 16 ký tự hex đầu>.ogg`, Opus mono 32 kbps; index `content/audio/index.json` (`provider`, `voices`, `speed`, `clips`).
- Khóa Vbee đọc từ `~/.config/xoai/vbee.env` (`VBEE_APP_ID`, `VBEE_TOKEN`) hoặc biến môi trường cùng tên; **không bao giờ** in, log hay commit khóa.
- Ảnh: Fluent Emoji 3D (MIT), repo `microsoft/fluentui-emoji` ghim theo commit SHA; lưu `content/images/vocab/<id>.png`; kèm `content/images/vocab/LICENSE-fluentui-emoji.txt` và `THIRD_PARTY_NOTICES.md`.
- DB: `schemaVersion` 2, cột mới `profile.showFindLetter` bool mặc định false, có `MigrationStrategy`.
- Màn chính: 🐾 → 🎈 (chỉ khi bật) → ✏️ → 🗣️ → 🇻🇳; bỏ nút 🐶. Mọi chạm điều hướng phải có tiếng.
- Phải vừa màn 360×640 dp không tràn.
- Chữ hiển thị cho bố mẹ và thông báo lỗi bằng tiếng Việt.
- `flutter analyze --no-fatal-infos` sạch lỗi/cảnh báo và `flutter test` xanh trước mỗi commit.

## File Structure

```
content/
  manifest.json                      + 4 gói vocab_*
  phrases.json                       + vocab_prompt/vocab_correct/vocab_hint, game_vocab mới
  packs/vocab_animals.json, vocab_fruits.json, vocab_vegetables.json, vocab_vehicles.json
  images/vocab/<id>.png (45), LICENSE-fluentui-emoji.txt
  audio/index.json, audio/*.ogg      (sinh bởi tool/gen_voice.dart)
THIRD_PARTY_NOTICES.md
tool/fetch_images.dart               tải ảnh Fluent theo bảng tên
tool/gen_voice.dart                  tạo giọng Leda
tool/validate_content.dart           + kiểm tra audio index
lib/core/content/models.dart         + VocabItem, PhrasePart, Phrase.parts, ContentBundle.vocab
lib/core/content/vocab.dart          vocabVars()
lib/core/content/content_validator.dart  + gói vocab, phrase nhiều đoạn, validateAudioIndex()
lib/core/voice/utterance.dart        Utterance, UtterancePart
lib/core/voice/utterances.dart       enumerateUtterances(), PlannedUtterance, UtteranceKind
lib/core/voice/clip_library.dart     ClipLibrary
lib/core/voice/clip_player.dart      ClipPlayer + JustAudioClipPlayer
lib/core/voice/voice_service.dart    clip trước, giọng máy sau; nhiều đoạn
lib/core/db/database.dart            schema v2 + migration
lib/core/profile/profile_store.dart  + showFindLetter / setShowFindLetter
lib/app/providers.dart               + profileStoreProvider
lib/app/show_find_letter_controller.dart
lib/features/games/pick_session.dart PickQuestion, PickSession, TapResult (tách từ find_letter_logic)
lib/features/games/find_letter/find_letter_logic.dart  dùng PickSession
lib/features/games/vocab/vocab_logic.dart   VocabQuestion, buildVocabRound
lib/features/games/vocab/picture_grid.dart  lưới 2×2 thẻ ảnh
lib/features/games/vocab/vocab_screen.dart
lib/features/home/home_screen.dart   danh sách nút mới
lib/features/parent/parent_screen.dart  + công tắc
lib/main.dart                        nạp ClipLibrary, JustAudioClipPlayer
```

---

### Task 1: Gói từ vựng, ảnh Fluent, validator

**Files:**
- Modify: `lib/core/content/models.dart`, `lib/core/content/content_validator.dart`, `content/manifest.json`, `pubspec.yaml`
- Create: `lib/core/content/vocab.dart`, `content/packs/vocab_animals.json`, `content/packs/vocab_fruits.json`, `content/packs/vocab_vegetables.json`, `content/packs/vocab_vehicles.json`, `tool/fetch_images.dart`, `content/images/vocab/*.png`, `content/images/vocab/LICENSE-fluentui-emoji.txt`, `THIRD_PARTY_NOTICES.md`
- Test: `test/core/content/vocab_test.dart`, `test/core/content/content_validator_test.dart` (thêm case), `test/support/content_fixture.dart` (thêm 1 gói vocab vào fixture)

**Interfaces:**
- Produces:
  - `class VocabItem { String id; String word; String vi; String? image; String emoji; String topic; }` — `topic` = tên gói bỏ tiền tố `vocab_` (ví dụ `animals`)
  - `ContentBundle.vocab: List<VocabItem>` (mọi gói có tên bắt đầu `vocab_`, theo thứ tự trong manifest)
  - `Map<String, String> vocabVars(VocabItem w)` → `{word, Word, vi, Vi}`
  - Validator: lỗi cho gói vocab sai (thiếu trường, `id` trùng giữa các gói, ảnh không có khi truyền `assetPaths`, tổng < 4 từ, không có gói vocab nào)

- [ ] **Step 1: Viết test (failing)**

`test/core/content/vocab_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/vocab.dart';

void main() {
  test('vocabVars capitalises the first letter of word and vi', () {
    const w = VocabItem(id: 'lion', word: 'lion', vi: 'con sư tử', emoji: '🦁', topic: 'animals');
    expect(vocabVars(w), {'word': 'lion', 'Word': 'Lion', 'vi': 'con sư tử', 'Vi': 'Con sư tử'});
  });

  test('the shipped content has 45 vocabulary words with images', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.vocab, hasLength(45));
    expect(bundle.vocab.map((w) => w.id).toSet(), hasLength(45));
    expect(bundle.vocab.map((w) => w.topic).toSet(), {'animals', 'fruits', 'vegetables', 'vehicles'});
    final lion = bundle.vocab.firstWhere((w) => w.id == 'lion');
    expect(lion.vi, 'con sư tử');
    expect(lion.image, 'images/vocab/lion.png');
  });
}
```

Thêm vào `test/support/content_fixture.dart` trong `validFiles()`: manifest `packs` thêm `'vocab_animals': 1`, và file:
```dart
      'packs/vocab_animals.json': jsonEncode({
        'id': 'vocab_animals',
        'version': 1,
        'title_vi': 'Con vật',
        'items': [
          for (final (id, vi) in [('cat', 'con mèo'), ('dog', 'con chó'), ('lion', 'con sư tử'), ('duck', 'con vịt')])
            {'id': id, 'word': id, 'vi': vi, 'image': 'images/vocab/$id.png', 'emoji': '🐾'},
        ],
      }),
```

Thêm vào `test/core/content/content_validator_test.dart`:
```dart
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
```

- [ ] **Step 2: Chạy test, xác nhận fail** — `flutter test test/core/content` → FAIL (chưa có `VocabItem`, `vocab.dart`, validator chưa kiểm tra vocab).

- [ ] **Step 3: Model + `vocabVars`**

Thêm vào `lib/core/content/models.dart`:
```dart
class VocabItem {
  const VocabItem({required this.id, required this.word, required this.vi, required this.emoji, required this.topic, this.image});

  factory VocabItem.fromJson(Map<String, dynamic> json, String topic) => VocabItem(
        id: json['id'] as String,
        word: json['word'] as String,
        vi: json['vi'] as String,
        emoji: json['emoji'] as String,
        image: json['image'] as String?,
        topic: topic,
      );

  final String id;
  final String word;
  final String vi;
  final String emoji;
  final String? image;
  final String topic;
}
```
Trong `ContentBundle`: thêm field `final List<VocabItem> vocab;` (constructor `required this.vocab`), và trong `fromFiles`:
```dart
    final manifest = read('manifest.json');
    final vocab = [
      for (final name in (manifest['packs'] as Map<String, dynamic>).keys)
        if (name.startsWith('vocab_'))
          for (final j in read('packs/$name.json')['items'] as List)
            VocabItem.fromJson(j as Map<String, dynamic>, name.substring('vocab_'.length)),
    ];
```

`lib/core/content/vocab.dart`:
```dart
import 'models.dart';

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Template variables for phrases about one vocabulary word.
Map<String, String> vocabVars(VocabItem w) => {
      'word': w.word,
      'Word': _capitalise(w.word),
      'vi': w.vi,
      'Vi': _capitalise(w.vi),
    };
```

- [ ] **Step 4: Validator**

Trong `validateContent`, sau `_checkLetters(...)`, thêm `_checkVocab(packs.keys, docs, errors, checkImage);` và hàm:
```dart
void _checkVocab(
  Iterable<String> packNames,
  Map<String, Map<String, dynamic>> docs,
  List<String> errors,
  void Function(String where, Object? image) checkImage,
) {
  final names = packNames.where((n) => n.startsWith('vocab_')).toList();
  if (names.isEmpty) {
    errors.add('manifest.json: cần ít nhất một gói từ vựng "vocab_..."');
    return;
  }
  final seen = <String, String>{};
  var total = 0;
  for (final name in names) {
    final path = 'packs/$name.json';
    final items = docs[path]?['items'];
    if (items is! List || items.isEmpty) {
      errors.add('$path: "items" phải là danh sách không rỗng');
      continue;
    }
    for (final (i, item) in items.indexed) {
      final where = '$path items[$i]';
      if (item is! Map<String, dynamic>) {
        errors.add('$where: phải là object');
        continue;
      }
      total++;
      final id = item['id'];
      if (!_nonEmpty(id)) {
        errors.add('$where: thiếu "id"');
      } else if (seen.containsKey(id)) {
        errors.add(seen[id] == path ? '$where: id "$id" bị trùng' : '$where: id "$id" đã có ở gói khác');
      } else {
        seen[id as String] = path;
      }
      for (final field in ['word', 'vi', 'emoji']) {
        if (!_nonEmpty(item[field])) errors.add('$where: thiếu "$field"');
      }
      checkImage(where, item['image']);
    }
  }
  if (total < 4) errors.add('Cần ít nhất 4 từ vựng (hiện có $total)');
}
```

- [ ] **Step 5: Công cụ tải ảnh `tool/fetch_images.dart`**

```dart
import 'dart:io';

/// Downloads Fluent Emoji 3D images (MIT) for the vocabulary into
/// content/images/vocab/<id>.png. Skips files that already exist.
/// Usage: dart run tool/fetch_images.dart
const _commit = 'PIN_ME';
const _base = 'https://raw.githubusercontent.com/microsoft/fluentui-emoji/$_commit';

/// vocabulary id → Fluent asset folder name.
const _folders = {
  'cat': 'Cat face', 'dog': 'Dog face', 'lion': 'Lion', 'elephant': 'Elephant', 'tiger': 'Tiger face',
  'monkey': 'Monkey face', 'rabbit': 'Rabbit face', 'bear': 'Bear', 'fish': 'Fish', 'bird': 'Bird',
  'duck': 'Duck', 'cow': 'Cow face', 'pig': 'Pig face', 'horse': 'Horse face', 'chicken': 'Baby chick',
  'frog': 'Frog', 'giraffe': 'Giraffe', 'zebra': 'Zebra', 'panda': 'Panda', 'penguin': 'Penguin',
  'apple': 'Red apple', 'banana': 'Banana', 'orange': 'Tangerine', 'grapes': 'Grapes', 'watermelon': 'Watermelon',
  'strawberry': 'Strawberry', 'mango': 'Mango', 'pineapple': 'Pineapple', 'pear': 'Pear', 'cherry': 'Cherries',
  'lemon': 'Lemon', 'peach': 'Peach', 'coconut': 'Coconut',
  'carrot': 'Carrot', 'tomato': 'Tomato', 'corn': 'Ear of corn', 'potato': 'Potato', 'broccoli': 'Broccoli',
  'cucumber': 'Cucumber',
  'car': 'Automobile', 'bus': 'Bus', 'train': 'Train', 'airplane': 'Airplane', 'boat': 'Sailboat', 'bicycle': 'Bicycle',
};

Future<void> main() async {
  final dir = Directory('content/images/vocab')..createSync(recursive: true);
  final client = HttpClient();
  try {
    await _download(client, '$_base/LICENSE', File('${dir.path}/LICENSE-fluentui-emoji.txt'));
    for (final MapEntry(key: id, value: folder) in _folders.entries) {
      final file = File('${dir.path}/$id.png');
      if (file.existsSync()) continue;
      final name = '${folder.toLowerCase().replaceAll(' ', '_')}_3d.png';
      await _download(client, '$_base/assets/${Uri.encodeComponent(folder)}/3D/$name', file);
      stdout.writeln('✓ $id ← $folder');
    }
  } finally {
    client.close();
  }
}

Future<void> _download(HttpClient client, String url, File to) async {
  final res = await (await client.getUrl(Uri.parse(url))).close();
  if (res.statusCode != 200) {
    stderr.writeln('❌ $url → HTTP ${res.statusCode}');
    exitCode = 1;
    await res.drain<void>();
    return;
  }
  await res.pipe(to.openWrite());
}
```
Trước khi chạy: lấy SHA mới nhất của nhánh `main` (`gh api repos/microsoft/fluentui-emoji/commits/main -q .sha` hoặc `git ls-remote https://github.com/microsoft/fluentui-emoji main`) và thay `PIN_ME`. Chạy `dart run tool/fetch_images.dart`. Kiểm tra: 45 file PNG, mỗi file 15–60 KB (`ls -la content/images/vocab | wc -l`; `file content/images/vocab/*.png | grep -vc PNG` = 0).

- [ ] **Step 6: Nội dung**

`content/manifest.json` — `packs` thành:
```json
"packs": { "letters_en": 1, "vocab_animals": 1, "vocab_fruits": 1, "vocab_vegetables": 1, "vocab_vehicles": 1 }
```

`content/packs/vocab_animals.json` (mẫu cho cả 4 gói; `image` = `images/vocab/<id>.png`, `word` = `id`):
```json
{
  "id": "vocab_animals",
  "version": 1,
  "title_vi": "Con vật",
  "items": [
    { "id": "cat", "word": "cat", "vi": "con mèo", "image": "images/vocab/cat.png", "emoji": "🐱" },
    { "id": "dog", "word": "dog", "vi": "con chó", "image": "images/vocab/dog.png", "emoji": "🐶" },
    { "id": "lion", "word": "lion", "vi": "con sư tử", "image": "images/vocab/lion.png", "emoji": "🦁" },
    { "id": "elephant", "word": "elephant", "vi": "con voi", "image": "images/vocab/elephant.png", "emoji": "🐘" },
    { "id": "tiger", "word": "tiger", "vi": "con hổ", "image": "images/vocab/tiger.png", "emoji": "🐯" },
    { "id": "monkey", "word": "monkey", "vi": "con khỉ", "image": "images/vocab/monkey.png", "emoji": "🐵" },
    { "id": "rabbit", "word": "rabbit", "vi": "con thỏ", "image": "images/vocab/rabbit.png", "emoji": "🐰" },
    { "id": "bear", "word": "bear", "vi": "con gấu", "image": "images/vocab/bear.png", "emoji": "🐻" },
    { "id": "fish", "word": "fish", "vi": "con cá", "image": "images/vocab/fish.png", "emoji": "🐟" },
    { "id": "bird", "word": "bird", "vi": "con chim", "image": "images/vocab/bird.png", "emoji": "🐦" },
    { "id": "duck", "word": "duck", "vi": "con vịt", "image": "images/vocab/duck.png", "emoji": "🦆" },
    { "id": "cow", "word": "cow", "vi": "con bò", "image": "images/vocab/cow.png", "emoji": "🐮" },
    { "id": "pig", "word": "pig", "vi": "con lợn", "image": "images/vocab/pig.png", "emoji": "🐷" },
    { "id": "horse", "word": "horse", "vi": "con ngựa", "image": "images/vocab/horse.png", "emoji": "🐴" },
    { "id": "chicken", "word": "chicken", "vi": "con gà", "image": "images/vocab/chicken.png", "emoji": "🐤" },
    { "id": "frog", "word": "frog", "vi": "con ếch", "image": "images/vocab/frog.png", "emoji": "🐸" },
    { "id": "giraffe", "word": "giraffe", "vi": "con hươu cao cổ", "image": "images/vocab/giraffe.png", "emoji": "🦒" },
    { "id": "zebra", "word": "zebra", "vi": "con ngựa vằn", "image": "images/vocab/zebra.png", "emoji": "🦓" },
    { "id": "panda", "word": "panda", "vi": "con gấu trúc", "image": "images/vocab/panda.png", "emoji": "🐼" },
    { "id": "penguin", "word": "penguin", "vi": "con chim cánh cụt", "image": "images/vocab/penguin.png", "emoji": "🐧" }
  ]
}
```
`vocab_fruits.json` (`title_vi` "Trái cây"): apple quả táo 🍎 · banana quả chuối 🍌 · orange quả cam 🍊 · grapes chùm nho 🍇 · watermelon quả dưa hấu 🍉 · strawberry quả dâu tây 🍓 · mango quả xoài 🥭 · pineapple quả dứa 🍍 · pear quả lê 🍐 · cherry quả anh đào 🍒 · lemon quả chanh 🍋 · peach quả đào 🍑 · coconut quả dừa 🥥.
`vocab_vegetables.json` ("Rau củ"): carrot củ cà rốt 🥕 · tomato quả cà chua 🍅 · corn bắp ngô 🌽 · potato củ khoai tây 🥔 · broccoli cây súp lơ xanh 🥦 · cucumber quả dưa chuột 🥒.
`vocab_vehicles.json` ("Xe cộ"): car ô tô 🚗 · bus xe buýt 🚌 · train tàu hỏa 🚆 · airplane máy bay ✈️ · boat con thuyền ⛵ · bicycle xe đạp 🚲.

`pubspec.yaml` assets thêm `- content/images/vocab/`.

`THIRD_PARTY_NOTICES.md`:
```markdown
# Third-party notices

## Fluent Emoji (Microsoft)
Vocabulary pictures in `content/images/vocab/` are from https://github.com/microsoft/fluentui-emoji
(3D style), used under the MIT License. Copyright (c) Microsoft Corporation.
Full license text: `content/images/vocab/LICENSE-fluentui-emoji.txt`.
```

- [ ] **Step 7: Chạy test + CLI + analyze**

```bash
flutter test
dart run tool/validate_content.dart
flutter analyze --no-fatal-infos
```
Expected: PASS; "Nội dung hợp lệ ✅".

- [ ] **Step 8: Commit** — `feat: vocabulary packs with Fluent Emoji 3D pictures`

---

### Task 2: Câu nói nhiều đoạn và danh sách mọi câu nói

**Files:**
- Modify: `lib/core/content/models.dart` (`Phrase`, thêm `PhrasePart`), `lib/core/content/content_validator.dart` (`_checkPhrases`, `requiredPhraseIds`), `content/phrases.json`, `lib/core/voice/voice_service.dart`
- Create: `lib/core/voice/utterance.dart`, `lib/core/voice/utterances.dart`
- Test: `test/core/voice/utterance_test.dart`, `test/core/voice/utterances_test.dart`, `test/core/voice/voice_service_test.dart` (thêm case), `test/core/content/content_validator_test.dart` (thêm case)

**Interfaces:**
- Consumes: `VocabItem`, `vocabVars`, `ContentBundle.vocab` (Task 1); `LetterItem`; `Names`.
- Produces:
  - `class PhrasePart { String lang; String text; }`
  - `Phrase` giữ constructor const cũ (`id, lang, text, group, priority`) và thêm `const Phrase.multi({required id, required List<PhrasePart> parts, required group, priority})`; getter `List<PhrasePart> get allParts`. JSON: hoặc `lang`+`text`, hoặc `parts: [{lang, text}]`.
  - `class UtterancePart { String lang; String text; }`; `class Utterance { List<UtterancePart> parts; String get key; String get spokenText; }` — `key` = `parts.map((p) => '${p.lang}|${p.text}').join(' || ')`, `spokenText` = các `text` nối bằng dấu cách.
  - `VoiceService.utterance(String phraseId, {Map<String,String> vars}) → Utterance` (render tên + biến); `say`, `sayGroup` giữ nguyên chữ ký.
  - `enum UtteranceKind { fixed, vocab, letters }`; `class PlannedUtterance { Utterance utterance; UtteranceKind kind; }`; `List<PlannedUtterance> enumerateUtterances(ContentBundle content, Names names)` — không trùng `key`, theo thứ tự: fixed → vocab → letters.
  - Hằng `vocabPhraseIds = ['vocab_prompt', 'vocab_correct', 'vocab_hint']`, `letterPhraseIds = ['find_letter_prompt', 'find_letter_small_prompt', 'letter_example']`.

- [ ] **Step 1: Viết test (failing)**

`test/core/voice/utterance_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/voice/utterance.dart';

void main() {
  test('key and spoken text join the parts', () {
    const u = Utterance([UtterancePart('en', 'Lion!'), UtterancePart('vi', 'Con sư tử!')]);
    expect(u.key, 'en|Lion! || vi|Con sư tử!');
    expect(u.spokenText, 'Lion! Con sư tử!');
  });
}
```

`test/core/voice/utterances_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

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

  test('letters cover upper and lower prompts, small prompts and examples', () {
    final letters = keys(UtteranceKind.letters).toSet();
    expect(letters, containsAll(['en|Find the letter B!', 'en|Find the letter b!', 'en|Find the small b!', 'en|B! B is for Ball!']));
    expect(letters, hasLength(26 * 4));
  });
}
```

Thêm vào `test/core/voice/voice_service_test.dart`:
```dart
  test('multi-part phrases speak each part in its own language', () async {
    final tts = FakeTts();
    final v = VoiceService(
      tts: tts,
      phrases: const {
        'correct': Phrase.multi(id: 'correct', group: 'vocab', parts: [
          PhrasePart('en', '{Word}!'),
          PhrasePart('vi', '{Vi}!'),
        ]),
      },
      names: const Names(en: 'An', vi: 'Xoài'),
    );
    await v.say('correct', vars: {'Word': 'Lion', 'Vi': 'Con sư tử'});
    expect(tts.spoken, [(text: 'Lion!', lang: 'en'), (text: 'Con sư tử!', lang: 'vi')]);
  });

  test('utterance renders names and vars into parts', () {
    final v = voice(FakeTts());
    expect(v.utterance('find', vars: {'letter': 'B'}).key, 'en|Find the letter B, An!');
  });
```

Thêm vào `test/core/content/content_validator_test.dart`:
```dart
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
```

- [ ] **Step 2: Chạy test, xác nhận fail** — `flutter test test/core/voice test/core/content` → FAIL (chưa có các file/kiểu mới).

- [ ] **Step 3: Model `PhrasePart` + `Phrase.multi`**

Trong `lib/core/content/models.dart`, thay class `Phrase` bằng:
```dart
class PhrasePart {
  const PhrasePart(this.lang, this.text);

  final String lang;
  final String text;
}

class Phrase {
  const Phrase({required this.id, required String lang, required String text, required this.group, this.priority = false})
      : _lang = lang,
        _text = text,
        _parts = null;

  const Phrase.multi({required this.id, required List<PhrasePart> parts, required this.group, this.priority = false})
      : _lang = null,
        _text = null,
        _parts = parts;

  factory Phrase.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final group = json['group'] as String;
    final priority = json['priority'] as bool? ?? false;
    final parts = json['parts'] as List?;
    if (parts != null) {
      return Phrase.multi(id: id, group: group, priority: priority, parts: [
        for (final p in parts) PhrasePart((p as Map<String, dynamic>)['lang'] as String, p['text'] as String),
      ]);
    }
    return Phrase(id: id, lang: json['lang'] as String, text: json['text'] as String, group: group, priority: priority);
  }

  final String id;
  final String group;
  final bool priority;
  final String? _lang;
  final String? _text;
  final List<PhrasePart>? _parts;

  List<PhrasePart> get allParts => _parts ?? [PhrasePart(_lang!, _text!)];
}
```
Tìm mọi chỗ dùng `phrase.lang` / `phrase.text` (`grep -rn "\.lang\b\|\.text\b" lib test`) và chuyển sang `allParts`.

- [ ] **Step 4: Validator cho phrase nhiều đoạn**

Trong `_checkPhrases`, thay hai kiểm tra `lang`/`text` bằng:
```dart
    final parts = item['parts'];
    if (parts != null) {
      if (parts is! List || parts.isEmpty) {
        errors.add('$where: "parts" phải là danh sách không rỗng');
      } else {
        for (final (j, part) in parts.indexed) {
          final pw = '$where parts[$j]';
          if (part is! Map<String, dynamic>) {
            errors.add('$pw: phải là object');
            continue;
          }
          if (part['lang'] != 'en' && part['lang'] != 'vi') errors.add('$pw: "lang" phải là "en" hoặc "vi"');
          if (!_nonEmpty(part['text'])) errors.add('$pw: thiếu "text"');
        }
      }
    } else {
      if (item['lang'] != 'en' && item['lang'] != 'vi') errors.add('$where: "lang" phải là "en" hoặc "vi"');
      if (!_nonEmpty(item['text'])) errors.add('$where: thiếu "text"');
    }
```
Thêm `'vocab_prompt', 'vocab_correct', 'vocab_hint'` vào `requiredPhraseIds`.

- [ ] **Step 5: `content/phrases.json`**

Sửa `game_vocab` thành `"text": "Nhìn hình đoán từ"`. Thêm:
```json
    { "id": "vocab_prompt", "lang": "en", "text": "Find the {word}!", "group": "vocab" },
    { "id": "vocab_correct", "group": "vocab", "parts": [ { "lang": "en", "text": "{Word}!" }, { "lang": "vi", "text": "{Vi}!" } ] },
    { "id": "vocab_hint", "group": "vocab", "parts": [ { "lang": "vi", "text": "{Vi} ở đây nè!" }, { "lang": "en", "text": "{Word}!" } ] },
```
Tăng `"version"` của `phrases.json` lên 2 và `files.phrases` trong `manifest.json` lên 2.

- [ ] **Step 6: `lib/core/voice/utterance.dart`**

```dart
class UtterancePart {
  const UtterancePart(this.lang, this.text);

  final String lang;
  final String text;
}

/// Everything spoken for one phrase: one or more parts, each in one language.
class Utterance {
  const Utterance(this.parts);

  final List<UtterancePart> parts;

  /// Stable lookup key for pre-generated audio, e.g. `en|Lion! || vi|Con sư tử!`.
  String get key => parts.map((p) => '${p.lang}|${p.text}').join(' || ');

  String get spokenText => parts.map((p) => p.text).join(' ');
}
```

- [ ] **Step 7: `VoiceService` dựng `Utterance`**

Trong `voice_service.dart`: thêm `Utterance utterance(String phraseId, {Map<String, String> vars = const {}})` (ném `ArgumentError` nếu không có phrase), và `_speak(Phrase, vars)` thành:
```dart
  Utterance _build(Phrase phrase, Map<String, String> vars) =>
      Utterance([for (final p in phrase.allParts) UtterancePart(p.lang, render(p.text, vars))]);

  Future<void> _speak(Phrase phrase, Map<String, String> vars) => _play(_build(phrase, vars));

  Future<void> _play(Utterance u) async {
    final gen = ++_generation;
    await _tts.stop();
    for (final part in u.parts) {
      if (gen != _generation) return;
      await _tts.speak(part.text, lang: part.lang);
    }
  }
```
với field `int _generation = 0;`, và `stop()` tăng `_generation` trước khi dừng: `Future<void> stop() { _generation++; return _tts.stop(); }`. (Một câu mới hoặc `stop()` cắt các đoạn còn lại.)

Thêm test vào `voice_service_test.dart`: gọi `say` câu 2 đoạn với một `GatedTts` (đã có trong `test/support/fakes.dart`) rồi `stop()` khi đoạn 1 đang nói → đoạn 2 không được nói.

- [ ] **Step 8: `lib/core/voice/utterances.dart`**

```dart
import '../content/models.dart';
import '../content/vocab.dart';
import '../profile/names.dart';
import 'utterance.dart';

enum UtteranceKind { fixed, vocab, letters }

class PlannedUtterance {
  const PlannedUtterance(this.utterance, this.kind);

  final Utterance utterance;
  final UtteranceKind kind;
}

const vocabPhraseIds = ['vocab_prompt', 'vocab_correct', 'vocab_hint'];
const letterPhraseIds = ['find_letter_prompt', 'find_letter_small_prompt', 'letter_example'];

final _placeholder = RegExp(r'\{(\w+)\}');

/// Every utterance the app can say, with names and item variables filled in.
/// Used by tool/gen_voice.dart to pre-generate audio and by the voice coverage test.
List<PlannedUtterance> enumerateUtterances(ContentBundle content, Names names) {
  final out = <PlannedUtterance>[];
  final seen = <String>{};

  String render(String template, Map<String, String> vars) {
    final all = {'name_en': names.en, 'name_vi': names.vi, ...vars};
    return template.replaceAllMapped(_placeholder, (m) => all[m[1]] ?? m[0]!);
  }

  void add(String phraseId, Map<String, String> vars, UtteranceKind kind) {
    final phrase = content.phrases[phraseId];
    if (phrase == null) return;
    final u = Utterance([for (final p in phrase.allParts) UtterancePart(p.lang, render(p.text, vars))]);
    if (seen.add(u.key)) out.add(PlannedUtterance(u, kind));
  }

  for (final id in content.phrases.keys) {
    if (vocabPhraseIds.contains(id) || letterPhraseIds.contains(id)) continue;
    add(id, const {}, UtteranceKind.fixed);
  }
  for (final w in content.vocab) {
    for (final id in vocabPhraseIds) {
      add(id, vocabVars(w), UtteranceKind.vocab);
    }
  }
  for (final l in content.lettersEn) {
    add('find_letter_prompt', {'letter': l.char}, UtteranceKind.letters);
    add('find_letter_prompt', {'letter': l.lower}, UtteranceKind.letters);
    add('find_letter_small_prompt', {'letter': l.lower}, UtteranceKind.letters);
    add('letter_example', {'letter': l.char, 'word': l.exampleWord}, UtteranceKind.letters);
  }
  return out;
}
```

- [ ] **Step 9: Chạy test, analyze, CLI** — `flutter test`, `flutter analyze --no-fatal-infos`, `dart run tool/validate_content.dart` → xanh.

- [ ] **Step 10: Commit** — `feat: multi-part phrases and utterance enumeration`

---

### Task 3: Phát clip có sẵn trước giọng máy

**Files:**
- Create: `lib/core/voice/clip_library.dart`, `lib/core/voice/clip_player.dart`
- Modify: `lib/core/voice/voice_service.dart`, `lib/main.dart`, `pubspec.yaml`, `test/support/fakes.dart`
- Test: `test/core/voice/clip_library_test.dart`, `test/core/voice/voice_service_test.dart` (thêm case)

**Interfaces:**
- Consumes: `Utterance` (Task 2), `ContentSource` (giai đoạn 1).
- Produces:
  - `class ClipLibrary { const ClipLibrary(Map<String, String> clips); static const empty; static ClipLibrary parse(String indexJson); static Future<ClipLibrary> load(ContentSource source); String? assetFor(Utterance u); int get length; }` — `assetFor` trả `content/audio/<file>` hoặc null; `load` trả `empty` nếu không đọc/parse được `audio/index.json`.
  - `abstract interface class ClipPlayer { Future<void> play(String assetPath); Future<void> stop(); }`; `class JustAudioClipPlayer implements ClipPlayer { static Future<JustAudioClipPlayer> create(); }`
  - `VoiceService({..., ClipLibrary clips = ClipLibrary.empty, ClipPlayer? player})`
  - Fake: `FakeClipPlayer` (ghi `played`, có `failWith` để ném lỗi, `stops`)

- [ ] **Step 1: Thêm dependency** — `flutter pub add just_audio audio_session`; `pubspec.yaml` assets thêm `- content/audio/`; tạo `content/audio/index.json` tạm:
```json
{ "voice": "Leda", "model": "gemini-3.8-flash-tts", "style": "", "clips": {} }
```

- [ ] **Step 2: Viết test (failing)**

`test/core/voice/clip_library_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/voice/clip_library.dart';
import 'package:xoai_castle/core/voice/utterance.dart';

class _Source implements ContentSource {
  _Source(this.text);
  final String? text;
  @override
  Future<String> readText(String path) async => text ?? (throw StateError('missing'));
}

void main() {
  const lion = Utterance([UtterancePart('en', 'Lion!'), UtterancePart('vi', 'Con sư tử!')]);

  test('finds the asset for a known utterance', () {
    final lib = ClipLibrary.parse('{"clips": {"en|Lion! || vi|Con sư tử!": "abc.ogg"}}');
    expect(lib.assetFor(lion), 'content/audio/abc.ogg');
    expect(lib.assetFor(const Utterance([UtterancePart('en', 'Cat!')])), isNull);
    expect(lib.length, 1);
  });

  test('a missing or broken index gives an empty library', () async {
    expect((await ClipLibrary.load(_Source(null))).length, 0);
    expect((await ClipLibrary.load(_Source('{oops'))).length, 0);
  });
}
```

Thêm vào `test/support/fakes.dart`:
```dart
class FakeClipPlayer implements ClipPlayer {
  final played = <String>[];
  int stops = 0;
  Object? failWith;

  @override
  Future<void> play(String assetPath) async {
    played.add(assetPath);
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  Future<void> stop() async => stops++;
}
```

Thêm vào `voice_service_test.dart`:
```dart
  group('pre-generated clips', () {
    const phrases = {
      'hello': Phrase(id: 'hello', lang: 'vi', text: 'Chào {name_vi}!', group: 'greet'),
      'bye': Phrase(id: 'bye', lang: 'en', text: 'Bye!', group: 'greet'),
    };
    final clips = ClipLibrary.parse('{"clips": {"vi|Chào Xoài!": "hello.ogg"}}');

    VoiceService withClips(FakeTts tts, FakeClipPlayer player) => VoiceService(
          tts: tts, phrases: phrases, names: const Names(en: 'An', vi: 'Xoài'), clips: clips, player: player);

    test('plays the clip instead of TTS when one exists', () async {
      final tts = FakeTts();
      final player = FakeClipPlayer();
      await withClips(tts, player).say('hello');
      expect(player.played, ['content/audio/hello.ogg']);
      expect(tts.spoken, isEmpty);
    });

    test('falls back to TTS when there is no clip', () async {
      final tts = FakeTts();
      final player = FakeClipPlayer();
      await withClips(tts, player).say('bye');
      expect(player.played, isEmpty);
      expect(tts.texts, ['Bye!']);
    });

    test('falls back to TTS when the clip fails to play', () async {
      final tts = FakeTts();
      final player = FakeClipPlayer()..failWith = StateError('decoder');
      await withClips(tts, player).say('hello');
      expect(tts.texts, ['Chào Xoài!']);
    });

    test('stop stops both the clip player and TTS', () async {
      final tts = FakeTts();
      final player = FakeClipPlayer();
      await withClips(tts, player).stop();
      expect(player.stops, 1);
      expect(tts.calls, contains('stop'));
    });
  });
```

- [ ] **Step 3: Chạy test, xác nhận fail** — `flutter test test/core/voice` → FAIL.

- [ ] **Step 4: `lib/core/voice/clip_library.dart`**

```dart
import 'dart:convert';

import '../content/content_repository.dart';
import 'utterance.dart';

/// Pre-generated audio clips (content/audio/index.json), keyed by Utterance.key.
class ClipLibrary {
  const ClipLibrary(this._clips);

  static const empty = ClipLibrary({});

  final Map<String, String> _clips;

  int get length => _clips.length;

  static ClipLibrary parse(String indexJson) {
    final json = jsonDecode(indexJson) as Map<String, dynamic>;
    return ClipLibrary((json['clips'] as Map<String, dynamic>).cast<String, String>());
  }

  /// An unreadable or missing index means no clips: everything falls back to TTS.
  static Future<ClipLibrary> load(ContentSource source) async {
    try {
      return parse(await source.readText('audio/index.json'));
    } on Object {
      return empty;
    }
  }

  String? assetFor(Utterance u) {
    final file = _clips[u.key];
    return file == null ? null : 'content/audio/$file';
  }
}
```

- [ ] **Step 5: `lib/core/voice/clip_player.dart`**

```dart
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

abstract interface class ClipPlayer {
  /// Plays an asset; completes when playback ends or is stopped.
  Future<void> play(String assetPath);

  Future<void> stop();
}

class JustAudioClipPlayer implements ClipPlayer {
  JustAudioClipPlayer._(this._player);

  final AudioPlayer _player;

  static Future<JustAudioClipPlayer> create() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    return JustAudioClipPlayer._(AudioPlayer());
  }

  @override
  Future<void> play(String assetPath) async {
    await _player.stop();
    await _player.setAsset(assetPath);
    // just_audio's play() completes when playback finishes, pauses or stops.
    await _player.play();
  }

  @override
  Future<void> stop() => _player.stop();
}
```
Kiểm tra lại với tài liệu just_audio phiên bản đã cài rằng `play()` hoàn thành khi phát xong; nếu không, chờ `processingState == ProcessingState.completed` qua `playerStateStream` (có `stop()` làm kết thúc).

- [ ] **Step 6: `VoiceService` dùng clip**

Constructor thêm `ClipLibrary clips = ClipLibrary.empty, ClipPlayer? player`. `_play` thành:
```dart
  static const _clipTimeout = Duration(seconds: 15);

  Future<void> _play(Utterance u) async {
    final gen = ++_generation;
    await _tts.stop();
    await _player?.stop();
    final asset = _clips.assetFor(u);
    final player = _player;
    if (asset != null && player != null) {
      try {
        await player.play(asset).timeout(_clipTimeout);
        return;
      } catch (e) {
        debugPrint('Clip failed ($asset): $e — using TTS');
        if (gen != _generation) return;
      }
    }
    for (final part in u.parts) {
      if (gen != _generation) return;
      await _tts.speak(part.text, lang: part.lang);
    }
  }

  Future<void> stop() async {
    _generation++;
    await _player?.stop();
    await _tts.stop();
  }
```
(`debugPrint` từ `package:flutter/foundation.dart`.)

- [ ] **Step 7: `main.dart`**

Sau khi nạp `content`:
```dart
  final clips = await ClipLibrary.load(AssetContentSource());
  final player = await JustAudioClipPlayer.create();
```
và truyền `clips: clips, player: player` vào `VoiceService(...)`.

- [ ] **Step 8: Chạy test, analyze, build** — `flutter test`, `flutter analyze --no-fatal-infos`, `flutter build apk --debug` → xanh.

- [ ] **Step 9: Commit** — `feat: play pre-generated voice clips before device TTS`

---

### Task 4: Công cụ tạo giọng Leda và kiểm tra đủ giọng

**Files:**
- Create: `tool/gen_voice.dart`
- Modify: `lib/core/content/content_validator.dart` (thêm `validateAudioIndex`), `tool/validate_content.dart`, `pubspec.yaml` (dev: `crypto`), `README.md`
- Test: `test/core/content/content_validator_test.dart` (thêm case `validateAudioIndex`)

**Interfaces:**
- Consumes: `enumerateUtterances`, `PlannedUtterance`, `UtteranceKind`, `Utterance` (Task 2); `ContentRepository`, `FileContentSource`; `Names`.
- Produces:
  - `List<String> validateAudioIndex(String indexJson, Set<String> assetPaths)` — lỗi nếu file trong index không tồn tại (`audio/<file>`), hoặc có `audio/*.ogg` không nằm trong index.
  - CLI `dart run tool/gen_voice.dart [--limit N] [--prune] [--dry-run]`.

- [ ] **Step 1: Test (failing)**

Thêm vào `content_validator_test.dart`:
```dart
  test('audio index files must exist and no clip may be orphaned', () {
    const index = '{"clips": {"vi|A": "a.ogg", "vi|B": "b.ogg"}}';
    expect(validateAudioIndex(index, {'audio/a.ogg', 'audio/b.ogg'}), isEmpty);
    expect(validateAudioIndex(index, {'audio/a.ogg'}), contains('audio/index.json: thiếu file "audio/b.ogg"'));
    expect(validateAudioIndex(index, {'audio/a.ogg', 'audio/b.ogg', 'audio/c.ogg'}),
        contains('audio/c.ogg: không có câu nào dùng file này'));
  });
```


- [ ] **Step 2: Chạy test, xác nhận fail** — `flutter test test/core/content` → FAIL (chưa có `validateAudioIndex`).

- [ ] **Step 3: `validateAudioIndex`** (trong `content_validator.dart`)

```dart
/// Checks content/audio/index.json against the files present (paths relative to content/).
List<String> validateAudioIndex(String indexJson, Set<String> assetPaths) {
  final errors = <String>[];
  final Map<String, dynamic> clips;
  try {
    clips = (jsonDecode(indexJson) as Map<String, dynamic>)['clips'] as Map<String, dynamic>;
  } on Object catch (e) {
    return ['audio/index.json: không đọc được ($e)'];
  }
  final used = <String>{};
  for (final file in clips.values) {
    final path = 'audio/$file';
    used.add(path);
    if (!assetPaths.contains(path)) errors.add('audio/index.json: thiếu file "$path"');
  }
  for (final path in assetPaths.where((p) => p.startsWith('audio/') && p.endsWith('.ogg'))) {
    if (!used.contains(path)) errors.add('$path: không có câu nào dùng file này');
  }
  return errors;
}
```
`tool/validate_content.dart`: nếu `snapshot.json['audio/index.json']` có thì cộng thêm `validateAudioIndex(...)` vào danh sách lỗi.

- [ ] **Step 4: `tool/gen_voice.dart`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

/// Pre-generates the Leda voice for every utterance (Gemini TTS) into
/// content/audio/*.ogg + content/audio/index.json. Resumable: skips clips that
/// already exist. The API key is read from ~/.config/xoai/gemini_api_key or
/// $GEMINI_API_KEY and is never written or printed.
///
///   dart run tool/gen_voice.dart [--limit N] [--prune] [--dry-run]
const _model = 'gemini-3.8-flash-tts';
const _voice = 'Leda';
const _style = 'a warm, cheerful young woman speaking slowly and clearly to a 5-year-old girl';
const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/interactions';

Future<void> main(List<String> args) async {
  final limitIdx = args.indexOf('--limit');
  final limit = limitIdx >= 0 ? int.parse(args[limitIdx + 1]) : null;
  final prune = args.contains('--prune');
  final dryRun = args.contains('--dry-run');

  final content = await ContentRepository(FileContentSource('content')).load();
  final d = content.profileDefaults;
  final planned = enumerateUtterances(content, Names(en: d.nameEn, vi: d.nameVi));

  final dir = Directory('content/audio')..createSync(recursive: true);
  final indexFile = File('${dir.path}/index.json');
  final clips = indexFile.existsSync()
      ? ((jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>)['clips'] as Map<String, dynamic>)
          .cast<String, String>()
      : <String, String>{};

  void saveIndex() {
    final sorted = Map.fromEntries(clips.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    indexFile.writeAsStringSync(const JsonEncoder.withIndent('  ')
        .convert({'voice': _voice, 'model': _model, 'style': _style, 'clips': sorted}));
  }

  final todo = [
    for (final p in planned)
      if (!(clips.containsKey(p.utterance.key) && File('${dir.path}/${clips[p.utterance.key]}').existsSync())) p,
  ];
  stdout.writeln('${planned.length} utterances, ${todo.length} to generate.');
  if (dryRun) {
    for (final p in todo) {
      stdout.writeln('  [${p.kind.name}] ${p.utterance.key}');
    }
    return;
  }

  final key = _readKey();
  final client = HttpClient();
  var done = 0;
  try {
    for (final p in todo) {
      if (limit != null && done >= limit) break;
      final file = '${sha1.convert(utf8.encode(p.utterance.key)).toString().substring(0, 16)}.ogg';
      final wav = await _tts(client, key, p.utterance.spokenText);
      await _toOgg(wav, File('${dir.path}/$file'));
      clips[p.utterance.key] = file;
      saveIndex();
      done++;
      stdout.writeln('✓ ${todo.length - done} left  [${p.kind.name}] ${p.utterance.spokenText}');
    }
  } on _DailyQuotaExceeded catch (e) {
    stderr.writeln('⏸ Hết lượt trong ngày ($e). Chạy lại sau; đã tạo $done câu.');
    exitCode = 2;
  } finally {
    client.close();
    saveIndex();
  }

  if (prune) {
    final keep = {for (final p in planned) p.utterance.key};
    clips.removeWhere((k, _) => !keep.contains(k));
    final files = clips.values.toSet();
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.ogg') && !files.contains(name)) f.deleteSync();
    }
    saveIndex();
  }
}

String _readKey() {
  final env = Platform.environment['GEMINI_API_KEY'];
  if (env != null && env.trim().isNotEmpty) return env.trim();
  final file = File('${Platform.environment['HOME']}/.config/xoai/gemini_api_key');
  if (!file.existsSync()) {
    stderr.writeln('Thiếu key: tạo ~/.config/xoai/gemini_api_key hoặc đặt GEMINI_API_KEY');
    exit(1);
  }
  return file.readAsStringSync().trim();
}

class _DailyQuotaExceeded implements Exception {
  _DailyQuotaExceeded(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Calls Gemini TTS and returns WAV bytes. Waits and retries on per-minute
/// rate limits; throws _DailyQuotaExceeded when the daily quota is used up.
Future<List<int>> _tts(HttpClient client, String key, String text) async {
  final body = jsonEncode({
    'model': _model,
    'input': [
      {
        'type': 'user_input',
        'content': [
          {
            'type': 'text',
            'text': text,
            'annotations': [
              {'type': 'speech_metadata', 'style': _style},
            ],
          },
        ],
      },
    ],
    'response_format': {'type': 'audio'},
    'generation_config': {
      'speech_config': [
        {'voice': _voice},
      ],
    },
  });
  for (var attempt = 0; attempt < 10; attempt++) {
    final req = await client.postUrl(Uri.parse(_endpoint));
    req.headers
      ..set('x-goog-api-key', key)
      ..contentType = ContentType.json;
    req.add(utf8.encode(body));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final audio = [
        for (final step in json['steps'] as List)
          if ((step as Map)['type'] == 'model_output')
            for (final c in step['content'] as List)
              if ((c as Map)['type'] == 'audio') c,
      ].last;
      return base64Decode(audio['data'] as String);
    }
    if (res.statusCode == 429) {
      final retry = RegExp(r'retry in (\d+)').firstMatch(text);
      if (retry == null || text.toLowerCase().contains('per day')) throw _DailyQuotaExceeded('HTTP 429');
      await Future<void>.delayed(Duration(seconds: int.parse(retry[1]!) + 3));
      continue;
    }
    throw HttpException('Gemini TTS HTTP ${res.statusCode}: ${text.length > 300 ? text.substring(0, 300) : text}');
  }
  throw const HttpException('Gemini TTS: too many retries');
}

Future<void> _toOgg(List<int> wav, File out) async {
  final tmp = File('${Directory.systemTemp.path}/xoai-${DateTime.now().microsecondsSinceEpoch}.wav')
    ..writeAsBytesSync(wav);
  try {
    final r = await Process.run('ffmpeg', [
      '-y', '-loglevel', 'error', '-i', tmp.path,
      '-ac', '1', '-c:a', 'libopus', '-b:a', '32k', '-application', 'voip', out.path,
    ]);
    if (r.exitCode != 0) throw ProcessException('ffmpeg', [], '${r.stderr}', r.exitCode);
  } finally {
    tmp.deleteSync();
  }
}
```
Thêm dev dependency: `flutter pub add dev:crypto`. Lưu ý thông báo HTTP 429 lỗi có thể chứa key? Không — key chỉ nằm trong header; không in header.

- [ ] **Step 5: Thử nhỏ** — `dart run tool/gen_voice.dart --dry-run` (in số câu, không gọi API), rồi `dart run tool/gen_voice.dart --limit 2`; kiểm tra 2 file `.ogg` (`ffprobe -hide_banner content/audio/*.ogg` → opus, mono) và `index.json` có 2 khóa. Phát thử một file bằng `afplay` không được (afplay không đọc opus) → dùng `ffplay -nodisp -autoexit content/audio/<file>.ogg` nếu cần.

- [ ] **Step 6: README** — thêm mục:
```markdown
## Giọng Leda (Gemini TTS)

Sau khi sửa nội dung (`content/phrases.json`, `content/packs/*`): `dart run tool/gen_voice.dart`
(key ở `~/.config/xoai/gemini_api_key`, không commit). Gói miễn phí: 3 câu/phút; script tự đợi và chạy tiếp được.
`--prune` xóa clip không còn dùng. Test `test/content/voice_coverage_test.dart` báo đỏ nếu thiếu giọng.
```

- [ ] **Step 7: Commit** — tool + 2 clip thử + index: `feat: Leda voice generator`. (Test kiểm tra đủ giọng được thêm ở Task 8, sau khi đã tạo đủ clip, để suite luôn xanh.)

---

### Task 5: DB schema v2 và công tắc "Hiện trò Tìm chữ cái"

**Files:**
- Modify: `lib/core/db/database.dart` (+ sinh lại `.g.dart`), `lib/core/profile/profile_store.dart`, `lib/app/providers.dart`, `lib/features/parent/parent_screen.dart`, `test/support/fakes.dart`, `test/support/test_app.dart`
- Create: `lib/app/show_find_letter_controller.dart`
- Test: `test/core/db/migration_test.dart`, `test/core/db/stores_test.dart` (thêm case), `test/features/parent/parent_screen_test.dart` (thêm case)

**Interfaces:**
- Produces:
  - `ProfileStore.showFindLetter() → Future<bool>`, `ProfileStore.setShowFindLetter(bool) → Future<void>`
  - `profileStoreProvider = Provider<ProfileStore>((ref) => DriftProfileStore(ref.watch(databaseProvider)))`
  - `showFindLetterProvider = AsyncNotifierProvider<ShowFindLetterController, bool>`; `Future<void> ShowFindLetterController.set(bool value)`
  - Fake `MemoryProfileStore({bool showFindLetter = false})` (cũng implement `loadNames` trả An/Xoài); `testApp(..., ProfileStore? profile)`

- [ ] **Step 1: Ghi lại DDL v1 của bảng `profile`** — trước khi sửa, copy câu `CREATE TABLE` của `profile` từ `lib/core/db/database.g.dart` (hoặc mở DB v1 bằng `NativeDatabase.memory()` và đọc `sqlite_master`) để dùng trong test migration.

- [ ] **Step 2: Test (failing)**

`test/core/db/migration_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/db/database.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';

/// DDL of the `profile` table at schema v1 (copied from the v1 generated code).
const _profileV1 = 'PASTE_V1_CREATE_TABLE_PROFILE_HERE';

void main() {
  test('upgrading from v1 keeps the profile and adds showFindLetter = false', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute(_profileV1);
      raw.execute("INSERT INTO profile (id, name_en, name_vi, daily_limit_min) VALUES (1, 'An', 'Xoài', 20)");
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(db.close);

    final store = DriftProfileStore(db);
    expect(await store.showFindLetter(), isFalse);
    final row = await db.select(db.profile).getSingle();
    expect([row.nameEn, row.nameVi, row.dailyLimitMin], ['An', 'Xoài', 20]);
  });
}
```
(`_profileV1` thay bằng DDL thật ở Step 1; không để chuỗi giữ chỗ trong commit.)

Thêm vào `stores_test.dart`:
```dart
  test('showFindLetter defaults to false and can be toggled', () async {
    final store = DriftProfileStore(db);
    await store.loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
    expect(await store.showFindLetter(), isFalse);
    await store.setShowFindLetter(true);
    expect(await DriftProfileStore(db).showFindLetter(), isTrue);
  });
```

Thêm vào `parent_screen_test.dart` (dùng `testApp(..., profile: MemoryProfileStore())`):
```dart
  testWidgets('the find-letter switch is off by default and saves when toggled', (tester) async {
    final profile = MemoryProfileStore();
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const ParentScreen(), profile: profile));
    await tester.pump();
    final tile = find.widgetWithText(SwitchListTile, 'Hiện trò Tìm chữ cái');
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pump();
    expect(profile.show, isTrue);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });
```

- [ ] **Step 3: Chạy test, xác nhận fail.**

- [ ] **Step 4: Schema v2**

Trong bảng `Profile` thêm `BoolColumn get showFindLetter => boolean().withDefault(const Constant(false))();`. Trong `AppDatabase`:
```dart
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(profile, profile.showFindLetter);
        },
      );
```
Chạy `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 5: Store + provider + controller**

`ProfileStore` thêm hai method; `DriftProfileStore`:
```dart
  @override
  Future<bool> showFindLetter() async {
    final row = await (_db.select(_db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();
    return row?.showFindLetter ?? false;
  }

  @override
  Future<void> setShowFindLetter(bool value) async {
    await (_db.update(_db.profile)..where((t) => t.id.equals(1))).write(ProfileCompanion(showFindLetter: Value(value)));
  }
```
`providers.dart`: `final profileStoreProvider = Provider<ProfileStore>((ref) => DriftProfileStore(ref.watch(databaseProvider)));`

`lib/app/show_find_letter_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Parent switch: show the 🎈 find-letter game on the home screen.
final showFindLetterProvider = AsyncNotifierProvider<ShowFindLetterController, bool>(ShowFindLetterController.new);

class ShowFindLetterController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(profileStoreProvider).showFindLetter();

  Future<void> set(bool value) async {
    await ref.read(profileStoreProvider).setShowFindLetter(value);
    state = AsyncData(value);
  }
}
```
`fakes.dart`:
```dart
class MemoryProfileStore implements ProfileStore {
  MemoryProfileStore({this.show = false});

  bool show;

  @override
  Future<Names> loadNames(ProfileDefaults defaults) async => const Names(en: 'An', vi: 'Xoài');

  @override
  Future<bool> showFindLetter() async => show;

  @override
  Future<void> setShowFindLetter(bool value) async => show = value;
}
```
`testApp`: thêm tham số `ProfileStore? profile` và override `profileStoreProvider.overrideWithValue(profile ?? MemoryProfileStore())`.

- [ ] **Step 6: Công tắc trong `ParentScreen`** — thêm sau tile phiên bản:
```dart
          SwitchListTile(
            secondary: const Icon(Icons.abc),
            title: const Text('Hiện trò Tìm chữ cái'),
            subtitle: const Text('Trò 🎈 tìm chữ cái tiếng Anh, dành cho khi bé đã thuộc mặt chữ'),
            value: ref.watch(showFindLetterProvider).value ?? false,
            onChanged: (v) => ref.read(showFindLetterProvider.notifier).set(v),
          ),
```

- [ ] **Step 7: Chạy test, analyze** → xanh. **Commit** — `feat: schema v2 with parent switch for the find-letter game`

---

### Task 6: `PickSession` dùng chung và logic trò từ vựng

**Files:**
- Create: `lib/features/games/pick_session.dart`, `lib/features/games/vocab/vocab_logic.dart`
- Modify: `lib/features/games/find_letter/find_letter_logic.dart`
- Test: `test/features/vocab/vocab_logic_test.dart` (mới); `test/features/find_letter/find_letter_logic_test.dart` phải xanh không sửa

**Interfaces:**
- Consumes: `VocabItem` (Task 1), `QuestionPicker`, `ItemStat`, `AnswerOutcome`.
- Produces:
  - `abstract interface class PickQuestion { String get key; String get answer; }`
  - `enum TapResult { correct, wrong, ignored }`; `class PickSession<Q extends PickQuestion>` (chuyển nguyên logic `FindLetterSession`)
  - `find_letter_logic.dart`: `FindLetterQuestion implements PickQuestion`; `typedef FindLetterSession = PickSession<FindLetterQuestion>;`; `export '../pick_session.dart' show PickSession, TapResult;`
  - `class VocabQuestion implements PickQuestion { VocabItem item; List<VocabItem> options; String get key => 'word:${item.id}'; String get answer => item.id; }`
  - `List<VocabQuestion> buildVocabRound({required List<VocabItem> words, required Map<String, ItemStat> stats, required QuestionPicker picker, required Random random, int count = 8, int optionCount = 4, int maxNew = 3})`

- [ ] **Step 1: Test (failing)** — `test/features/vocab/vocab_logic_test.dart`:
```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/pick_session.dart';
import 'package:xoai_castle/features/games/vocab/vocab_logic.dart';

final words = [
  for (final id in ['cat', 'dog', 'lion', 'duck', 'cow', 'pig', 'apple', 'banana', 'car', 'bus'])
    VocabItem(id: id, word: id, vi: 'vi $id', emoji: '⭐', topic: 't'),
];

List<VocabQuestion> round(Map<String, ItemStat> stats, [int seed = 1]) =>
    buildVocabRound(words: words, stats: stats, picker: QuestionPicker(Random(seed)), random: Random(seed));

void main() {
  test('a round has 8 questions with 4 distinct options including the answer', () {
    for (var seed = 0; seed < 20; seed++) {
      final qs = round(const {}, seed);
      expect(qs, hasLength(8));
      for (final q in qs) {
        expect(q.options, hasLength(4));
        expect(q.options.map((o) => o.id).toSet(), hasLength(4));
        expect(q.options.map((o) => o.id), contains(q.answer));
        expect(q.key, 'word:${q.item.id}');
      }
      for (var i = 1; i < qs.length; i++) {
        expect(qs[i].key, isNot(qs[i - 1].key));
      }
    }
  });

  test('a fresh player meets at most 3 new words per round', () {
    for (var seed = 0; seed < 20; seed++) {
      expect(round(const {}, seed).map((q) => q.item.id).toSet().length, lessThanOrEqualTo(3));
    }
  });

  test('known words are mixed in', () {
    final stats = {for (final w in words.take(6)) 'word:${w.id}': ItemStat(key: 'word:${w.id}', mastery: 1)};
    final ids = round(stats).map((q) => q.item.id).toSet();
    expect(ids.where((id) => !stats.containsKey('word:$id')).length, lessThanOrEqualTo(3));
    expect(ids.length, greaterThan(3));
  });

  test('the shared session scores taps on vocabulary questions', () {
    final s = PickSession(round(const {}));
    final wrong = s.current.options.firstWhere((o) => o.id != s.current.answer).id;
    expect(s.tap(wrong), TapResult.wrong);
    expect(s.tap(wrong), TapResult.wrong);
    expect(s.showHint, isTrue);
    expect(s.tap(s.current.answer), TapResult.correct);
    expect(s.outcomes, [AnswerOutcome.hinted]);
  });
}
```

- [ ] **Step 2: Chạy, xác nhận fail.**

- [ ] **Step 3: `pick_session.dart`** — chuyển nguyên `TapResult` và class `FindLetterSession` từ `find_letter_logic.dart` sang đây, đổi tên thành `PickSession<Q extends PickQuestion>` (giữ đủ: `questions`, `outcomes`, `index`, `isFinished`, `current`, `showHint`, `firstTryCount`, `tap`, `next`, cờ `_answered`), thêm:
```dart
abstract interface class PickQuestion {
  /// Mastery key, e.g. `word:lion`.
  String get key;

  /// The option value that counts as correct.
  String get answer;
}
```
Trong `find_letter_logic.dart`: xóa `TapResult` + `FindLetterSession`, thêm `import '../pick_session.dart';`, `export '../pick_session.dart' show PickSession, TapResult;`, `class FindLetterQuestion implements PickQuestion` (thêm `@override` cho `key`, `answer`), và `typedef FindLetterSession = PickSession<FindLetterQuestion>;`.

- [ ] **Step 4: `vocab_logic.dart`**
```dart
import 'dart:math';

import '../../../core/content/models.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';
import '../pick_session.dart';

class VocabQuestion implements PickQuestion {
  const VocabQuestion({required this.item, required this.options});

  final VocabItem item;

  /// Pictures on the four cards, answer included, in display order.
  final List<VocabItem> options;

  @override
  String get key => 'word:${item.id}';

  @override
  String get answer => item.id;
}

List<VocabQuestion> buildVocabRound({
  required List<VocabItem> words,
  required Map<String, ItemStat> stats,
  required QuestionPicker picker,
  required Random random,
  int count = 8,
  int optionCount = 4,
  int maxNew = 3,
}) {
  final byKey = {for (final w in words) 'word:${w.id}': w};
  final keys = picker.pick(candidates: byKey.keys.toList(), stats: stats, count: count, maxNew: maxNew);
  return [
    for (final k in keys)
      () {
        final item = byKey[k]!;
        final others = words.where((w) => w.id != item.id).toList()..shuffle(random);
        final options = [item, ...others.take(optionCount - 1)]..shuffle(random);
        return VocabQuestion(item: item, options: options);
      }(),
  ];
}
```

- [ ] **Step 5: Chạy toàn bộ test** (find-letter logic + screen test phải xanh không sửa), analyze. **Commit** — `feat: shared pick session and vocabulary round logic`

---

### Task 7: Màn chơi 🐾 và màn chính mới

**Files:**
- Create: `lib/features/games/vocab/picture_grid.dart`, `lib/features/games/vocab/vocab_screen.dart`
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/vocab/vocab_screen_test.dart`, `test/features/home/home_screen_test.dart` (sửa các test dùng 🎈 / 🐶)

**Interfaces:**
- Consumes: `buildVocabRound`, `VocabQuestion`, `PickSession`, `TapResult` (Task 6); `vocabVars` (Task 1); `showFindLetterProvider` (Task 5); providers, `rewardStateProvider`, `RewardScreen`, `SessionRecord`, `dayKey`, widget dùng chung (giai đoạn 1).
- Produces: `VocabScreen`; `PictureGrid({required List<VocabItem> options, required ValueChanged<String> onTap, String? hint, String? shaking, String? burst})` — mỗi thẻ có `Key('card-<id>')`.

- [ ] **Step 1: Test (failing)** — `test/features/vocab/vocab_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/vocab/vocab_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

final _prompt = RegExp(r'^Find the (.+)!$');

List<String> asked(FakeTts tts) => [
      for (final t in tts.texts)
        if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!,
    ];

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  String idFor(String word) => content.vocab.firstWhere((w) => w.word == word).id;

  testWidgets('a full round of correct taps ends on the reward screen', (tester) async {
    final tts = FakeTts();
    final sessions = MemorySessionStore();
    final rewards = MemoryRewardStore();
    final stats = MemoryItemStatsStore();
    await tester.pumpWidget(testApp(
        content: content, tts: tts, home: const VocabScreen(), sessions: sessions, rewards: rewards, itemStats: stats));
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 8; i++) {
      final words = asked(tts);
      expect(words, hasLength(i + 1), reason: 'question ${i + 1}');
      await tester.tap(find.byKey(Key('card-${idFor(words.last)}')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+13 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'vocab');
    expect(stats.stats.keys.every((k) => k.startsWith('word:')), isTrue);
  });

  testWidgets('a correct tap says the English word then the Vietnamese meaning', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const VocabScreen()));
    await tester.pump();
    await tester.pump();
    final word = asked(tts).single;
    final item = content.vocab.firstWhere((w) => w.word == word);
    await tester.tap(find.byKey(Key('card-${item.id}')));
    await tester.pump();
    final capital = word[0].toUpperCase() + word.substring(1);
    final vi = item.vi[0].toUpperCase() + item.vi.substring(1);
    expect(tts.spoken, containsAllInOrder([(text: '$capital!', lang: 'en'), (text: '$vi!', lang: 'vi')]));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('two wrong taps light up the right card and give the hint', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const VocabScreen()));
    await tester.pump();
    await tester.pump();
    final word = asked(tts).single;
    final item = content.vocab.firstWhere((w) => w.word == word);
    final wrongCard = find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('card-') && (w.key! as ValueKey<String>).value != 'card-${item.id}');
    await tester.tap(wrongCard.first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(wrongCard.first);
    await tester.pump(const Duration(milliseconds: 500));
    final vi = item.vi[0].toUpperCase() + item.vi.substring(1);
    expect(tts.texts, contains('$vi ở đây nè!'));
    expect(find.byKey(Key('glow-${item.id}')), findsOneWidget);
  });

  testWidgets('fits a 360x640 phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const VocabScreen()));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
```
Sửa `home_screen_test.dart`:
- test "the balloon button opens the find-letter game" → thành "the paw button opens the vocabulary game": tap `'🐾'`, expect `VocabScreen`, expect spoken 'Nhìn hình đoán từ'.
- test double-tap: dùng `'🐾'` và `VocabScreen`.
- thêm test: mặc định không có `'🎈'` và không có `'🐶'`; với `profile: MemoryProfileStore(show: true)` thì có `'🎈'`.

- [ ] **Step 2: Chạy, xác nhận fail.**

- [ ] **Step 3: `picture_grid.dart`**
```dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/content/models.dart';

/// Four picture cards in a 2×2 grid. Cards are as big as fit (max 200 dp).
class PictureGrid extends StatelessWidget {
  const PictureGrid({super.key, required this.options, required this.onTap, this.hint, this.shaking, this.burst});

  final List<VocabItem> options;
  final ValueChanged<String> onTap;
  final String? hint;
  final String? shaking;
  final String? burst;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 16.0;
      final side = min(200.0, min((c.maxWidth - gap * 3) / 2, (c.maxHeight - gap * 3) / 2));
      return Center(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final o in options) _Card(item: o, side: side, grid: this)],
        ),
      );
    });
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.side, required this.grid});

  final VocabItem item;
  final double side;
  final PictureGrid grid;

  @override
  Widget build(BuildContext context) {
    final glow = grid.hint == item.id;
    final burst = grid.burst == item.id;
    final shaking = grid.shaking == item.id;
    final image = item.image;
    Widget picture = image == null
        ? Text(item.emoji, style: TextStyle(fontSize: side * 0.55))
        : Image.asset('content/$image',
            width: side * 0.8,
            height: side * 0.8,
            errorBuilder: (_, __, ___) => Text(item.emoji, style: TextStyle(fontSize: side * 0.55)));
    return GestureDetector(
      key: Key('card-${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => grid.onTap(item.id),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(shaking),
        tween: Tween(begin: 0, end: shaking ? 1 : 0),
        duration: const Duration(milliseconds: 400),
        builder: (context, t, child) => Transform.translate(offset: Offset(sin(t * pi * 6) * 8, 0), child: child),
        child: AnimatedScale(
          scale: burst ? 1.12 : 1,
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: glow ? Key('glow-${item.id}') : null,
            width: side,
            height: side,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: glow
                  ? const [BoxShadow(color: IceColors.glow, blurRadius: 28, spreadRadius: 10)]
                  : [BoxShadow(color: IceColors.deep.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))],
              border: burst ? Border.all(color: IceColors.frost, width: 6) : null,
            ),
            child: picture,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: `vocab_screen.dart`** — cùng cấu trúc `FindLetterScreen` (đã có ở `lib/features/games/find_letter/find_letter_screen.dart`: `_guard`, `_finishing`, `PopScope`, 🏠 nói `go_home`, `_finish` lưu phiên + `completeRound` + `pushReplacement(RewardScreen)`), với các khác biệt sau, viết đầy đủ:
```dart
class VocabScreen extends ConsumerStatefulWidget {
  const VocabScreen({super.key});

  @override
  ConsumerState<VocabScreen> createState() => _VocabScreenState();
}

class _VocabScreenState extends ConsumerState<VocabScreen> {
  PickSession<VocabQuestion>? _session;
  Map<String, ItemStat> _stats = {};
  late final DateTime _startedAt;
  bool _busy = true;
  String? _shaking;
  String? _burst;

  VoiceService get _voice => ref.read(voiceProvider);

  bool get _finishing {
    final s = _session;
    return _burst != null && s != null && s.index == s.questions.length - 1;
  }

  @override
  void initState() {
    super.initState();
    _startedAt = ref.read(clockProvider)();
    _guard(_start);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('Vocab error: $e\n$st');
      if (!mounted) return;
      await _voice.say('error_home');
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    final random = ref.read(randomProvider);
    _stats = await ref.read(itemStatsStoreProvider).loadByPrefix('word:');
    final questions = buildVocabRound(
      words: ref.read(contentProvider).vocab,
      stats: _stats,
      picker: QuestionPicker(random),
      random: random,
    );
    if (!mounted) return;
    setState(() => _session = PickSession(questions));
    await _ask();
  }

  Map<String, String> get _vars => vocabVars(_session!.current.item);

  Future<void> _ask() async {
    setState(() => _busy = false);
    await _voice.say('vocab_prompt', vars: _vars);
  }

  void _onTap(String id) {
    if (_busy) return;
    _guard(() => _handleTap(id));
  }

  Future<void> _handleTap(String id) async {
    final session = _session!;
    final result = session.tap(id);
    if (result == TapResult.wrong) {
      setState(() => _shaking = id);
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shaking = null);
      });
      if (session.showHint) {
        setState(() {});
        await _voice.say('vocab_hint', vars: _vars);
      } else {
        await _voice.sayGroup('try_again');
      }
      return;
    }
    if (result != TapResult.correct) return;

    final q = session.current;
    setState(() {
      _busy = true;
      _burst = id;
    });
    final stat = (_stats[q.key] ?? ItemStat(key: q.key)).apply(session.outcomes.last, ref.read(clockProvider)());
    _stats[q.key] = stat;
    await ref.read(itemStatsStoreProvider).save(stat);
    await Future.wait([
      _voice.say('vocab_correct', vars: _vars),
      Future<void>.delayed(const Duration(milliseconds: 800)),
    ]);
    if (!mounted) return;
    session.next();
    setState(() => _burst = null);
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
          game: 'vocab',
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
    return PopScope(
      canPop: !_finishing,
      child: Scaffold(
        body: IceBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    BigButton(
                      emoji: '🏠',
                      size: 64,
                      onTap: () {
                        if (_finishing) return;
                        _voice.say('go_home');
                        Navigator.of(context).pop();
                      },
                    ),
                    const Spacer(),
                    Text(
                      '${session.index + 1}/${session.questions.length}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: IceColors.deep),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _voice.say('vocab_prompt', vars: _vars),
                child: const CharacterView(id: 'elsa', size: 110),
              ),
              Expanded(
                child: PictureGrid(
                  key: ValueKey(session.index),
                  options: q.options,
                  onTap: _onTap,
                  hint: session.showHint ? q.answer : null,
                  shaking: _shaking,
                  burst: _burst,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```
(Import giống `find_letter_screen.dart`, thay phần find-letter bằng `vocab_logic.dart`, `picture_grid.dart`, `pick_session.dart`, `core/content/vocab.dart`.)

- [ ] **Step 5: Màn chính** — trong `home_screen.dart`, bỏ `_games` cố định; trong `build`:
```dart
    final showFindLetter = ref.watch(showFindLetterProvider).value ?? false;
    final games = <_GameEntry>[
      _GameEntry('🐾', 'game_vocab', (_) => const VocabScreen()),
      if (showFindLetter) _GameEntry('🎈', 'game_find_letter', (_) => const FindLetterScreen()),
      const _GameEntry('✏️', 'game_trace'),
      const _GameEntry('🗣️', 'game_talk'),
      const _GameEntry('🇻🇳', 'game_vi'),
    ];
```
và dùng `games` thay `_games`.

- [ ] **Step 6: Chạy toàn bộ test, analyze, `flutter build apk --debug`** → xanh. **Commit** — `feat: picture vocabulary game as the main game`

---

### Task 8 (controller): Tạo giọng đầy đủ, phát hành v0.2.0, cập nhật qua app

Không giao cho subagent (cần key, chạy lâu, thao tác công khai).

- [ ] **Step 1:** `dart run tool/gen_voice.dart` chạy nền (≈ 90 phút với 3 câu/phút); nếu dừng vì hết quota ngày → báo người dùng, chạy tiếp hôm sau.
- [ ] **Step 2:** `dart run tool/gen_voice.dart --prune`; `dart run tool/validate_content.dart`; tạo test kiểm tra đủ giọng dưới đây; `flutter test` (xanh); nghe thử vài file.

`test/content/voice_coverage_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

/// Every fixed and vocabulary utterance must have a Leda clip before release.
/// Letter-game clips are optional while that game is hidden: only reported.
void main() {
  test('every fixed and vocabulary utterance has a generated clip', () async {
    final content = await ContentRepository(FileContentSource('content')).load();
    final defaults = content.profileDefaults;
    final planned = enumerateUtterances(content, Names(en: defaults.nameEn, vi: defaults.nameVi));
    final clips = (jsonDecode(File('content/audio/index.json').readAsStringSync())['clips'] as Map).cast<String, String>();

    bool has(PlannedUtterance p) {
      final file = clips[p.utterance.key];
      return file != null && File('content/audio/$file').existsSync();
    }

    final missing = [for (final p in planned) if (p.kind != UtteranceKind.letters && !has(p)) p.utterance.key];
    final missingLetters = planned.where((p) => p.kind == UtteranceKind.letters && !has(p)).length;
    if (missingLetters > 0) {
      // ignore: avoid_print
      print('Note: $missingLetters letter-game utterances have no clip (TTS fallback).');
    }
    expect(missing, isEmpty, reason: 'Run: dart run tool/gen_voice.dart');
  });
}
```

- [ ] **Step 3:** Commit `content/audio/` + `test/content/voice_coverage_test.dart` — `feat: Leda voice clips and coverage check`.
- [ ] **Step 4:** `pubspec.yaml` `version: 0.2.0+2`; commit `chore: release 0.2.0`.
- [ ] **Step 5:** Push nhánh, mở PR, chờ CI xanh, merge (người dùng đã cho phép quy trình PR → merge → tag ở lần trước; vẫn báo trước khi làm).
- [ ] **Step 6:** Tag `v0.2.0`, chờ workflow Release, kiểm tra asset APK.
- [ ] **Step 7:** Trên điện thoại: mở app → 🔒 có chấm đỏ → khu bố mẹ → Cập nhật → cài; xác nhận phiên bản `0.2.0`, tiến độ ❄️ cũ còn nguyên, giọng Leda phát, trò 🐾 chơi được.
