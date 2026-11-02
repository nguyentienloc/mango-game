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

## Giọng Vbee (HN – Ngọc Huyền + Heart)

Sau khi sửa nội dung (`content/phrases.json`, `content/packs/*`): `dart run tool/gen_voice.dart`
(cần `ffmpeg` có libopus). Tiếng Việt dùng giọng **HN – Ngọc Huyền** (`hn_female_ngochuyen_full_48k-fhg`), tiếng Anh dùng **Heart** (`af_heart`), tốc độ 0.9.
Khóa Vbee nằm ở `~/.config/xoai/vbee.env` (hai dòng `VBEE_APP_ID=…` và `VBEE_TOKEN=…`, hoặc biến môi trường cùng tên), không commit.
Mỗi đoạn một ngôn ngữ được đọc riêng (lưu đệm ở `build/voice-parts/`), các đoạn của một câu nối nhau cách 0,25 s. Tối đa 3 câu chạy song song; script tự chờ khi bị giới hạn đồng thời (HTTP 429) và chạy tiếp được.
**Chi phí:** Vbee tính credit theo số ký tự gửi đi; `--dry-run` in số ký tự cần đọc (bỏ qua phần đã lưu đệm). Hết credit/gói thì script dừng (mã thoát 2) và in số câu còn thiếu.
Tùy chọn: `--limit N` (chỉ tạo N câu), `--only TEXT` (chỉ câu có khóa chứa TEXT), `--dry-run` (không gọi mạng). Đổi giọng/tốc độ thì `index.json` bị coi là hết hạn: mọi clip được tạo lại.
`--prune` xóa clip không còn dùng. Test `test/content/voice_coverage_test.dart` báo đỏ nếu thiếu giọng.
