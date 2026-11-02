# Lâu đài băng của Xoài

Game học tiếng Anh/tiếng Việt cho bé Xoài (Flutter, Android).

- Thiết kế: `docs/superpowers/specs/2026-11-02-xoai-ice-castle-design.md`
- Chạy test: `flutter test`
- Kiểm tra nội dung: `dart run tool/validate_content.dart`
- Sinh code DB sau khi sửa `lib/core/db/database.dart`: `dart run build_runner build --delete-conflicting-outputs`

## Phát hành bản mới

1. Tăng `version:` trong `pubspec.yaml`.
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. GitHub Actions build APK đã ký và tạo Release; app trên điện thoại báo chấm đỏ ở ổ khóa.

Keystore nằm ở `~/.xoai-keystore/` (không commit). Mất keystore thì không cập nhật đè được app đã cài.
