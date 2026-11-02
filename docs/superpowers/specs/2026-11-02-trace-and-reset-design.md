# Tô chữ in hoa + Đặt lại dữ liệu — Thiết kế

**Ngày:** 2026-11-02 · **Phát hành:** v0.3.0 · Bổ sung cho `2026-11-02-xoai-ice-castle-design.md` §5.2 và §9.

## 1. Trò ✏️ Tô chữ (A–Z in hoa)

- **Một lượt:** 3 chữ, chọn bằng `QuestionPicker` theo khóa `trace_en_upper:X`, `maxNew: 3`.
- **Mỗi chữ:** Elsa nói *"Let's write A!"* (phrase `trace_prompt`, en, "Let's write {letter}!"). Chạm Elsa → nói lại.
- **Từng nét một:** nét hiện tại vẽ nét đứt phát sáng + chấm tròn đánh số ở điểm đầu + mũi tên chỉ hướng; nét đã xong vẽ liền màu băng đậm; nét chưa tới vẽ mờ.
- Bé tô bằng ngón tay; vệt tô hiện ngay ("phép băng"). Thả tay → chấm nét:
  - **Đạt** khi *độ phủ* ≥ 80% (điểm mẫu trên nét cách vệt tô ≤ 12% cạnh khung) **và** *độ chính xác* ≥ 70% (điểm của vệt tô cách nét ≤ 12%) — chặn tô nguệch ngoạc.
  - Đạt → nét chuyển màu, sang nét sau. Chưa đạt → vệt mờ đi, nhóm câu `try_again`, tô lại nét đó.
- **Xong chữ:** thẻ ví dụ (emoji/ảnh từ `letters_en.json`) hiện lên, Elsa nói `letter_example` ("A! A is for Apple!"), tối thiểu 0,8 s rồi sang chữ sau.
- **Kết quả chữ:** có nét nào chưa đạt ≥ 3 lần → `retry` (giữ nguyên mức thuộc), ngược lại `firstTry` (+1 mức, +1 ❄️). Lượt: +5 ❄️, tính nhiệm vụ ngày, phiên lưu `game: 'trace'`.
- 🏠 nói `go_home`; vuốt back cũng nói `go_home`; bị chặn khi đang ăn mừng chữ cuối/đang lưu (như trò 🐾).

### 1.1 Dữ liệu nét
`content/packs/letters_en.json`, mỗi chữ thêm `"strokes"`: danh sách nét; mỗi nét là danh sách đoạn nối tiếp:
- `{"line": [[x,y], [x,y], ...]}` — đường gấp khúc;
- `{"arc": [cx, cy, rx, ry, startDeg, sweepDeg]}` — cung elip; góc 0° = bên phải, góc dương = theo chiều kim đồng hồ trên màn hình (y hướng xuống).

Tọa độ chuẩn hóa 0–1 trong khung vuông. Validator: mọi chữ phải có ≥ 1 nét; tọa độ/tâm trong [0, 1]; `line` ≥ 2 điểm; `arc` đủ 6 số, `rx, ry > 0`, `sweep ≠ 0`. Tăng `version` của gói `letters_en` lên 2.

### 1.2 Giọng
Thêm `trace_prompt` vào `requiredPhraseIds`, `enumerateUtterances` thêm loại `trace` (26 câu); test đủ giọng bắt buộc cả `trace`. Tạo 26 clip bằng `tool/gen_voice.dart` (giọng Clementine).

### 1.3 Màn chính
Nút ✏️ mở `TraceScreen` (không còn "sắp có").

## 2. Đặt lại dữ liệu (khu bố mẹ)

- Mục đỏ **"Đặt lại dữ liệu game"** cuối danh sách. Chạm → hộp thoại *"Xóa toàn bộ tiến độ của Xoài? Không khôi phục được."* với **Hủy** / **Xóa** (đỏ).
- **Xóa:** bảng `item_stats`, `sessions`; `rewards` về mặc định (❄️ 0, lâu đài mốc 1, chuỗi ngày 0, nhiệm vụ ngày trống). **Giữ:** `profile` (tên, công tắc 🎈).
- Làm trong một transaction. Xong → làm mới trạng thái phần thưởng, quay về màn chính, Elsa chào lại.

## 3. Kiểm thử
- Unit: lấy mẫu nét (line/arc), chấm nét (đạt khi tô đúng; trượt khi tô lệch, tô nửa nét, tô nguệch ngoạc cả khung), phiên tô chữ (chuyển nét, đếm lần sai, kết quả), dựng lượt, validator nét, reset DB (xóa đúng bảng, giữ profile).
- Widget: lượt tô đầy đủ bằng cách "vẽ" theo nét mẫu → màn thưởng +8 ❄️ (3 + 5); vẽ lệch → `try_again`, nét không đổi; reset: Hủy không xóa, Xóa → ❄️ 0; vừa màn 360×640.
- Thử thật trên điện thoại sau khi cập nhật v0.3.0.
