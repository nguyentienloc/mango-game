# 🗣️ Nói chuyện với Elsa — Design + Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** v0.6.0 — trò 🗣️: Elsa hỏi câu giao tiếp tiếng Anh, bé giữ nút micro trả lời, app nhận giọng nói (Android SpeechRecognizer qua `speech_to_text`) và chấm rất dễ theo từ khóa; không nhận được giọng → chế độ "nghe rồi nói theo".

**Architecture:** Gói nội dung `content/packs/conversation.json` (câu hỏi, nhóm từ khóa chấp nhận, bí danh, câu mẫu). Logic thuần Dart: `AnswerMatcher` (chuẩn hóa + nhóm từ khóa + bí danh), `TalkSession` (5 câu/lượt, luồng thử 3 lần), chọn câu theo mức thuộc. `SpeechRecognizer` interface + `SpeechToTextRecognizer`; `TalkScreen` theo khuôn `VocabScreen`.

## Global Constraints
- Nhánh `feat/talk`. Phát hành `0.6.0+7`, tag `v0.6.0`.
- Câu hỏi (id → hỏi / chấp nhận nếu có ≥1 nhóm mà mọi từ trong nhóm xuất hiện / câu mẫu):
  - `name` → "What's your name?" / `[name, an]`, `[an]`, `[xoai]`, `[im, an]` / "My name is {name_en}."
  - `age` → "How old are you?" / `[five]`, `[four]`, `[5]`, `[4]` / "I am five."
  - `how_are_you` → "How are you?" / `[fine]`, `[good]`, `[great]`, `[ok]`, `[okay]`, `[happy]` / "I'm fine, thank you!"
  - `hello` → "Hello, {name_en}!" / `[hello]`, `[hi]`, `[hey]` / "Hello, Elsa!"
  - `goodbye` → "Goodbye, {name_en}!" / `[bye]`, `[goodbye]` / "Goodbye, Elsa!"
  - `color` → "What color do you like?" / mỗi màu một nhóm: red, blue, pink, green, yellow, purple, orange, white, black / "I like blue."
  - `apples` → "Do you like apples?" / `[yes]`, `[yeah]`, `[no]`, `[like]` / "Yes, I do!"
  - `flower` → "Here is a flower for you!" / `[thank]`, `[thanks]` / "Thank you!"
- Bí danh (mỗi từ khóa có thể khớp bí danh): an → ann, anne, and, en, un, ang; xoai → swine, soy, sway, xoài; five → fine, fight, 5; four → for, fourth, 4; fine → find, fun; hello → hallo, hullo, yellow; bye → by, buy, bai; thank → tank, thanks, thankyou; yes → yesh, yep; red → read; blue → blew. (Bí danh là dữ liệu trong JSON, sửa được.)
- Chuẩn hóa: chữ thường, bỏ dấu câu, "'" bỏ (i'm → im), tách theo khoảng trắng; số giữ nguyên.
- Luồng một câu: Elsa hỏi → bé giữ 🎤 (tối đa 8 s; nút khóa khi Elsa đang nói) → thả → chấm. Đúng → khen (nhóm `praise`) + "+1 ❄️ nếu lần đầu". Sai lần 1 → `talk_again` (en "Hmm, can you say it again?"). Sai lần 2 → `talk_say_after` [vi "Con nói theo Elsa nhé:"], [en "{model}"]. Lần 3 → luôn đạt, khen (kết quả `hinted`). Kết quả: `firstTry`/`retry`/`hinted`; khóa `conv:<id>`; 5 câu/lượt (maxNew 3); +5 ❄️/lượt; phiên `game: 'talk'`.
- Chế độ nói theo (STT không sẵn sàng hoặc bị từ chối quyền micro): Elsa hỏi → `talk_say_after` → hiện nút ✅ lớn → bấm → sang câu (không đổi mức thuộc, +1 ❄️ mỗi câu). Màn hình nhỏ báo "chế độ nói theo" chỉ trong khu bố mẹ? — Không: không hiện chữ; chỉ đổi nút 🎤 thành ✅.
- Nhận giọng: `speech_to_text`, locale `en_US` (ưu tiên `en-US`), `onDevice: true` nếu được hỗ trợ (thử trước, lỗi → online), `listenFor` 8 s, `pauseFor` 3 s, lấy kết quả cuối + mọi alternates (chấm đạt nếu bất kỳ phương án nào khớp).
- Android: quyền `RECORD_AUDIO`; `<queries>` thêm `<intent><action android:name="android.speech.RecognitionService"/></intent>`.
- Câu nói mới (đều có clip): 8 câu hỏi (en), 8 câu mẫu (en, qua `talk_say_after`), `talk_again`, `talk_say_after` phần vi, `talk_hold_hint` vi "Bấm giữ nút micro rồi nói nha!" (nói một lần khi vào trò). Kind `talk` bắt buộc trong coverage.
- Mọi chạm điều hướng có tiếng; vừa 360×640; `flutter analyze --no-fatal-infos` sạch; `flutter test` xanh.

### Task 1: Nội dung + logic chấm
**Files:** `content/packs/conversation.json` (+manifest), `lib/core/content/models.dart` (`ConversationItem`), validator, `lib/features/games/talk/answer_matcher.dart`, `lib/features/games/talk/talk_logic.dart` (`buildTalkRound`, `TalkTurn` state machine: attempts, outcome, `mode` normal/followAlong), tests.
- Validator: id duy nhất, `question`/`model` không rỗng, `accept` ≥1 nhóm không rỗng, aliases là map từ → danh sách.
- `AnswerMatcher.matches(ConversationItem item, List<String> transcripts)`; tests cho từng câu với các phiên âm sai thường gặp ("my name is and" đạt; "I am fine" đạt câu how_are_you; "banana" không đạt; rỗng không đạt; "I'm five" đạt age).
- `TalkTurn`: `submit(List<String> transcripts) → TalkFeedback {correct, tryAgain, sayAfter, passAfterHelp}`; `outcome`; follow-along `confirm()`.
- Commit `feat: conversation content and lenient answer matching`.

### Task 2: Nhận giọng + câu nói + giọng
**Files:** `pubspec.yaml` (`speech_to_text`), `android/app/src/main/AndroidManifest.xml`, `lib/core/speech/speech_recognizer.dart` (interface `SpeechRecognizer { Future<bool> init(); bool get available; Future<void> start({required void Function(List<String> transcripts, bool isFinal) onResult}); Future<void> stop(); Future<void> cancel(); }`), `lib/core/speech/speech_to_text_recognizer.dart`, provider `speechRecognizerProvider`, fake `FakeSpeechRecognizer` (tests), `content/phrases.json` (+manifest, requiredPhraseIds), `utterances.dart` (kind `talk`), coverage/parity tests, `content/audio/*`.
- Kiểm tra API `speech_to_text` bản cài (đọc dartdoc trong ~/.pub-cache) cho `onDevice`, alternates, `listenFor`/`pauseFor`, lỗi/permission; ghi lại trong report.
- Câu hỏi/câu mẫu thuộc `conversation.json` → enumeration đọc trực tiếp từ gói (render `{name_en}`).
- Tạo giọng: `--dry-run`, rồi `--allow-api` (Vbee; tool tự đọc credentials, không đọc/in file), `--prune`.
- Commit `feat: speech recognizer and talk voice lines`.

### Task 3: Màn chơi + màn chính
**Files:** `lib/features/games/talk/talk_screen.dart`, `mic_button.dart`, `home_screen.dart`, tests.
- `MicButton`: nút tròn lớn 🎤 (≥ 120 dp), giữ để nghe (vòng sóng nhấp nháy khi nghe), thả → dừng; khóa (mờ) khi Elsa đang nói hoặc đang chấm; giữ quá 8 s tự dừng.
- `TalkScreen` theo khuôn `VocabScreen` (guard, busy, finishing, PopScope + back `go_home`, 🏠 `go_home`, Elsa chạm → hỏi lại, `_finish` → phiên `'talk'` + completeRound + RewardScreen). Lần đầu vào: xin quyền micro (qua `speech_to_text` init); thất bại → chế độ nói theo cho cả lượt.
- Home: 🗣️ → `TalkScreen`.
- Tests với `FakeSpeechRecognizer`: trả lời đúng ngay → khen, +1; sai → "Hmm, can you say it again?"; sai 2 → câu mẫu; lần 3 luôn đạt; đủ 5 câu → RewardScreen `+10 ❄️` khi đúng hết; STT không sẵn sàng → nút ✅ và luồng nói theo; nút micro khóa khi Elsa nói; vừa 360×640.
- `flutter test`, analyze, `flutter build apk --debug`. Commit `feat: talk with Elsa game`.

### Task 4 (controller): review toàn nhánh → sửa → `0.6.0+7` → PR → CI → merge → tag `v0.6.0`.
