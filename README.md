# Lâu đài băng của Xoài

Game học tiếng Anh/tiếng Việt cho bé Xoài (Flutter, Android).

- Thiết kế: `docs/superpowers/specs/2026-11-02-xoai-ice-castle-design.md`
- Chạy test: `flutter test`
- Kiểm tra nội dung: `dart run tool/validate_content.dart`
- Sinh code DB sau khi sửa `lib/core/db/database.dart`: `dart run build_runner build --delete-conflicting-outputs`

## Phát hành bản mới

1. Tăng `version:` trong `pubspec.yaml` cho khớp với tag (nên giữ đồng bộ, nhưng **tag mới là nguồn chính**).
2. `git tag vX.Y.Z && git push origin vX.Y.Z` (tag phải đúng dạng số `X.Y.Z`, nếu không job báo lỗi).
3. GitHub Actions build APK với `versionName = X.Y.Z` và `versionCode = X*10000 + Y*100 + Z` (lấy từ tag), kiểm tra APK đã ký bằng keystore release (`apksigner verify`), rồi tạo Release; app trên điện thoại báo chấm đỏ ở ổ khóa.

Keystore nằm ở `~/.xoai-keystore/` (không commit). Mất keystore thì không cập nhật đè được app đã cài.

## Giọng Leda (Gemini TTS)

Sau khi sửa nội dung (`content/phrases.json`, `content/packs/*`): `dart run tool/gen_voice.dart`
(key ở `~/.config/xoai/gemini_api_key`, không commit). Gói miễn phí: 3 câu/phút (và có thể giới hạn theo ngày); script tự đợi giới hạn theo phút và chạy tiếp được.
`--prune` xóa clip không còn dùng. Test `test/content/voice_coverage_test.dart` báo đỏ nếu thiếu giọng.
