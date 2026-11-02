# Nhìn hình đoán từ + giọng Vbee — Thiết kế

**Ngày:** 2026-11-02
**Bổ sung cho:** `2026-11-02-xoai-ice-castle-design.md` (giai đoạn 1 đã phát hành v0.1.0)
**Lý do:** Bé chưa chơi được trò 🎈 Tìm chữ cái; giọng máy (Google TTS trên điện thoại) nghe "robot". Bố mẹ muốn trò chính là nhìn hình đoán tên tiếng Anh (con vật, trái cây…) và giọng nữ tự nhiên.

Kết quả: bản **v0.2.0**.

## 1. Phạm vi

**Có:**
- Trò mới 🐾 **Nhìn hình đoán từ** làm trò chính trên màn chính.
- Ẩn trò 🎈 Tìm chữ cái; công tắc trong khu bố mẹ để hiện lại.
- 4 chủ đề, 45 từ, ảnh **Microsoft Fluent Emoji 3D** (MIT) đóng gói trong APK.
- **Giọng Vbee** (tiếng Việt HN – Ngọc Huyền, tiếng Anh Heart) tạo sẵn thành file âm thanh, đóng gói trong APK; giọng máy chỉ còn là dự phòng.
- Lần nâng cấp schema DB đầu tiên (thêm công tắc) kèm `MigrationStrategy`.

**Không có:** gọi Vbee lúc chạy app; chọn chủ đề; thu âm bố mẹ (giai đoạn sau); ảnh AI tự vẽ.

## 2. Trò 🐾 Nhìn hình đoán từ

### 2.1 Luật chơi
- **Một lượt:** 8 câu, từ được trộn từ mọi chủ đề.
- **Chọn câu hỏi:** dùng `QuestionPicker` sẵn có (trọng số `5 − mức thuộc`, không lặp liền nhau) với **tối đa 3 từ mới mỗi lượt** (`maxNew: 3`).
- **Mỗi câu 4 thẻ hình** (lưới 2×2): 1 đáp án + 3 từ khác chọn ngẫu nhiên, không trùng nhau. Thứ tự xáo trộn.
- **Hỏi:** Elsa nói *"Find the lion!"*. Chạm Elsa → nói lại câu hỏi.
- **Đúng:** thẻ phóng to + lấp lánh, Elsa nói *"Lion! Con sư tử!"*; dừng ~0,8 s tối thiểu rồi sang câu sau.
- **Sai lần 1:** thẻ rung + nhóm câu `try_again`.
- **Sai lần 2 trở đi:** thẻ đúng phát sáng + Elsa nói *"Con sư tử ở đây nè! Lion!"*.
- **Kết quả câu** (dùng chung luật giai đoạn 1): `firstTry` (+1 mức, +1 ❄️), `retry` (giữ nguyên), `hinted` (−1 mức).
- **Khóa mức thuộc:** `word:<id>`, ví dụ `word:lion`.
- Xong 8 câu → lưu phiên (`game: 'vocab'`) → `completeRound` → màn thưởng (giống giai đoạn 1: +5 ❄️/lượt, nhiệm vụ ngày 3 lượt).
- 🏠 nói `go_home` rồi quay về; bị bỏ qua trong lúc ăn mừng câu cuối. Lỗi bất ngờ → `error_home` và quay về (như trò chữ cái).

### 2.2 Màn hình
```
┌──────────────────────────────┐
│ 🏠                      3/8    │
│        👸  (Elsa, chạm = nghe lại)│
│  ┌──────────┐  ┌──────────┐  │
│  │   hình   │  │   hình   │  │
│  └──────────┘  └──────────┘  │
│  ┌──────────┐  ┌──────────┐  │
│  │   hình   │  │   hình   │  │
│  └──────────┘  └──────────┘  │
└──────────────────────────────┘
```
- Thẻ vuông, nền trắng bo góc, bóng nhẹ; cạnh thẻ = min((rộng − lề) / 2, (cao còn lại) / 2), tối đa 200 dp (ảnh 256 px vẫn nét trên màn xxhdpi ở cỡ này).
- Không có chữ trên thẻ (bé chưa đọc được).
- Phải vừa màn 360×640 dp không tràn.

### 2.3 Màn chính
- Hàng nút trò chơi: **🐾** (trò mới, đứng đầu) → 🎈 (chỉ hiện khi công tắc bật) → ✏️ → 🗣️ → 🇻🇳.
- Nút 🐶 "Học từ mới" (đang "sắp có") **bị bỏ**, vì trò 🐾 chính là trò đó.
- Tên trò: phrase `game_vocab` đổi thành "Nhìn hình đoán từ".

### 2.4 Khu bố mẹ
- Thêm `SwitchListTile` **"Hiện trò Tìm chữ cái"** (mặc định tắt). Lưu trong bảng `profile`, cột mới `showFindLetter`.

## 3. Nội dung

### 3.1 Gói từ vựng
Mỗi chủ đề một gói trong `content/packs/`, khai báo trong `manifest.json`:

```json
{
  "id": "vocab_animals",
  "version": 1,
  "title_vi": "Con vật",
  "items": [
    { "id": "lion", "word": "lion", "vi": "con sư tử", "image": "images/vocab/lion.png", "emoji": "🦁" }
  ]
}
```
- `id`: duy nhất trên **mọi** gói từ vựng; `word`: tiếng Anh viết thường; `vi`: nghĩa tiếng Việt viết thường; `image`: đường dẫn trong `content/`; `emoji`: dự phòng khi ảnh lỗi.
- Validator kiểm tra: các trường bắt buộc, `id` không trùng giữa các gói, ảnh tồn tại (khi có danh sách asset), tổng số từ ≥ 4.
- Câu nói ghép với từ: `{word}` → "lion", `{Word}` → "Lion", `{vi}` → "con sư tử", `{Vi}` → "Con sư tử".

### 3.2 Danh sách 45 từ (phương ngữ miền Bắc; bố mẹ sửa được trong JSON)

| Chủ đề | id → tiếng Việt |
|---|---|
| Con vật (20) | cat con mèo · dog con chó · lion con sư tử · elephant con voi · tiger con hổ · monkey con khỉ · rabbit con thỏ · bear con gấu · fish con cá · bird con chim · duck con vịt · cow con bò · pig con lợn · horse con ngựa · chicken con gà · frog con ếch · giraffe con hươu cao cổ · zebra con ngựa vằn · panda con gấu trúc · penguin con chim cánh cụt |
| Trái cây (13) | apple quả táo · banana quả chuối · orange quả cam · grapes chùm nho · watermelon quả dưa hấu · strawberry quả dâu tây · mango quả xoài · pineapple quả dứa · pear quả lê · cherry quả anh đào · lemon quả chanh · peach quả đào · coconut quả dừa |
| Rau củ (6) | carrot củ cà rốt · tomato quả cà chua · corn bắp ngô · potato củ khoai tây · broccoli cây súp lơ xanh · cucumber quả dưa chuột |
| Xe cộ (6) | car ô tô · bus xe buýt · train tàu hỏa · airplane máy bay · boat con thuyền · bicycle xe đạp |

### 3.3 Ảnh: Fluent Emoji 3D
- Nguồn: `github.com/microsoft/fluentui-emoji`, nhánh `main` **ghim theo một commit SHA** ghi trong script. Đường dẫn: `assets/<Tên thư mục>/3D/<tên_file>_3d.png`, PNG 256×256, 22–50 KB.
- Dùng bản **khuôn mặt** cho cat, dog, cow, pig, horse, tiger, monkey, rabbit (`Cat face`, `Dog face`…) và `Baby chick` cho chicken; tên khác cho orange → `Tangerine`, apple → `Red apple`, cherry → `Cherries`, corn → `Ear of corn`, car → `Automobile`, boat → `Sailboat`. Còn lại dùng tên trùng từ tiếng Anh.
- `tool/fetch_images.dart` tải ảnh về `content/images/vocab/<id>.png` (bỏ qua file đã có), và tải file LICENSE về `content/images/vocab/LICENSE-fluentui-emoji.txt`. Ảnh được commit vào repo (không tải lúc build).
- `THIRD_PARTY_NOTICES.md` ở gốc repo ghi nguồn + giấy phép MIT của Fluent Emoji.
- `pubspec.yaml` thêm asset `content/images/vocab/`.

## 4. Giọng Vbee

### 4.1 Liệt kê mọi câu app có thể nói
Một hàm Dart duy nhất `enumerateUtterances(ContentBundle, Names)` (trong `lib/core/voice/utterances.dart`) trả về mọi câu nói (đã thay biến) mà app có thể phát:
- mọi phrase cố định (thay `{name_en}`, `{name_vi}`);
- với mỗi từ vựng: `vocab_prompt`, `vocab_correct`, `vocab_hint`;
- với mỗi chữ cái (trò Tìm chữ cái): `find_letter_prompt` (hoa + thường), `find_letter_small_prompt`, `letter_example`.

App và công cụ dùng **cùng hàm này** nên không lệch nhau.

### 4.2 Câu song ngữ
Một **câu nói** (`Utterance`) là danh sách đoạn `(lang, text)`. Phrase có thể có một đoạn (như hiện nay: `lang` + `text`) hoặc nhiều đoạn:
```json
{ "id": "vocab_correct", "group": "vocab",
  "parts": [ { "lang": "en", "text": "{Word}!" }, { "lang": "vi", "text": "{Vi}!" } ] }
{ "id": "vocab_hint", "group": "vocab",
  "parts": [ { "lang": "vi", "text": "{Vi} ở đây nè!" }, { "lang": "en", "text": "{Word}!" } ] }
{ "id": "vocab_prompt", "lang": "en", "text": "Find the {word}!", "group": "vocab" }
```
- Khóa của câu nói: các đoạn nối bằng `" || "`, mỗi đoạn dạng `lang|text`. Ví dụ `en|Lion! || vi|Con sư tử!`.
- Mỗi đoạn được đọc bằng giọng đúng ngôn ngữ của đoạn đó rồi nối thành **một file** cho cả câu song ngữ (cách nhau ~0,25 s).
- Giọng máy dự phòng: đọc từng đoạn bằng đúng ngôn ngữ của đoạn đó.

### 4.3 Tạo file giọng — `tool/gen_voice.dart`
- Đọc khóa từ `~/.config/xoai/vbee.env` (`VBEE_APP_ID=…`, `VBEE_TOKEN=…`, hoặc biến môi trường cùng tên); **không bao giờ** ghi khóa ra file trong repo, in ra log hay đặt trên dòng lệnh.
- Giọng theo ngôn ngữ của từng đoạn: `vi` → **HN – Ngọc Huyền** (`hn_female_ngochuyen_full_48k-fhg`), `en` → **Heart** (`af_heart`); tốc độ 0.9.
- Gói của tài khoản không có chế độ đồng bộ nên dùng **async**: `POST https://api.vbee.vn/v1/tts` (header `Authorization: Bearer …`, `App-Id: …`; body `text`, `voiceCode`, `mode: "async"`, `outputFormat: "mp3"`, `bitrate: 128`, `speed: 0.9`, `webhookUrl` trỏ tới tên miền `.invalid` vì API bắt buộc có webhook nhưng không được gọi tới server thật), rồi hỏi `GET /v1/tts/requests/<requestId>` mỗi ~2 s (tối đa ~120 s) đến khi `COMPLETED` → tải `audioLink` (URL ký sẵn, hết hạn sau 3 phút, chuyển hướng sang S3).
- Mỗi **đoạn** được tạo riêng và lưu đệm ở `build/voice-parts/<sha1(lang|text|voice|speed)>.mp3` (đoạn dùng chung giữa nhiều câu chỉ tạo một lần). Câu nhiều đoạn: `ffmpeg` nối các đoạn, giữa các đoạn chèn ~0,25 s im lặng → **Opus trong OGG**, mono, 32 kbps → `content/audio/<sha1(key)[:16]>.ogg`.
- Ghi `content/audio/index.json` sau mỗi clip (ghi nguyên tử bằng `*.tmp` + đổi tên):
  ```json
  { "provider": "vbee",
    "voices": { "vi": "hn_female_ngochuyen_full_48k-fhg", "en": "af_heart" },
    "speed": 0.9,
    "clips": { "vi|Chào Xoài! Hôm nay mình chơi gì nào?": "3f2a9c….ogg" } }
  ```
  Nếu nhà cung cấp/giọng/tốc độ trong index khác cấu hình hiện tại thì mọi clip cũ bị coi là hết hạn (tạo lại; file cũ thành mồ côi, `--prune` xóa).
- Bỏ qua câu đã có trong index và file tồn tại. Tối đa 3 câu chạy song song. HTTP 429 (`TTS_CCR_MAX_LIMIT_REACHED`, quá số yêu cầu đồng thời) → chờ rồi thử lại. `BAD_REQUEST` nhắc tới credit/gói → dừng (mã thoát 2), in số câu còn thiếu; nạp thêm rồi chạy lại sẽ tiếp tục. Lỗi khác → câu đó thất bại, các câu khác vẫn chạy (mã thoát 1).
- Chi phí: Vbee tính credit theo số ký tự; `--dry-run` in số ký tự cần đọc.
- Thứ tự tạo: phrase cố định → từ vựng → chữ cái.
- Tùy chọn: `--limit N`, `--only TEXT`, `--prune` (xóa file không còn câu nào dùng), `--dry-run`.
- Dùng `dart:io` `HttpClient`.

### 4.4 Phát trong app
- `VoiceService` nhận thêm một `ClipLibrary` (đọc `content/audio/index.json` khi khởi động) và một `ClipPlayer` (dựa trên `just_audio`, phát asset `content/audio/<file>`).
- `say` / `sayGroup` / `sayParts`: dựng `Utterance` → có clip → phát clip; không có → giọng máy đọc từng đoạn. Lỗi khi phát clip → dự phòng giọng máy cho câu đó.
- `stop()` dừng cả clip và giọng máy. Giữ ngữ nghĩa hiện tại: một câu mới luôn dừng câu đang nói; future của `say` hoàn thành khi phát xong hoặc bị dừng; có timeout an toàn 15 s.
- `ClipPlayer` dùng `AudioSession` loại speech để không bị nhạc khác lấn.

### 4.5 Kiểm tra đủ giọng
- Test `test/content/voice_coverage_test.dart`: với nội dung thật trong `content/`, mọi câu từ `enumerateUtterances` thuộc **phrase cố định + từ vựng** phải có trong `index.json` và file tồn tại. Câu của trò Tìm chữ cái chỉ cảnh báo (in số câu thiếu), không làm fail, vì trò đang ẩn.
- `tool/validate_content.dart` kiểm tra thêm: mọi file trong `index.json` tồn tại, không có file `.ogg` mồ côi.

## 5. Dữ liệu
- `schemaVersion` 1 → 2: thêm cột `profile.showFindLetter` (bool, mặc định false).
- `MigrationStrategy`: `onCreate` tạo toàn bộ bảng; `onUpgrade` từ 1 lên 2 thêm cột. Test migration bằng DB v1 dựng tay (tạo bảng theo schema v1, chèn dữ liệu, mở bằng `AppDatabase` mới, kiểm tra dữ liệu còn nguyên và cột mới = false).
- `ProfileStore` thêm `Future<bool> showFindLetter()` và `Future<void> setShowFindLetter(bool)`; provider `showFindLetterProvider` (AsyncNotifier) để màn chính và khu bố mẹ cùng cập nhật.

## 6. Xử lý lỗi
| Tình huống | Xử lý |
|---|---|
| Thiếu `index.json` / không đọc được | Thư viện clip rỗng → toàn bộ dùng giọng máy |
| Clip lỗi khi phát | Dự phòng giọng máy cho câu đó, ghi log |
| Ảnh thiếu/lỗi | Hiện emoji của từ (đã có `errorBuilder`) |
| Hết credit Vbee khi tạo giọng | Script dừng, in số câu thiếu; test coverage chặn phát hành bản thiếu giọng |

## 7. Kiểm thử
- Unit: render biến `{Word}/{Vi}`, `Utterance` + khóa, `enumerateUtterances` (đủ và không trùng), `ClipLibrary` tra cứu, `VoiceService` chọn clip trước rồi mới giọng máy, dự phòng khi clip lỗi, `stop` dừng clip; dựng lượt trò từ vựng (4 lựa chọn khác nhau, có đáp án, maxNew 3); session (dùng lại luật kết quả); validator gói từ vựng; migration DB.
- Widget: một lượt đầy đủ trò từ vựng (đúng hết → màn thưởng +13 ❄️), sai 2 lần → thẻ đúng phát sáng + câu gợi ý, 🏠 nói `go_home`; màn chính hiện 🐾 và ẩn 🎈 khi tắt công tắc, hiện 🎈 khi bật; công tắc trong khu bố mẹ; vừa màn 360×640.
- Coverage giọng (4.5) chạy trong CI.
- Thử thật: cài v0.2.0 qua **chức năng tự cập nhật** trên điện thoại (lần đầu kiểm tra luồng này).

## 8. Thứ tự làm
1. Gói từ vựng + validator + tải ảnh Fluent + giấy phép.
2. `Utterance`, phrase nhiều đoạn, `enumerateUtterances`.
3. `ClipLibrary` + `ClipPlayer` + nối vào `VoiceService`.
4. `tool/gen_voice.dart` + test coverage; chạy tạo giọng (cần key, mất ~1–2 giờ do giới hạn 3 lượt/phút).
5. Migration DB + công tắc khu bố mẹ.
6. Logic + màn chơi trò 🐾, cập nhật màn chính.
7. Phát hành v0.2.0, cập nhật qua app trên điện thoại.
