# Đập bong bóng chữ cái — Design + Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** v0.4.0 — trò 🎈 Đập bong bóng thay trò Tìm chữ cái cũ: bóng nhiều màu chứa chữ IN HOA A–Z bay từ dưới lên; Elsa bảo "Xoài tìm chữ B nào!"; bấm quả nào quả đó nổ và Elsa báo đúng/sai.

**Architecture:** Logic thuần Dart (`balloon_logic.dart`): dựng lượt 5 chữ bằng `QuestionPicker`, bộ sinh bóng giữ bất biến "không trùng chữ trên màn hình, chữ đích luôn có mặt", phiên dùng lại `PickSession`. UI: `BalloonField` (một `Ticker` cập nhật vị trí, mỗi quả là widget vẽ bằng CustomPainter, nổ bằng animation + pháo giấy) và `BalloonScreen` theo khuôn `VocabScreen`. Câu nói nhiều đoạn (vi + tên chữ en) phát theo clip từng đoạn.

## Global Constraints
- Phát hành chung `0.4.0+5`, tag `v0.4.0` (nhánh `feat/small-fixes-032`, sau các commit sửa nhỏ).
- 5 chữ/lượt; khóa `balloon_en_upper:<CHAR>`; `maxNew: 3`; phiên `game: 'balloon'`.
- Trên màn hình: 5–6 bóng (6 nếu rộng ≥ 360 dp); mỗi bóng bay hết chiều cao trong 11–14 s (từ v0.4.1; trước đó 7–9 s) (ngẫu nhiên), lắc ngang ±12 dp hình sin; đường kính ≈ 84–96 dp; không bao giờ 2 bóng cùng chữ; chữ đích luôn có ít nhất 1 bóng đang bay hoặc sắp xuất hiện (≤ 1,5 s); bóng ra khỏi mép trên → thay bóng mới từ dưới.
- Bấm bất kỳ bóng nào → nổ. Đúng → `balloon_correct`, sang chữ sau (bóng còn lại tiếp tục bay). Sai → `balloon_wrong` (đọc tên chữ vừa bấm + nhắc chữ đích); sai ≥ 2 lần → bóng đích phát sáng. Kết quả: `firstTry`/`retry`/`hinted` như `PickSession`. +1 ❄️/firstTry, +5/lượt, nhiệm vụ ngày.
- Câu nói (tất cả `group: "balloon"`):
  - `balloon_prompt`: [vi "{name_vi} tìm chữ"], [en "{letter}"], [vi "nào!"]
  - `balloon_correct`: [vi "Đúng rồi!"], [en "{letter}!"]
  - `balloon_wrong`: [vi "Chưa đúng rồi, đây là chữ"], [en "{tapped}"], [vi "Tìm chữ"], [en "{letter}"], [vi "nha!"]
  - Thêm vào `requiredPhraseIds`; `enumerateUtterances` thêm `UtteranceKind.balloon` (bắt buộc trong coverage test): prompt + correct cho 26 chữ, wrong cho mọi cặp? **Không** — `balloon_wrong` chỉ cần các đoạn; vì clip theo đoạn, liệt kê `balloon_wrong` với `{tapped: X, letter: Y}` cho Y cố định = 'A' và X chạy 26 chữ, cộng X='A', Y chạy 26 chữ là đủ phủ mọi đoạn (đoạn không phụ thuộc cặp). Ghi rõ lý do trong code.
- Bỏ trò Tìm chữ cái cũ: xóa `lib/features/games/find_letter/find_letter_screen.dart`, `falling_flakes.dart`, `find_letter_logic.dart` (giữ `example_card.dart` — trò tô chữ dùng; chuyển nó sang `lib/shared/example_card.dart`), tests liên quan; xóa công tắc "Hiện trò Tìm chữ cái" khỏi `ParentScreen`, `showFindLetterProvider`/controller và test; **giữ** cột DB `showFindLetter` (không đổi schema) và các phương thức store nếu còn test migration dùng — đánh dấu `// unused since v0.4.0`. Phrase `find_letter_prompt`, `find_letter_small_prompt`, `game_find_letter` bỏ khỏi `phrases.json`/`requiredPhraseIds`; `letter_example` giữ (trò tô chữ). Kind `letters` trong enumeration bỏ. `--prune` xóa clip mồ côi.
- Phrase `game_balloon` vi "Đập bong bóng"; màn chính: 🐾 → 🎈 (BalloonScreen) → ✏️ → 🗣️ → 🇻🇳.
- Giọng mới: tạo bằng `tool/gen_voice.dart` (chế độ gộp lô cho đoạn ngắn đã có từ v0.3.2).
- Mọi chạm điều hướng có tiếng; vừa màn 360×640; `flutter analyze --no-fatal-infos` sạch; `flutter test` xanh.

### Task 1: Logic
**Files:** `lib/features/games/balloon/balloon_logic.dart`, `test/features/balloon/balloon_logic_test.dart`.
- `String balloonKey(LetterItem l)`; `List<LetterItem> buildBalloonRound({letters, stats, picker, count = 5, maxNew = 3})` (chữ khác nhau như `buildTraceRound`).
- `class BalloonQuestion implements PickQuestion { LetterItem item; key; answer => item.char }`.
- `class BalloonSpawner { BalloonSpawner({required List<String> alphabet, required Random random}); String nextLetter({required Set<String> onScreen, required String target, required bool targetPending}); }` — trả chữ không có trên màn hình; nếu chữ đích không có trên màn hình và chưa có bóng chờ (`targetPending == false`) → trả chữ đích; ngoài ra ngẫu nhiên, ưu tiên chữ đích với xác suất 1/4 khi nó chưa có mặt.
- `class Balloon { int id; String letter; int colorIndex; double x (0–1 tâm); double startTime; double duration; double wobblePhase; double progress(double t); bool get popped; }` thuần dữ liệu; `double balloonY(progress)` 1 → 0 (dưới lên).
- Tests: round 5 chữ khác nhau (nhiều seed), maxNew; spawner không bao giờ trả chữ đã có trên màn hình (chạy 1000 bước giả lập với tập onScreen thay đổi), luôn trả chữ đích khi đích vắng mặt và không chờ, phân bố màu/chữ hợp lệ; PickSession với BalloonQuestion (sai 2 lần → showHint, kết quả hinted).

### Task 2: Câu nói, giọng, bỏ trò cũ
**Files:** `content/phrases.json` (+manifest), `content_validator.dart`, `utterances.dart`, coverage/parity/utterances tests, `content/audio/*`, xóa trò cũ + công tắc, `home_screen.dart` (tạm trỏ 🎈 sang placeholder `BalloonScreen` rỗng nếu Task 3 chưa có — hoặc làm Task 2 sau Task 3; khuyến nghị: Task 2 không đụng home, Task 3 nối home).
- Thêm phrases như Global Constraints + `game_balloon`; bỏ phrases trò cũ; enumeration `balloon` kind; coverage bắt buộc `balloon`; parity test: say các câu balloon như màn chơi gọi.
- Xóa code + test trò cũ, công tắc + provider/controller + test; giữ DB column.
- Tạo giọng: `dart run tool/gen_voice.dart --dry-run` rồi chạy thật (cache + gộp lô cho đoạn ngắn) và `--prune`. Báo số đoạn mới.
- `flutter test`, analyze, validate. Commit `feat: balloon game phrases; retire the old find-letter game`.

### Task 3: Màn chơi
**Files:** `lib/features/games/balloon/balloon_field.dart`, `balloon_screen.dart`, `lib/shared/example_card.dart` (nếu chưa chuyển), `home_screen.dart`, tests `test/features/balloon/balloon_screen_test.dart`, home tests.
- `BalloonField({required String target, required ValueChanged<String> onPop, String? hint, required Random random, bool enabled})`: `Ticker` cập nhật; giữ danh sách bóng; spawn theo `BalloonSpawner` để duy trì số bóng; bóng vẽ bằng CustomPainter (thân tròn hơi oval màu bảng 8 màu tươi, dây, chữ trắng viền đậm ở giữa, bóng sáng nhỏ); `Key('balloon-<LETTER>')` trên mỗi bóng; chạm (`onTapDown`, vùng chạm = cả quả + 12 dp) → animation nổ 250 ms (phóng to + mờ + 8 mảnh pháo giấy) rồi gỡ bỏ, gọi `onPop(letter)`; bóng đích phát sáng khi `hint == letter`. Có `@visibleForTesting` cách đặt thời gian (ví dụ `debugTimeDilation`-free: dùng `tester.pump` với Ticker là đủ).
- `BalloonScreen`: như `VocabScreen` (guard, busy, finishing, PopScope + back `go_home`, 🏠 `go_home`, Elsa nói lại prompt, `_finish` lưu phiên `'balloon'` + completeRound + RewardScreen). Đúng → `_busy` trong lúc đọc `balloon_correct` (tối thiểu 0,8 s) rồi chữ sau; sai → `balloon_wrong` với `{tapped, letter}` (không khóa bấm lâu: cho bấm tiếp sau khi câu bắt đầu? — chọn: khóa trong lúc Elsa nói để tránh câu chồng).
- Home: 🎈 → `BalloonScreen` (phrase `game_balloon`).
- Tests: lượt đủ 5 chữ bấm đúng → RewardScreen `+10 ❄️`; bấm sai đọc "Chưa đúng rồi, đây là chữ" + tên chữ, bóng sai biến mất; sai 2 lần → `Key('balloon-glow-<target>')`; không bao giờ có 2 bóng trùng chữ (kiểm tra qua các khung hình trong 20 s mô phỏng); chữ đích luôn có mặt trong ≤ 1,5 s; vừa 360×640.
- `flutter test`, analyze, `flutter build apk --debug`. Commit `feat: balloon pop letter game`.

### Task 4 (controller): review toàn nhánh → sửa → cài thử (versionCode < 400) → `0.4.0+5` → PR → CI → merge → tag `v0.4.0`.
