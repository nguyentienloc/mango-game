# Tốc độ đọc chỉnh được + clip theo từng đoạn — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** v0.3.1 — bố mẹ chỉnh tốc độ đọc tiếng Anh và tiếng Việt riêng (0,6×–1,3×) trong khu bố mẹ; áp dụng lúc phát cho cả clip và giọng máy; không cần tạo lại giọng.

**Architecture:** Clip đổi từ "một file cho cả câu" sang **một file cho mỗi đoạn** (`UtterancePart`, khóa `lang|text`), sinh lại từ cache MP3 có sẵn trong `build/voice-parts/` (không gọi Vbee). `VoiceService` phát lần lượt từng đoạn, đoạn nào có clip thì phát clip với tốc độ của ngôn ngữ đó (`just_audio` `setSpeed`, giữ cao độ), không có thì giọng máy với tốc độ tương ứng. Tốc độ lưu trong bảng `profile` (schema v3).

**Tech Stack:** Flutter 3.47.9, just_audio, flutter_tts, drift, Riverpod 3.4.3.

## Global Constraints
- Nhánh `feat/voice-speed`. Phát hành `0.3.1+4`, tag `v0.3.1`.
- Khóa clip = khóa đoạn `lang|text` (như `UtterancePart` trong `Utterance.key`). File `content/audio/<sha1(partKey) 16 hex>.ogg`, Opus mono 32 kbps. `index.json` có `"granularity": "part"`.
- Khoảng lặng giữa các đoạn khi phát: 200 ms (thay cho 0,25 s ghép sẵn trước đây).
- Tốc độ: `enSpeed` mặc định **0.85**, `viSpeed` mặc định **1.0**; khoảng cho phép 0.6–1.3, bước 0.05.
- Giọng máy: `setSpeechRate(0.42 × tốc độ)` theo ngôn ngữ của đoạn.
- Giữ nguyên: bộ đếm generation (câu mới/stop cắt các đoạn còn lại, kể cả đang ở khoảng lặng), circuit breaker clip (2 lỗi liên tiếp → chỉ dùng giọng máy), timeout clip.
- Không gọi Vbee; nếu cache thiếu đoạn nào, công cụ dừng và báo (không tự gọi API) trừ khi chạy với `--allow-api`.
- `flutter analyze --no-fatal-infos` sạch lỗi/cảnh báo; `flutter test` xanh trước mỗi commit.

### Task 1: Clip theo từng đoạn

**Files:** `tool/gen_voice.dart`, `tool/src/voice_gen.dart`, `lib/core/voice/clip_library.dart`, `lib/core/voice/voice_service.dart`, `content/audio/*`, tests (`test/core/voice/*`, `test/content/voice_coverage_test.dart`, `test/tool/*`).

- [ ] `enumerateUtterances` giữ nguyên. Công cụ tạo giọng: tập clip cần có = **mọi đoạn khác nhau** của mọi câu (bỏ trùng theo khóa đoạn). Với mỗi đoạn: lấy MP3 từ cache part (khóa cache hiện có `lang|text|voice|speed`); không có → nếu `--allow-api` thì tạo qua Vbee như cũ, ngược lại ghi vào danh sách thiếu và cuối cùng thoát mã 2 kèm số đoạn thiếu. Mã hóa MP3 → Opus (không ghép, không chèn lặng). Ghi `index.json` `{provider, voices, speed, granularity: "part", clips: {partKey: file}}`. Index cũ (không có `granularity: "part"`) coi là hết hạn; `--prune` xóa file cũ.
- [ ] `ClipLibrary.assetFor(UtterancePart part)` (tra theo `'${part.lang}|${part.text}'`). Bỏ tra theo cả câu.
- [ ] `VoiceService._play(Utterance u)`: với mỗi đoạn theo thứ tự: kiểm tra generation; nếu không phải đoạn đầu → chờ 200 ms (rồi kiểm tra generation lại); có clip và breaker cho phép → phát clip (timeout như cũ; lỗi → tăng breaker, đọc đoạn đó bằng giọng máy); không có clip → giọng máy đọc đoạn đó. (Task 2 thêm tốc độ.)
- [ ] Test (viết trước, thấy fail): ClipLibrary tra theo đoạn; câu 2 đoạn chỉ có clip cho một đoạn → đoạn đó phát clip, đoạn kia giọng máy, đúng thứ tự; `stop()` trong khoảng lặng giữa hai đoạn → đoạn hai không phát; breaker vẫn hoạt động. Coverage test: mọi đoạn của câu loại `fixed`, `vocab`, `trace` có clip + file tồn tại. Parity test: chuyển sang kiểm tra mọi đoạn đều được phát bằng clip.
- [ ] Chạy `dart run tool/gen_voice.dart --prune` (từ cache, không gọi API) → kiểm tra số file ≈ số đoạn khác nhau, `dart run tool/validate_content.dart` sạch. Commit `feat: per-part voice clips`.

### Task 2: Tốc độ đọc trong khu bố mẹ

**Files:** `lib/core/db/database.dart` (+ `.g.dart`), `lib/core/profile/profile_store.dart`, `lib/app/` (provider/controller tốc độ), `lib/core/voice/clip_player.dart`, `lib/core/voice/tts_engine.dart`, `lib/core/voice/flutter_tts_engine.dart`, `lib/core/voice/voice_service.dart`, `lib/main.dart`, `lib/features/parent/parent_screen.dart`, `test/support/*`, tests.

- [ ] Schema v3: `profile.enSpeed` (real, default 0.85), `profile.viSpeed` (real, default 1.0); `onUpgrade`: `from < 2` thêm `showFindLetter` (giữ), `from < 3` thêm hai cột mới. Test migration v2 → v3 bằng DDL v2 thật (lấy từ code sinh hiện tại trước khi sửa) giữ nguyên dữ liệu, giá trị mặc định đúng; và v1 → v3.
- [ ] `ProfileStore`: `Future<VoiceSpeeds> voiceSpeeds()` / `Future<void> setVoiceSpeeds(VoiceSpeeds)`; `class VoiceSpeeds { double en; double vi; double forLang(String lang); }` (giá trị ngoài 0.6–1.3 thì kẹp lại). `MemoryProfileStore` cập nhật.
- [ ] `ClipPlayer.play(String asset, {double speed = 1.0})` — `JustAudioClipPlayer` gọi `setSpeed(speed)` trước khi phát. `TtsEngine.speak(text, {lang, double speed = 1.0})` — `FlutterTtsEngine` đặt `setSpeechRate(0.42 * speed)` khi tốc độ đổi. Fakes ghi lại `speed`.
- [ ] `VoiceService`: thuộc tính `VoiceSpeeds speeds` (đặt được lúc chạy); mỗi đoạn phát với `speeds.forLang(part.lang)` cho cả clip và giọng máy. `main.dart` nạp tốc độ từ DB lúc khởi động và truyền vào.
- [ ] Controller `voiceSpeedsProvider` (AsyncNotifier) đọc/ghi qua `ProfileStore`; khi đặt → lưu DB và cập nhật `voiceProvider.speeds` ngay.
- [ ] `ParentScreen`: hai `ListTile` với `Slider` (min 0.6, max 1.3, divisions 14, nhãn "0,85×"): **"Tốc độ đọc tiếng Anh"** và **"Tốc độ đọc tiếng Việt"**; `onChangeEnd` → lưu + đọc câu mẫu (en: `vocab_prompt` với từ `lion`; vi: `greet_vi`). Nút nhỏ "Mặc định" đưa về 0.85 / 1.0.
- [ ] Test (trước): fake player/TTS nhận đúng tốc độ theo ngôn ngữ từng đoạn (câu song ngữ dùng hai tốc độ khác nhau); kẹp giá trị; slider lưu và đọc câu mẫu; migration.
- [ ] `flutter test`, `flutter analyze --no-fatal-infos`, `flutter build apk --debug`. Commit `feat: adjustable voice speed per language`.

### Task 3 (controller): review toàn nhánh → sửa → thử trên máy → `0.3.1+4` → PR → CI → merge → tag `v0.3.1`.
