# Lâu đài băng của Xoài — Thiết kế

**Ngày:** 2026-11-02
**Người dùng:** Hoài An (Xoài), gần 5 tuổi — đang học bảng chữ cái tiếng Anh, tiếng Việt và câu giao tiếp tiếng Anh cơ bản ở lớp.
**Mục tiêu:** Game học-mà-chơi dành riêng cho bé, khiến bé *muốn* mở ra mỗi ngày (bé đang lười học ở nhà).

## 1. Tổng quan

- **Nền tảng:** App Android (APK cài ngoài, không lên Play Store), viết bằng **Flutter**.
- **Chủ đề:** Băng giá / Elsa. Elsa là nhân vật dẫn dắt; phần thưởng là xây một lâu đài băng lớn dần.
- **Đối tượng không biết đọc:** mọi hướng dẫn bằng giọng nói, mọi nút là hình lớn.
- **Bản quyền:** Elsa/Olaf/Anna thuộc Disney. App chỉ dùng trong gia đình, **không phát hành công khai**. Nhân vật được khai báo qua file cấu hình + ảnh để thay thế dễ dàng (app chỉ đóng gói hình tạm tự vẽ; ảnh Elsa thật do bố mẹ tự thêm vào).

### Phạm vi

**Có:** 5 trò chơi (Đập bong bóng chữ cái EN, Tô chữ, Nói chuyện với Elsa, Chữ cái tiếng Việt, Từ vựng), hệ thống phần thưởng (bông tuyết, lâu đài, sticker, chuỗi ngày), khu bố mẹ (tiến độ, thu âm, cập nhật, cài đặt, sao lưu), cập nhật nội dung qua JSON từ GitHub, cập nhật APK qua GitHub Releases.

**Không có:** iOS, nhiều hồ sơ trẻ, đồng bộ cloud, tài khoản đăng nhập, analytics, Play Store.

## 2. Nguyên tắc trải nghiệm

1. **Không cần đọc chữ.** Chạm vào bất kỳ nút điều hướng nào → Elsa đọc tên nó.
2. **Màn hình dọc**, khóa xoay.
3. **Tối đa 5–6 vùng chạm** mỗi màn hình; vùng chạm tối thiểu 64dp.
4. **Không có "thua".** Sai lần 1 → động viên; sai lần 2 → đáp án đúng phát sáng để bé chạm theo. Mọi lượt đều kết thúc bằng lời khen.
5. **Lượt ngắn:** 2–3 phút mỗi lượt.
6. **Giới hạn thời gian/ngày** (mặc định 20 phút, bố mẹ chỉnh được). Hết giờ giữa lượt → cho chơi nốt lượt đó, sau đó Elsa chào tạm biệt và khóa tới 00:00 hôm sau.

## 3. Màn hình và điều hướng

```
Màn chính (Lâu đài băng)
 ├─ 🎈 Đập bong bóng (chữ cái EN; từ v0.4.0, thay trò Tìm chữ cái cũ)
 ├─ ✏️ Tô chữ (EN)
 ├─ 🗣️ Nói chuyện với Elsa
 ├─ 🇻🇳 Chữ cái tiếng Việt → chọn [Tìm chữ] / [Tô chữ]
 ├─ 🐶 Từ vựng → chọn chủ đề (Con vật / Màu sắc / Số đếm / Trái cây / …)
 ├─ 🏰 Xem lâu đài + bộ sưu tập sticker + các bạn đã mở khóa
 └─ 🔒 Khu bố mẹ (góc dưới, nhỏ)
Sau mỗi lượt → Màn thưởng (bông tuyết bay vào lâu đài; mở quà nếu xong nhiệm vụ ngày)
```

**Màn chính** hiển thị: lâu đài ở mốc hiện tại, Elsa chào ("Hi An!" / "Chào Xoài!"), tổng ❄️, nhiệm vụ hôm nay (3 chấm), 5 nút trò chơi, ổ khóa khu bố mẹ (có chấm đỏ nếu có bản APK mới).

## 4. Luật chung của trò chơi

### 4.1 Mức thuộc và chọn câu hỏi

Mỗi mục học có một **khóa** duy nhất, ví dụ `letter_en_upper:B`, `letter_en_lower:b`, `letter_vi:đ`, `word:cat`, `color:red`, `number:3`, `conv:name`, `trace_en:B`.

Mỗi khóa có **mức thuộc 0–4**:
Mỗi câu kết thúc với một trong ba kết quả:
- **Đúng ngay lần đầu** (`firstTry`) → +1 (tối đa 4).
- **Đúng ở lần thử thứ hai** (`retry`, sai 1 lần) → giữ nguyên.
- **Cần gợi ý** (`hinted`, sai ≥ 2 lần, đáp án đã phát sáng / Elsa đã làm mẫu) → −1 (tối thiểu 0).

**Chọn câu hỏi cho một lượt:**
- Trọng số mỗi mục = `5 − mức thuộc` (mục chưa gặp coi như mức 0).
- Tối đa **2 mục mới** (chưa gặp bao giờ) mỗi lượt.
- Không hỏi cùng một mục hai câu liên tiếp.
- Phương án nhiễu (đáp án sai) lấy ngẫu nhiên từ cùng nhóm, không trùng đáp án đúng.
- Hàm chọn nhận vào nguồn ngẫu nhiên có seed để test được.

### 4.2 Phần thưởng

| Sự kiện | Thưởng |
|---|---|
| Đúng ngay lần đầu | +1 ❄️ |
| Đúng ở lần 2 / cần gợi ý | +0 ❄️ (vẫn khen) |
| Hoàn thành một lượt | +5 ❄️ |
| Hoàn thành nhiệm vụ ngày (3 lượt bất kỳ trong ngày) | 🎁 1 sticker ngẫu nhiên chưa có (hết sticker mới → +20 ❄️) |
| Chuỗi 3 ngày liên tiếp có chơi | 🎁 quà lớn: +30 ❄️ + 1 sticker |
| Chuỗi 7 ngày | 🎁 quà rất lớn: +80 ❄️ + 2 sticker |

Một "ngày có chơi" = hoàn thành ≥ 1 lượt. Lỡ một ngày → chuỗi về 0 (Olaf nói "Mình bắt đầu lại nha!", không trách).

**Mốc lâu đài** (tổng ❄️ tích lũy, không bao giờ giảm):

| Mốc | ❄️ cần | Lâu đài | Mở khóa bạn |
|---|---|---|---|
| 1 | 0 | Nền băng | — |
| 2 | 20 | Tường băng | Olaf |
| 3 | 50 | Cửa lớn | — |
| 4 | 100 | Tháp thứ nhất | Anna |
| 5 | 170 | Cầu thang băng | — |
| 6 | 260 | Đèn chùm | Sven |
| 7 | 380 | Tháp thứ hai | — |
| 8 | 530 | Pháo hoa băng | Kristoff |

Bạn đã mở khóa xuất hiện ở lâu đài và được chọn ngẫu nhiên (≈30%) để thay Elsa đọc câu khen.

**Sticker:** bộ 30 sticker chủ đề băng tuyết/nhân vật, khai báo trong `content/stickers.json`.

## 5. Các trò chơi

### 5.1 🎈 Đập bong bóng (chữ cái tiếng Anh)

Từ v0.4.0 trò này thay trò "Tìm chữ cái" cũ (bông tuyết mang chữ rơi từ trên xuống; trò cũ và công tắc ẩn/hiện của nó đã bỏ).

- **Một lượt:** 5 chữ HOA A–Z (chọn bằng `QuestionPicker`, tối đa 3 chữ chưa gặp). Khóa `balloon_en_upper:X`.
- **Sân chơi:** 5–6 bóng nhiều màu (6 nếu màn rộng ≥ 360 dp) bay từ dưới lên trong 7–9 giây, lắc ngang nhẹ, mỗi bóng một chữ, không bao giờ hai bóng cùng chữ; chữ cần tìm luôn có bóng trên sân.
- **Câu hỏi:** Elsa nói "Xoài tìm chữ B nào!" (chạm vào Elsa để nghe lại).
- **Chạm:** vùng chạm là thân bóng cộng 12 dp; nếu nhiều bóng chồng nhau thì quả có tâm gần ngón tay nhất nổ. Trong lúc Elsa đang nói, chạm vào bóng chỉ làm bóng lắc, chưa nổ.
- **Đúng:** bóng nổ kèm pháo giấy, Elsa nói "Đúng rồi! B!", sang chữ sau (các bóng khác vẫn bay).
- **Sai:** bóng bị chạm nổ, Elsa nói "Chưa đúng rồi, đây là chữ C" (khóa chạm đến hết đoạn này), rồi "Tìm chữ B nha!" (bé chạm tiếp được ngay). Sai lần 2 → bóng đúng phát sáng.
- **Kết quả:** `firstTry` / `retry` / `hinted` như các trò chọn khác; +1 ❄️ cho mỗi chữ đúng ngay lần đầu, +5 ❄️ mỗi lượt, tính vào nhiệm vụ ngày.

### 5.2 ✏️ Tô chữ (tiếng Anh)

- **Một lượt:** 3 chữ.
- Chữ hiển thị lớn với nét đứt; chấm xanh đánh số tại điểm bắt đầu mỗi nét và mũi tên chỉ hướng. Nét đang cần tô nhấp nháy nhẹ.
- Bé tô bằng ngón tay; vệt tô hiệu ứng băng lấp lánh.
- **Chấm nét:** lấy mẫu đều các điểm trên nét đích; một điểm được "phủ" nếu cách vệt tô của bé ≤ **12% cạnh khung chữ**. Nét đạt khi ≥ **80%** điểm được phủ. Không bắt buộc thứ tự nét hay chiều tô (bé 5 tuổi), chỉ hướng dẫn.
- Thả tay mà nét chưa đạt → vệt mờ đi, nét đó cho tô lại (không tính sai).
- Đủ các nét → chữ biến thành hình ví dụ (A → 🍎), Elsa đọc "A is for Apple!".
- Chữ hoa trước; chữ thường mở theo cùng quy tắc như 5.1. Khóa `trace_en_upper:X` / `trace_en_lower:x`. Tô xong không phải tô lại nét nào ≥ 3 lần = `firstTry`; ngược lại = `retry`.

### 5.3 🗣️ Nói chuyện với Elsa

- **Một lượt:** 5 câu hỏi.
- Elsa hỏi (ví dụ "What's your name?"). Bé **giữ nút micro lớn** để nói, thả ra để kết thúc (tối đa 8 giây). Trong khi Elsa đang nói, nút micro bị khóa (mờ đi).
- **Chấm:** chuẩn hóa văn bản nhận được (chữ thường, bỏ dấu câu, tách từ). Câu trả lời đúng nếu có **ít nhất một nhóm** trong `accept` mà mọi từ khóa của nhóm đều xuất hiện. Mỗi từ khóa được so khớp với danh sách **bí danh** (`aliases`) — ví dụ `an` ↔ `ann`, `anne`, `and`, `en`.
- **Sai lần 1:** "Hmm, can you say it again?"
- **Sai lần 2:** Elsa làm mẫu "Say: My name is An", bé nói theo.
- **Lần 3:** luôn tính đạt và khen (kết quả `hinted`). Nhận giọng trẻ em không đủ chính xác để phạt bé.
- **Bộ câu ban đầu:** What's your name? / How old are you? / How are you? / Hello! / Goodbye! / What color do you like? / Do you like apples? / Thank you!
- Câu hỏi có thể dùng `{name_en}` để chèn tên.

### 5.4 🇻🇳 Chữ cái tiếng Việt

- Vào trò → chọn **[Tìm chữ]** hoặc **[Tô chữ]**.
- Dùng lại cơ chế chọn chữ (bản đầu: Tìm chữ cái; từ v0.4.0 trò Tìm chữ không còn) và 5.2, với 29 chữ: a ă â b c d đ e ê g h i k l m n o ô ơ p q r s t u ư v x y.
- **Chữ thường trước** (trường ở VN dạy chữ thường trước). Chữ hoa mở khi ≥ 20/29 chữ thường đạt mức ≥ 2. Không có chế độ ghép hoa–thường.
- Câu nhắc tiếng Việt: "Xoài tìm chữ bờ nào!" — cách đọc mỗi chữ lấy từ trường `spoken` trong `letters_vi.json` (ví dụ `b` → "bờ") vì TTS đọc chữ đơn lẻ tiếng Việt không đúng cách đọc ở trường.
- Nét tô chữ có dấu (ă â đ ê ô ơ ư) = nét của chữ gốc + nét dấu.
- Khóa `letter_vi_lower:x`, `letter_vi_upper:X`, `trace_vi_lower:x`, `trace_vi_upper:X`.

### 5.5 🐶 Từ vựng

- Vào trò → chọn chủ đề (mỗi chủ đề là một gói nội dung `vocab_*`).
- **Một lượt:** 6 câu. Ba dạng câu hỏi, theo trường `type` của gói:
  - `pick_image`: "Where is the cat?" → chọn 1 trong 3 hình.
  - `pick_color`: "Touch the red one!" → chọn 1 trong 3 quả bóng màu.
  - `count`: "How many apples?" → hiện 1–10 hình, chọn 1 trong 3 số.
- Đúng → Elsa đọc lại từ ("Cat! Meow!" nếu có trường `fun`).
- **Chủ đề ban đầu:** con vật (12 từ), màu sắc (8), số đếm (1–10), trái cây (10).

## 6. Nội dung

### 6.1 Cấu trúc

```
content/
├── manifest.json
├── profile_defaults.json      ← tên mặc định, giới hạn giờ mặc định
├── characters.json            ← nhân vật → đường dẫn ảnh
├── stickers.json
├── castle.json                ← mốc lâu đài (bảng ở mục 4.2)
├── phrases.json               ← câu cố định: khen, động viên, hướng dẫn (EN + VI)
├── packs/
│   ├── letters_en.json        ← chữ, từ ví dụ, ảnh ví dụ, nét tô
│   ├── letters_vi.json        ← chữ, spoken, nét tô
│   ├── conversation.json
│   ├── vocab_animals.json
│   ├── vocab_colors.json
│   ├── vocab_numbers.json
│   └── vocab_fruits.json
├── images/                    ← OpenMoji PNG (CC BY-SA 4.0)
├── characters/                ← hình tạm; bố mẹ thay bằng ảnh thật
├── castle/                    ← castle_1.png … castle_8.png
└── stickers/
```

**Hình minh họa** của mỗi mục khai báo bằng `emoji` (Android vẽ sẵn, không cần file) hoặc `image` (file PNG trong `content/images/`, ví dụ OpenMoji); có `image` thì ưu tiên `image`. Giai đoạn 1 dùng `emoji`.

`content/` nằm trong repo và **được đóng gói vào APK** làm bản nội dung gốc (app chạy offline ngay lần đầu).

### 6.2 Định dạng chính

`manifest.json`:
```json
{
  "schema": 1,
  "packs": { "letters_en": 1, "letters_vi": 1, "conversation": 2, "vocab_animals": 3 },
  "files": { "phrases": 1, "stickers": 1, "castle": 1, "characters": 1 }
}
```

Mục từ vựng:
```json
{ "id": "vocab_animals", "version": 3, "type": "pick_image",
  "title_vi": "Con vật", "icon": "images/dog.png",
  "items": [
    { "id": "cat", "word": "cat", "image": "images/cat.png",
      "prompt": "Where is the cat?", "fun": "Meow!" }
  ] }
```

Câu giao tiếp:
```json
{ "id": "name", "question": "What's your name?",
  "accept": [["name", "an"], ["name", "xoai"], ["im", "an"], ["an"]],
  "aliases": { "an": ["ann", "anne", "and", "en"], "xoai": ["swine", "soy", "xoài"] },
  "model_answer": "My name is {name_en}." }
```

Nét tô (tọa độ chuẩn hóa 0–1 trong khung chữ, mỗi nét là một polyline):
```json
{ "char": "A", "strokes": [
    [[0.5, 0.05], [0.1, 0.95]],
    [[0.5, 0.05], [0.9, 0.95]],
    [[0.25, 0.6], [0.75, 0.6]] ],
  "example": { "word": "Apple", "emoji": "🍎" } }
```

Câu cố định (`phrases.json`) có mã, ngôn ngữ và nhóm, ví dụ:
```json
{ "id": "praise_vi_1", "lang": "vi", "text": "Giỏi quá {name_vi} ơi!", "group": "praise", "priority": true }
```

### 6.3 Kiểm tra hợp lệ

Một trình kiểm tra nội dung (Dart, dùng chung cho app và CLI) xác nhận: JSON đúng cấu trúc; mọi `id` trong một gói là duy nhất; mọi đường dẫn ảnh tồn tại; tọa độ nét trong [0, 1]; mỗi câu hỏi `pick_*`/`count` có đủ ≥ 3 mục để tạo phương án nhiễu; `version` là số nguyên dương.

### 6.4 Cập nhật nội dung qua mạng

1. Khi mở app (tối đa 1 lần/giờ) và có mạng: gọi `https://api.github.com/repos/nguyentienloc/mango-game/commits/main` để lấy `sha` mới nhất (repo cấu hình trong một hằng số). Trùng `sha` lần kiểm tra trước → dừng.
2. Tải `https://cdn.jsdelivr.net/gh/nguyentienloc/mango-game@<sha>/content/manifest.json` (ghim theo commit nên không bị cache cũ). So `version` từng gói/file với bản đang dùng; gói nào mới hơn → tải từ cùng đường dẫn `@<sha>/content/...`, kèm các ảnh mới mà gói tham chiếu.
3. Tải vào thư mục tạm → chạy trình kiểm tra → hợp lệ thì chuyển nguyên khối sang thư mục nội dung đang dùng; lỗi thì bỏ, giữ bản cũ.
4. Nội dung mới có hiệu lực từ **lần mở app sau**.
5. Thứ tự ưu tiên khi đọc: nội dung đã tải (nếu mới hơn) → nội dung đóng gói trong APK.

**CI nội dung:** GitHub Actions chạy trình kiểm tra trên mỗi push có thay đổi `content/`.

**Repo phải public** (jsDelivr và raw không đọc được repo private; không nhúng token vào APK).

## 7. Âm thanh

### 7.1 VoiceService

Một điểm duy nhất để phát giọng: `speak(key, {vars})`.
- `key` là mã câu cố định (`praise_vi_1`) hoặc mã nội dung (`letter_vi:b`, `word:cat`, `conv:name`).
- **Thứ tự:** có bản thu của bố mẹ cho `key` → phát file; không có → TTS với văn bản và ngôn ngữ tương ứng (sau khi thay `{name_en}`, `{name_vi}`).
- **Chọn câu khen/động viên:** chọn ngẫu nhiên trong nhóm; câu đã có bản thu có trọng số ×3.
- Nói câu mới thì dừng câu đang nói. Có callback khi nói xong (để mở khóa micro).

### 7.2 TTS

- `flutter_tts` với engine Google TTS của Android. `en-US` cho câu tiếng Anh, `vi-VN` cho câu tiếng Việt.
- Tốc độ 0.42, cao độ 1.15.
- Tên: câu EN dùng `name_en` ("An"), câu VI dùng `name_vi` ("Xoài").
- Lần đầu chạy, kiểm tra có giọng `vi-VN` và `en-US`; thiếu → khu bố mẹ hiện cảnh báo + nút mở cài đặt TTS của Android.

### 7.3 Nhận giọng nói

- `speech_to_text`, locale `en-US`, ưu tiên nhận dạng trên thiết bị (`onDevice`) nếu có; không có thì online.
- Giữ để nói, thả để dừng; tối đa 8 giây.
- Không khả dụng (không có engine/mạng/quyền) → trò 5.3 chuyển sang **chế độ nói theo**: Elsa hỏi, rồi làm mẫu câu trả lời, bé nói theo, sau đó bấm ✅ to để sang câu sau (không chấm, không cộng/trừ mức thuộc, vẫn +1 ❄️).

### 7.4 Thu âm của bố mẹ

- Màn hình trong khu bố mẹ liệt kê mọi `key` có thể thu, theo nhóm: **Nên thu trước** (phrases có `priority: true` + chữ cái tiếng Việt), Hướng dẫn trò chơi, Chữ cái tiếng Anh, Từ vựng, Giao tiếp. Bộ đếm "Đã thu: x/y".
- Mỗi dòng: văn bản, trạng thái, [▶ nghe], [🎙 giữ để thu], [🗑 xóa]. Thu tối đa 10 giây.
- `record` → AAC `.m4a`, lưu tại `<app documents>/recordings/<key đã mã hóa an toàn cho tên file>.m4a`. Phát bằng `just_audio`.
- Câu có biến `{name_*}` thì thu nguyên câu đã thay tên.

### 7.5 Nhạc và hiệu ứng

- Nhạc nền lặp, âm lượng thấp; tự giảm (ducking) khi đang nói; công tắc tắt trong cài đặt.
- Hiệu ứng: bông tuyết vỡ, lấp lánh, mở quà, lên mốc lâu đài. Nguồn CC0.

## 8. Dữ liệu cục bộ

SQLite qua **drift**:

| Bảng | Cột chính |
|---|---|
| `profile` (1 dòng) | name_en, name_vi, daily_limit_min, music_on, test_mode |
| `item_stats` | key (PK), mastery 0–4, correct, wrong, last_seen |
| `sessions` | id, date, game, started_at, duration_sec, correct, total |
| `rewards` (1 dòng) | snowflakes_total, castle_level, streak_days, last_play_date, daily_quest_date, daily_rounds_done |
| `stickers_owned` | sticker_id, obtained_at |
| `content_versions` | name, version, source (bundled/downloaded) |

Thời gian chơi trong ngày = tổng `duration_sec` của các phiên có `date` = hôm nay + phiên đang chạy.

**Sao lưu:** khu bố mẹ có **Xuất** (zip gồm file DB + thư mục recordings, chia sẻ qua intent của Android) và **Nhập** (chọn file zip → thay thế dữ liệu hiện tại sau khi xác nhận).

## 9. Khu bố mẹ

- **Cửa vào:** giữ ổ khóa 3 giây là vào, không còn câu đố (bản đầu: giữ 2 giây rồi giải phép cộng hai số có hai chữ số; bỏ từ v0.3.2). Nhấc tay hoặc trượt ngón ra khỏi ổ khóa thì hủy.
- **Tiến độ:** biểu đồ phút chơi 7 ngày; danh sách "Đã thuộc" (mức ≥ 3) và "Cần ôn" (mức ≤ 1 và đã gặp ≥ 3 lần) theo từng trò.
- **Thu âm:** mục 7.4.
- **Cập nhật:** trạng thái nội dung (phiên bản từng gói, nút "Kiểm tra ngay"); cập nhật app (mục 10).
- **Cài đặt:** tên EN/VI, giới hạn phút/ngày (10–60, hoặc tắt), nhạc nền bật/tắt, chế độ thử (bỏ giới hạn giờ, chọn được mọi chế độ khó), kiểm tra giọng TTS, quyền micro.
- **Sao lưu:** mục 8.

## 10. Cập nhật APK

**Phía build (GitHub Actions, khi push tag `v*`):**
1. `flutter test`.
2. `flutter build apk --release` với `versionName` = tag, `versionCode` = số lần chạy CI; ký bằng keystore lấy từ GitHub Secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`).
3. Tạo GitHub Release đính kèm `xoai-<tag>.apk`.

**Phía app:**
1. Mỗi lần mở app và khi bấm "Kiểm tra lại" trong khu bố mẹ: gọi `https://api.github.com/repos/nguyentienloc/mango-game/releases/latest`.
2. So `tag_name` (semver) với `versionName` hiện tại (`package_info_plus`). Mới hơn → chấm đỏ trên ổ khóa.
3. Bố mẹ bấm "Cập nhật" → tải asset `.apk` (thanh tiến trình, hủy được) vào bộ nhớ cache → mở trình cài đặt Android qua FileProvider.
4. Cần quyền `REQUEST_INSTALL_PACKAGES`; lần đầu Android yêu cầu bật "Cài ứng dụng không rõ nguồn gốc" — app hướng dẫn và mở đúng màn cài đặt đó.

**Bắt buộc:** mọi bản APK ký cùng một keystore. Keystore được tạo một lần và lưu dự phòng ngoài repo.

## 11. Kiến trúc code

```
lib/
├── main.dart, app.dart
├── core/
│   ├── content/    ContentRepository, ContentValidator, ContentUpdater, models
│   ├── voice/      VoiceService, TtsEngine, SpeechRecognizer, Recorder, AnswerMatcher
│   ├── progress/   ItemStatsRepository, QuestionPicker, MasteryRules
│   ├── rewards/    RewardService, CastleLevels, StreakRules
│   ├── tracing/    TraceScorer (thuần logic, không UI)
│   ├── session/    PlayTimeGuard (giới hạn thời gian)
│   ├── updater/    AppUpdater, VersionCompare
│   └── db/         drift database
├── features/
│   ├── home/  castle/  reward/
│   ├── games/  balloon/  trace_letter/  talk/  vocab/  vi_letters/
│   └── parent/  gate/  progress/  recordings/  update/  settings/  backup/
└── shared/  BigButton, CharacterView, SnowflakeView, theme
tool/
└── validate_content.dart   ← CLI dùng ContentValidator, chạy trong CI
```

- **State:** Riverpod. Các service trong `core/` là lớp Dart thuần, nhận dependency qua constructor (TTS/STT/recorder/HTTP/clock/random đều bọc sau interface) để test không cần thiết bị.
- **Android:** `minSdk 24`, khóa dọc, quyền `RECORD_AUDIO`, `INTERNET`, `REQUEST_INSTALL_PACKAGES`.
- **Gói chính:** flutter_riverpod, drift, sqlite3_flutter_libs, flutter_tts, speech_to_text, record, just_audio, audio_session, dio, path_provider, package_info_plus, permission_handler, open_filex, archive, share_plus, file_picker.

## 12. Xử lý lỗi

| Tình huống | Xử lý |
|---|---|
| Thiếu giọng TTS | Vẫn chơi; chữ hiển thị to hơn; khu bố mẹ cảnh báo + hướng dẫn cài |
| STT không khả dụng | Trò 5.3 chuyển sang chế độ nói theo (7.3) |
| Không có quyền micro | Như trên; khu bố mẹ có nút cấp lại quyền |
| Tải nội dung lỗi / JSON sai | Giữ bản cũ, ghi lỗi vào màn Cập nhật của khu bố mẹ |
| Ảnh trong gói bị thiếu | Validator chặn; nếu vẫn lọt → hiện ô trống có chữ, không crash |
| Tải APK lỗi / mất mạng | Thông báo + nút thử lại; không ảnh hưởng bản đang chạy |
| Không có mạng | Mọi thứ chạy offline trừ cập nhật và STT online |
| Lỗi không lường trước trong một trò | Bắt ở cấp màn hình → Elsa nói "Mình về lâu đài nha!" → quay về màn chính; ghi log cục bộ |

## 13. Kiểm thử

- **Unit test (viết theo TDD)** cho: `AnswerMatcher`, `TraceScorer`, `QuestionPicker`, `MasteryRules`, `RewardService` + `CastleLevels` + `StreakRules`, `PlayTimeGuard`, `VersionCompare`, `ContentValidator`, `ContentUpdater` (HTTP giả), thứ tự chọn nguồn trong `VoiceService` (bản thu vs TTS).
- **Widget test** cho: màn chính, một vòng đầy đủ của mỗi trò (với voice/random giả), cửa vào khu bố mẹ.
- **CI:** `flutter analyze` + `flutter test` trên mỗi push; validator nội dung khi `content/` thay đổi.
- **Thử thật:** sau mỗi giai đoạn, cài APK lên điện thoại Android của gia đình và chơi thử bằng chế độ thử.

## 14. Giai đoạn triển khai

Mỗi giai đoạn kết thúc bằng một bản APK bé chơi được.

| # | Nội dung |
|---|---|
| 1 | Khung dự án, DB, ContentRepository (chỉ nội dung đóng gói), VoiceService (TTS), màn chính, trò Tìm chữ cái EN (từ v0.4.0 là 🎈 Đập bong bóng), bông tuyết + lâu đài + nhiệm vụ ngày + màn thưởng (chưa có sticker nên quà nhiệm vụ = +20 ❄️ theo luật mục 4.2), cửa khu bố mẹ + màn cập nhật APK, CI build/ký/release. Từ đây các bản sau cài qua tự cập nhật. |
| 2 | TraceScorer + ✏️ Tô chữ EN, 🇻🇳 Chữ cái tiếng Việt (tìm + tô), nét tô cho toàn bộ chữ cái. |
| 3 | 🐶 Từ vựng: 3 dạng câu hỏi, 4 chủ đề ban đầu, ảnh OpenMoji. |
| 4 | 🗣️ Nói chuyện với Elsa: STT, AnswerMatcher, chế độ nói theo. |
| 5 | Khu bố mẹ đầy đủ: thu âm, tiến độ, giới hạn thời gian, cài đặt, sao lưu; cập nhật nội dung qua mạng + CI nội dung; sticker, chuỗi ngày, nhạc nền. |
