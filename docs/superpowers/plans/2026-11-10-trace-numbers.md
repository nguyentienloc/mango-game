# 🔢 Tô chữ số 0–99 — Design + Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** v0.8.0 — nút ✏️ mở màn chọn 🔤 Chữ cái / 🔢 Chữ số. Trò tô số dùng lại `TraceScreen` (qua `LetterGameSpec`) với các số 0–99, Elsa đọc tên số tiếng Việt + tiếng Anh, sau khi tô hiện "mặt số" (0–9 kèm đúng số đồ vật), các số mở dần theo cấp.

**Architecture:** Gói nội dung mới `content/packs/digits.json` (nét 10 chữ số 0–9). Logic thuần `number_trace.dart` dựng `LetterItem` cho mọi số 0–99 (số 2 chữ số = ghép nét hai chữ số, thu nhỏ đều 0,75 và đặt cạnh nhau) và tính cấp đã mở từ mức thuộc. `LetterGameSpec.traceNumbers` cấu hình `TraceScreen`; màn chọn `TraceChooserScreen` theo khuôn `VietnameseLettersScreen`.

## Global Constraints
- Nhánh `feat/trace-numbers`. Phát hành `0.8.0+10`, tag `v0.8.0`.
- **Nét chữ số** (khung đơn vị như `letters_en.json`, y 0,1–0,9, chữ số chiếm x ≈ 0,25–0,75; dùng `line`/`arc` như chữ cái), kiểu viết mầm non Việt Nam, thứ tự nét:
  - 0: một nét cong kín (ellipse) bắt đầu ở đỉnh, đi ngược chiều kim đồng hồ.
  - 1: nét xiên ngắn từ trái-giữa lên đỉnh, rồi nét thẳng đứng xuống đáy (hai nét liền trong một stroke hoặc hai stroke — tùy cách hợp với chấm điểm).
  - 2: nét cong trên → nét xiên xuống trái-đáy → nét ngang đáy.
  - 3: hai nét cong hở bên trái (trên, dưới).
  - 4: nét xiên từ đỉnh xuống trái, nét ngang sang phải; nét thẳng đứng từ trên xuống (stroke riêng, sau).
  - 5: nét thẳng đứng ngắn trên-trái + nét cong bụng dưới (một stroke), rồi nét ngang trên cùng (stroke sau cùng).
  - 6: nét cong từ trên xuống trái rồi vòng kín ở dưới.
  - 7: nét ngang trên → nét xiên xuống đáy.
  - 8: một nét S từ đỉnh xuống rồi vòng ngược về đỉnh (có thể tách 2 stroke nếu chấm điểm cần).
  - 9: vòng kín trên (ngược chiều kim đồng hồ) rồi nét thẳng/cong xuống đáy.
- **Số 2 chữ số** `n = 10a + b`: nét của chữ số `a` rồi `b`, mỗi chữ số biến đổi đều `p' = c + (p − (0.5, 0.5)) × 0.7` với tâm `c = (0.27, 0.5)` cho hàng chục và `(0.73, 0.5)` cho hàng đơn vị (arc: tâm biến đổi như điểm, `rx`, `ry` × 0,7, góc giữ nguyên). Số 0–9: nét gốc, không biến đổi.
- **Cấp**: 1 = 0–9, 2 = 10–19, 3 = 20–39, 4 = 40–69, 5 = 70–99. Cấp 1 luôn mở; cấp k+1 mở khi **mọi** số của cấp k có `mastery ≥ 1` (khóa `trace_num:<n>`). Tập số của lượt = mọi số thuộc các cấp đã mở.
- Lượt: 3 số khác nhau (`buildTraceRound`, `maxNew 3`, keyPrefix `trace_num`); phiên `game: 'trace_num'`; +1 ❄️/firstTry, +5/lượt, nhiệm vụ ngày — như trò tô chữ.
- **Câu nói** (tất cả `group` "trace_numbers"):
  - `trace_num_prompt`: [vi "Mình cùng viết số"], [vi "{number}"], [en "{number}"]
  - `trace_num_done`: [vi "Giỏi quá! Số"], [vi "{number}"], [en "{number}"]
  - `trace_num_unlock`: vi "Mở khóa số mới rồi nè!"
  - `game_trace_letters`: vi "Chữ cái"; `game_trace_numbers`: vi "Chữ số"; `game_trace` giữ "Tô chữ".
  - `{number}` = chữ số thập phân (`'23'`). Đoạn `vi|<n>` đã có clip (từ `snowflake_count`); cần clip mới cho `en|0`…`en|99` và các đoạn cố định. Kind mới `UtteranceKind.traceNumbers` (bắt buộc trong coverage test) liệt kê prompt + done cho n = 0..99.
- **Sau khi tô xong một số** (thay thẻ ví dụ): số to + n = 1–9: hàng/lưới n emoji giống nhau (emoji theo số: 1 🍎, 2 ⭐, 3 🐟, 4 🌸, 5 🎈, 6 🍓, 7 🦋, 8 🍪, 9 🐥); n = 0: số to + giỏ trống 🧺; n ≥ 10: số to lấp lánh (như `_SparkleLetter`). Tối thiểu 0,8 s như cũ.
- **Mở cấp**: khi kết thúc lượt, nếu cấp đã mở tăng so với lúc vào trò → nói `trace_num_unlock` (chờ tối đa 3 s) trước khi sang màn thưởng.
- Màn chọn: ✏️ trên màn chính → `TraceChooserScreen` (nói `game_trace`), hai `BigButton` 🔤 (nói `game_trace_letters` → `TraceScreen()` bản EN hiện tại, `popToRootOnExit` như bản VI) / 🔢 (nói `game_trace_numbers` → `TraceScreen(spec: LetterGameSpec.traceNumbers)`), 🏠 `go_home`, chống bấm đúp như `VietnameseLettersScreen`.
- Bản EN / VI không đổi hành vi (ngoài việc ✏️ giờ qua màn chọn); test hiện có xanh, chỉ sửa test điều hướng của ✏️.
- Không đọc/in credentials (`~/.config/xoai/*`); `tool/gen_voice.dart` tự đọc.
- Mọi chạm điều hướng có tiếng; vừa 360×640; `flutter analyze --no-fatal-infos` sạch lỗi/cảnh báo; `flutter test` xanh.

### Task 1: Gói chữ số + dựng số + cấp
**Files:** Create `content/packs/digits.json`, `lib/features/games/trace/number_trace.dart`; Modify `content/manifest.json`, `lib/core/content/models.dart` (`ContentBundle.digits`, `List<LetterItem>`), `lib/core/content/content_validator.dart`, `test/support/content_fixture.dart`; Tests `test/features/trace/number_trace_test.dart`, `test/core/content/*`.

**Produces:**
```dart
/// Every number 0..99 as a traceable item (char = '$n', strokes composed from [digits]).
List<LetterItem> buildNumberItems(List<LetterItem> digits);
const numberLevels = [(0, 9), (10, 19), (20, 39), (40, 69), (70, 99)];
String numberTraceKey(int n) => 'trace_num:$n';
/// 1..5: highest unlocked level given mastery stats keyed by numberTraceKey.
int unlockedNumberLevel(Map<String, ItemStat> stats);
/// Items of all unlocked levels.
List<LetterItem> unlockedNumbers(List<LetterItem> numbers, Map<String, ItemStat> stats);
```
- [ ] Test trước: 100 item, char '0'..'99'; số 0–9 nét trùng digits; số 37 = nét '3' biến đổi về tâm (0.27,0.5) rồi nét '7' về (0.73,0.5), mọi điểm trong [0,1], hai nửa không chồng nhau (x hàng chục < 0.5 < x hàng đơn vị, kể cả biên arc); cấp: rỗng → 1; mọi 0–9 mastery ≥1 → 2; thiếu một số → vẫn 1; nhảy cấp không bỏ qua (cấp 3 cần cả cấp 2 xong); `unlockedNumbers` đúng tập.
- [ ] `digits.json` (`{"id":"digits","version":1,"items":[{"char":"0","strokes":[...]}, ...]}`) theo Global Constraints; validator: gói bắt buộc, đúng 10 item '0'..'9' theo thứ tự, nét hợp lệ như letters (dùng lại hàm kiểm nét). In ASCII render 10 chữ số + vài số 2 chữ số (10, 23, 88) vào report để kiểm tra bằng mắt.
- [ ] `flutter test`, analyze, `dart run tool/validate_content.dart`. Commit `feat: digit strokes, numbers 0-99 and unlock levels`.

### Task 2: Trò tô số, câu nói, giọng, màn chọn
**Files:** `lib/features/games/letter_game_spec.dart` (`traceNumbers`, hook hiển thị sau khi tô), `lib/features/games/trace/trace_screen.dart`, Create `lib/features/games/trace/number_face.dart`, `lib/features/games/trace/trace_chooser_screen.dart`; Modify `lib/features/home/home_screen.dart`, `content/phrases.json` (+manifest, `requiredPhraseIds`), `lib/core/voice/utterances.dart`, coverage/parity tests, `content/audio/*`; Tests `test/features/trace/trace_numbers_screen_test.dart`, chooser + home tests.

**Consumes:** Task 1 (`buildNumberItems`, `unlockedNumbers`, `unlockedNumberLevel`, `numberTraceKey`, `ContentBundle.digits`).
- [ ] `LetterGameSpec.traceNumbers`: letters = `unlockedNumbers(buildNumberItems(content.digits), stats)` — nếu spec hiện nhận `letters(ContentBundle)` không có stats, thêm cách chọn tập theo stats tối thiểu (ví dụ `letters` nhận thêm stats, hoặc một `filter` tùy chọn) mà không đổi hành vi EN/VI; keyPrefix `trace_num`; sessionGame `trace_num`; promptId `trace_num_prompt`; doneId `trace_num_done`; vars `{'number': item.char}`; hiển thị sau khi tô = `NumberFace(n)`; `popToRootOnExit: true`.
- [ ] `NumberFace`: theo Global Constraints (`Key('number-face-<n>')`, mỗi emoji đếm `Key('number-face-item')`); vừa vùng thẻ ví dụ hiện có ở 360×640.
- [ ] Mở cấp: `TraceScreen` ghi cấp lúc vào (chỉ với spec số); `_finish` tính lại sau khi lưu stats; tăng → `say('trace_num_unlock')` (cap 3 s) rồi màn thưởng.
- [ ] Câu nói + `UtteranceKind.traceNumbers` + coverage bắt buộc + parity test (gọi đúng như màn chơi). Tạo giọng: `dart run tool/gen_voice.dart --dry-run` → `--allow-api` (đoạn ngắn gộp lô) → `--prune`; báo số đoạn mới (~100 `en|n` + vài đoạn cố định).
- [ ] `TraceChooserScreen` + home ✏️ → chooser (phrase `game_trace`).
- [ ] Tests: lượt đầu chỉ có số 0–9; tô đủ 3 số → màn thưởng `+8 ❄️` khi đúng hết; câu nói "Mình cùng viết số" + "7" (vi) + "7" (en); sau khi tô 7 thấy 7 `number-face-item`; 0 → giỏ; 23 → không có item đếm; stats làm cấp 1 xong trừ một số, tô số đó đúng → nói "Mở khóa số mới rồi nè!" trước màn thưởng; chooser mở đúng hai trò; home ✏️ mở chooser; vừa 360×640 (cả số 2 chữ số trên pad).
- [ ] `flutter test`, analyze, validate, `flutter build apk --debug`. Commit `feat: number tracing 0-99 with a letters/numbers chooser`.

### Task 3 (controller): review toàn nhánh → sửa → `0.8.0+10` → PR → CI → merge → tag `v0.8.0`.
