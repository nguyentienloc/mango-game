# 🇻🇳 Chữ cái tiếng Việt (IN HOA) — Design + Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** v0.5.0 — nút 🇻🇳 mở màn chọn 🎈 Đập bong bóng / ✏️ Tô chữ với 29 chữ IN HOA tiếng Việt, câu nói tiếng Việt (giọng Ngọc Huyền). Kèm thay đổi đã có trên nhánh: bóng bay 11–14 s.

**Architecture:** Gói nội dung mới `letters_vi.json` (chữ, tên đọc `spoken`, nét). `BalloonScreen` và `TraceScreen` nhận một cấu hình `LetterGameSpec` (bộ chữ, tiền tố khóa mức thuộc, mã câu nói, cách dựng biến) — bản tiếng Anh giữ nguyên hành vi hiện tại. Màn chọn `VietnameseLettersScreen` mở hai trò với spec tiếng Việt.

## Global Constraints
- Nhánh `feat/next-game`. Phát hành `0.5.0+6`, tag `v0.5.0`.
- 29 chữ theo thứ tự: A Ă Â B C D Đ E Ê G H I K L M N O Ô Ơ P Q R S T U Ư V X Y.
- Tên đọc (`spoken`): A "a", Ă "á", Â "ớ", B "bờ", C "cờ", D "dờ", Đ "đờ", E "e", Ê "ê", G "gờ", H "hờ", I "i", K "ca", L "lờ", M "mờ", N "nờ", O "o", Ô "ô", Ơ "ơ", P "pờ", Q "quờ", R "rờ", S "sờ", T "tờ", U "u", Ư "ư", V "vờ", X "xờ", Y "i dài".
- Nét: chữ không dấu dùng **y hệt** nét của chữ cùng hình trong `letters_en.json`. Chữ có dấu phía trên (Ă Â Ê Ô): nét chữ gốc co theo chiều dọc vào dải y 0,3–0,9 (`y' = 0.3 + (y − 0.1) × 0.75`, x giữ nguyên), rồi thêm nét dấu (tô sau cùng):
  - Ă dấu trăng: `{"arc":[0.5,0.1,0.15,0.1,180,-180]}`
  - Â/Ê/Ô dấu mũ: `{"line":[[0.35,0.22],[0.5,0.08],[0.65,0.22]]}`
  - Ơ (không co): thêm `{"line":[[0.74,0.24],[0.94,0.06]]}`; Ư (không co): thêm `{"line":[[0.8,0.2],[0.96,0.04]]}`
  - Đ (không co): nét D + nét gạch `{"line":[[0.12,0.5],[0.42,0.5]]}` (tô sau cùng).
- Khóa mức thuộc: `balloon_vi_upper:<CHAR>`, `trace_vi_upper:<CHAR>`; phiên `game: 'balloon_vi'` / `'trace_vi'`.
- Câu nói (một đoạn `vi` mỗi câu, tên chữ nhúng trong câu để ngữ điệu tự nhiên), nhóm `vi_letters`:
  - `vi_balloon_prompt` "{name_vi} tìm chữ {spoken} nào!"
  - `vi_balloon_correct` "Đúng rồi! Chữ {spoken}!"
  - `vi_balloon_wrong_this` "Chưa đúng rồi, đây là chữ {tapped}."
  - `vi_balloon_wrong_find` "Tìm chữ {spoken} nha!"
  - `vi_trace_prompt` "Mình cùng viết chữ {spoken} nào!"
  - `vi_trace_done` "Giỏi quá! Chữ {spoken}!"
  - `game_vi_balloon` "Đập bong bóng", `game_vi_trace` "Tô chữ", `game_vi` giữ "Chữ cái tiếng Việt".
  - `{tapped}` = `spoken` của chữ bị bấm.
- Mọi câu thuộc loại `UtteranceKind.viLetters` — bắt buộc trong coverage test.
- Quy tắc trò chơi y như bản tiếng Anh (5 chữ/lượt bóng, 3 chữ/lượt tô, maxNew 3, +1/+5 ❄️, nhiệm vụ ngày, mở khóa chạm sau `wrong_this`, phát sáng sau 2 lần sai, `go_home` khi 🏠/back).
- Bản tiếng Anh không đổi hành vi; toàn bộ test hiện có phải xanh mà không sửa assertion (chỉ sửa cách khởi tạo nếu chữ ký constructor đổi).
- `flutter analyze --no-fatal-infos` sạch lỗi/cảnh báo; `flutter test` xanh.

### Task 1: Gói chữ tiếng Việt
**Files:** `content/packs/letters_vi.json`, `content/manifest.json`, `lib/core/content/models.dart` (`LetterItem.spoken` tùy chọn; `ContentBundle.lettersVi`), `lib/core/content/content_validator.dart` (gói `letters_vi` bắt buộc; chữ hợp lệ là 29 chữ trên; `spoken` không rỗng; nét như letters_en), tests (`test/core/content/*`, fixture).
- Sinh `letters_vi.json` đúng quy tắc nét ở trên bằng một script tạm (không commit script; ghi lệnh trong report), kiểm tra bằng test: chữ không dấu có nét trùng khớp letters_en; chữ có dấu trên nằm trong [0,1] và nét dấu nằm phía trên (y ≤ 0,25); thứ tự 29 chữ đúng; `spoken` đúng bảng.
- Validator: `char` của letters_vi thuộc tập 29 chữ (thay regex A–Z), không trùng; `spoken` bắt buộc với letters_vi.
- In ASCII render vài chữ (Ă Â Đ Ơ Ư) vào report để kiểm tra bằng mắt.
- Commit `feat: Vietnamese uppercase letters pack`.

### Task 2: Tổng quát hóa hai trò theo `LetterGameSpec`
**Files:** `lib/features/games/letter_game_spec.dart` (mới), `balloon_screen.dart`, `trace_screen.dart`, `balloon_logic.dart`/`trace_logic.dart` (khóa theo tiền tố), tests.
- `class LetterGameSpec { List<LetterItem> Function(ContentBundle) letters; String keyPrefix (ví dụ 'balloon_en_upper'); String sessionGame; String promptId, correctId, wrongThisId, wrongFindId (bóng) / promptId, doneId (tô); Map<String,String> Function(LetterItem target, {LetterItem? tapped}) vars; bool showExampleCard; }` với hai hằng/factory: `LetterGameSpec.balloonEn`, `.balloonVi`, `.traceEn`, `.traceVi` (đúng mã câu & biến hiện tại cho bản EN: `{letter}`, `{tapped}`; bản VI: `{spoken}`, `{tapped}` = spoken).
- `BalloonScreen({LetterGameSpec spec = LetterGameSpec.balloonEn})`, `TraceScreen({spec = traceEn})`. Bản VI của tô chữ: xong chữ không hiện thẻ ví dụ — hiện chữ to lấp lánh + nói `vi_trace_done`; tối thiểu 0,8 s như cũ.
- `buildBalloonRound`/`buildTraceRound` nhận `keyPrefix`.
- Test: toàn bộ test EN cũ xanh không sửa assertion; thêm test VI cho mỗi trò (một lượt đủ → màn thưởng; câu nói đúng mẫu với `spoken`; khóa mức thuộc `*_vi_upper:`; chữ có dấu tô được bằng cách vẽ theo nét mẫu).
- Commit `refactor: letter games take a LetterGameSpec; add Vietnamese specs`.

### Task 3: Câu nói, giọng, màn chọn, màn chính
**Files:** `content/phrases.json` (+manifest, `requiredPhraseIds`), `lib/core/voice/utterances.dart` (kind `viLetters`), coverage/parity tests, `content/audio/*`, `lib/features/games/vi_letters/vi_letters_screen.dart`, `home_screen.dart`, tests.
- Thêm câu như Global Constraints; enumeration `viLetters`: mọi câu × 29 chữ (wrong_this × 29 giá trị `tapped`); coverage bắt buộc; parity test gọi đúng như màn chơi.
- Tạo giọng: `dart run tool/gen_voice.dart --dry-run` → chạy thật với `--allow-api` (cache trước; đoạn ngắn gộp lô) → `--prune`. Báo số đoạn mới. Credentials do tool tự đọc; không đọc/in file.
- `VietnameseLettersScreen`: nền băng, 🏠 (`go_home`), Elsa, hai `BigButton` 🎈 / ✏️ (nói `game_vi_balloon` / `game_vi_trace` rồi mở `BalloonScreen(spec: balloonVi)` / `TraceScreen(spec: traceVi)`, có chống bấm đúp như màn chính).
- Màn chính: 🇻🇳 → `VietnameseLettersScreen` (nói `game_vi`).
- Tests: màn chọn mở đúng trò với spec VI; home 🇻🇳 mở màn chọn; vừa 360×640.
- `flutter test`, analyze, validate, `flutter build apk --debug`. Commit `feat: Vietnamese letters games`.

### Task 4 (controller): review toàn nhánh → sửa → `0.5.0+6` → PR → CI → merge → tag `v0.5.0`.
