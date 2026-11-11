# ⚖️ So sánh + Tô dấu + Tô 10 lần — Design + Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** v0.9.0 — (1) mọi trò tô 10 lần/lượt kèm hàng 10 chấm tiến độ; (2) 🇻🇳 thêm trò **Tô dấu** (sắc, huyền, hỏi, ngã, nặng) — tô xong hiện "A + ´ = Á" và Elsa đọc "a, sắc, á"; (3) trò mới **⚖️ So sánh** (nút thứ 7 màn chính) với 4 cấp: nhiều hơn/ít hơn bằng hình → chọn dấu > < = cho số 0–10 (có chấm đếm) → 0–20 → 0–99.

**Mockup đã duyệt:** https://claude.ai/artifact/DogF691Vnj6Nbq1Ps7md4S (màn 1–10). Khung cam đứt nét trong mockup = câu Elsa nói, KHÔNG vẽ trong app; chữ ghi chú xanh nhỏ và chữ dưới nút của mockup cũng KHÔNG vẽ trong app (app chỉ có nút, Elsa đọc tên khi bấm).

## Global Constraints
- Nhánh `feat/compare-tones`. Phát hành `0.9.0+11`, tag `v0.9.0`. Cài thử lên thiết bị adb đang nối (Xiaomi 23021RAAEG) bằng bản release ký sẵn từ GitHub (`adb install -r xoai-v0.9.0.apk`).
- Màu/kiểu như app hiện có (`IceColors`, `IceBackground`, `BigButton`, `CharacterView('elsa')`, 🏠 trái, thẻ đếm "n/10" phải).
- **Tô 10 lần**: `TraceScreen` lượt = 10 mục (EN, VI, số, dấu). Nếu tập mục nhỏ hơn 10 → lặp lại, không có hai mục giống nhau liền nhau, phân bố đều (mỗi mục xuất hiện ⌊10/n⌋ hoặc ⌈10/n⌉ lần). Hàng 10 chấm tiến độ dưới đầu màn (đã làm: đậm, đang làm: viền cam, chưa: nhạt) — `Key('trace-progress-dot')`. Thưởng: +1 ❄️ mỗi mục đúng ngay lần đầu (mục lặp lại cũng tính), +5/lượt, nhiệm vụ ngày.
- **Tô dấu**: gói `content/packs/tones.json` 5 mục (thứ tự sắc, huyền, hỏi, ngã, nặng), mỗi mục `{"id":"sac","name":"sắc","mark":"´","strokes":[...]}`, khung đơn vị, dấu to giữa khung:
  - sắc: một nét xiên từ dưới-trái (0.34,0.74) lên trên-phải (0.66,0.26).
  - huyền: một nét xiên từ trên-trái (0.34,0.26) xuống dưới-phải (0.66,0.74).
  - hỏi: một nét móc như nửa trên dấu hỏi không chấm: bắt đầu trái-trên, cong sang phải rồi xuống giữa (dài ≥ 0.5).
  - ngã: một nét lượn sóng trái → phải (hai cung nối nhau) ở giữa khung.
  - nặng: một vòng tròn nhỏ kín bán kính ≈ 0.12 tâm (0.5,0.5) (không phải chấm — để chấm điểm được).
  - Khóa `trace_tone:<id>`, phiên `game: 'trace_tone'`.
  - Hàng 5 ô dấu phía trên khung (ô của dấu đang tô tô đậm) như mockup màn 8.
  - Xong một dấu: thẻ "X + dấu = Xdấu" (X lần lượt xoay vòng A, E, O, U, I theo thứ tự xuất hiện trong lượt), dưới thẻ chữ "dấu <name>"; KHÔNG có hàng gợi ý Á À Ả Ã Ạ.
  - Câu nói (một đoạn `vi` mỗi câu, `group` "vi_tones"): `vi_tone_prompt` "Mình cùng tô dấu {tone} nào!" · `vi_tone_done` "Giỏi quá! {base}, {tone}, {combined}!" với `{base}` ∈ a e o u i, `{combined}` = chữ thường có dấu (á, à, ả, ã, ạ, é…). `game_vi_tone` "Tô dấu". Kind mới `UtteranceKind.viTones` (prompt × 5 + done × 25), bắt buộc trong coverage.
  - Màn 🇻🇳 thêm nút thứ 3 hiển thị chữ "á" (BigButton text) → `TraceScreen(spec: LetterGameSpec.traceTones)`.
- **So sánh** (`lib/features/games/compare/`):
  - Cấp 1: hai thẻ hình (cùng một emoji, xoay theo lượt: 🍎 ⭐ 🐟 🌸 🎈 🍓 🦋 🍪 🐥), số lượng 1–10 khác nhau; câu hỏi ngẫu nhiên "nhiều hơn" hoặc "ít hơn"; bé chạm một thẻ. Sau khi đúng: hiện số dưới mỗi thẻ, thẻ đúng viền vàng phát sáng, "+1 ❄️" nếu đúng lần đầu.
  - Cấp 2: hai số 0–10 kèm chấm đếm (chấm hồng, xếp lưới), ô "?" ở giữa, 3 nút xanh lá ">" (🐊), "<" (🐊 lật), xanh dương "=" (🤝). Cấp 3: 0–20 không chấm. Cấp 4: 0–99 không chấm, ≥ 2 câu/lượt là cặp đảo chữ số (ab vs ba, a≠b, cả hai ≥ 10).
  - Cấp 2–4: khoảng 1/5 câu là hai số bằng nhau. Đúng: dấu bay vào ô "?", cá sấu há về số lớn (với =: 🤝), chữ "3 bé hơn 5" dưới.
  - Sai: lần 1 thẻ/nút sai lắc + `compare_try_again` "Thử lại nha!"; lần 2 đáp án đúng phát sáng (`Key('compare-hint')`); kết quả firstTry/retry/hinted như `PickSession`.
  - 10 câu/lượt; +1 ❄️/firstTry, +5/lượt, nhiệm vụ ngày; phiên `game: 'compare'`.
  - Lên cấp: lượt có ≥ 8 câu firstTry → cấp +1 (tối đa 4), Elsa nói `compare_level_up` "Lên cấp rồi! Giỏi quá!" trước màn thưởng. Cấp lưu bằng `ItemStatsStore` khóa `compare:level` (giá trị = `mastery` 0..3 ↔ cấp 1..4; không đổi schema DB; Đặt lại tiến độ → cấp 1).
  - Câu nói (clip theo đoạn; đoạn số `vi|<n>` đã có clip 0–999), `group` "compare":
    - `compare_more` "Bên nào nhiều hơn?" · `compare_fewer` "Bên nào ít hơn?"
    - `compare_ask`: [vi "{a}"], [vi "và"], [vi "{b}"], [vi "Chọn dấu nào nhỉ?"]
    - `compare_right_more`: [vi "Đúng rồi!"], [vi "{a}"], [vi "nhiều hơn"], [vi "{b}"] · `compare_right_fewer`: … [vi "ít hơn"] …
    - `compare_right_gt`: [vi "Đúng rồi!"], [vi "{a}"], [vi "lớn hơn"], [vi "{b}"] · `compare_right_lt`: … "bé hơn" … · `compare_right_eq`: … "bằng" …
    - `compare_try_again` "Thử lại nha!" · `compare_level_up` "Lên cấp rồi! Giỏi quá!" · `game_compare` "So sánh".
    - Kind mới `UtteranceKind.compare` liệt kê đủ để phủ mọi đoạn (a chạy 0..99 với b cố định và ngược lại — ghi lý do trong code), bắt buộc trong coverage.
  - Màn chính: `_GameEntry('⚖️', 'game_compare', (_) => const CompareScreen())` chèn trước 🌙; 7 nút vừa 360×640.
- Không đọc/in credentials (`~/.config/xoai/*`); `tool/gen_voice.dart` tự đọc; tạo giọng: `--dry-run` → `--allow-api` → `--prune`.
- Mọi chạm điều hướng có tiếng; vừa 360×640; `flutter analyze --no-fatal-infos` sạch lỗi/cảnh báo; `flutter test` xanh. Không chạy `dart format` toàn repo.

### Task 1: Tô 10 lần + hàng chấm tiến độ
**Files:** `lib/features/games/trace/trace_logic.dart` (`buildTraceRound` count 10, lặp khi thiếu), `trace_screen.dart` (hàng chấm), tests trace hiện có (sửa số mục/lượt trong assertion nơi cần), test mới cho lặp lại.
- [ ] Test trước: pool 26 → 10 khác nhau; pool 5 → 10 mục, mỗi mục 2 lần, không liền nhau (nhiều seed); pool 1 → 10 lần cùng mục (ngoại lệ duy nhất cho "không liền nhau"); hàng chấm: 10 `trace-progress-dot`, chấm hiện tại đổi khi sang mục; lượt đủ 10 → màn thưởng `+15 ❄️` khi đúng hết.
- [ ] Commit `feat: tracing rounds of 10 with a progress row`.

### Task 2: Tô dấu
**Files:** `content/packs/tones.json` (+manifest), `lib/core/content/models.dart` (`ToneItem` hoặc tái dùng `LetterItem` + tên), validator, `lib/features/games/trace/tone_trace.dart` (dựng item, chữ ghép), `letter_game_spec.dart` (`traceTones`), `tone_face.dart`, `trace_screen.dart` (hàng 5 ô dấu qua hook của spec), `vi_letters_screen.dart` (nút 3), phrases/utterances/coverage/parity, `content/audio/*`, tests.
- [ ] Theo Global Constraints. ASCII render 5 dấu vào report. Test: mỗi dấu tô theo nét mẫu đạt (như test số); nặng là vòng kín; lượt 10 có mỗi dấu 2 lần; chữ ghép xoay A E O U I; câu nói đúng ("Giỏi quá! a, sắc, á!"); nút 3 trong 🇻🇳 mở trò; vừa 360×640.
- [ ] Commit `feat: Vietnamese tone-mark tracing`.

### Task 3: Trò So sánh
**Files:** `lib/features/games/compare/compare_logic.dart` (sinh câu theo cấp, đáp án, lên cấp), `compare_screen.dart`, `compare_cards.dart` (thẻ hình/thẻ số/nút dấu), `home_screen.dart`, phrases/utterances/coverage/parity, `content/audio/*`, tests.
- [ ] Logic test trước: cấp 1 hai số lượng khác nhau 1–10; cấp 2–4 khoảng số đúng, tỉ lệ bằng nhau ≈ 1/5 (±, nhiều seed), cấp 4 có ≥ 2 cặp đảo chữ số; đáp án đúng; lên cấp khi ≥ 8 firstTry, tối đa 4; đọc/ghi cấp qua `compare:level`.
- [ ] Widget test: cấp 1 nói "Bên nào nhiều hơn?" và chạm đúng → "Đúng rồi!" + số + nhiều hơn + số; sai 1 → "Thử lại nha!"; sai 2 → `compare-hint`; cấp 2 có chấm đếm, chọn "<" đúng; lượt 10 → màn thưởng `+15 ❄️` khi đúng hết; ≥8 firstTry → "Lên cấp rồi! Giỏi quá!" trước màn thưởng; home ⚖️ nói "So sánh" rồi mở trò; 7 nút vừa 360×640; mọi màn vừa 360×640.
- [ ] Commit `feat: compare game (more/fewer, > < =)`.

### Task 4 (controller): review toàn nhánh → sửa → `0.9.0+11` → PR → CI → merge → tag `v0.9.0` → tải APK release → `adb install -r` lên máy đang nối → mở app.
