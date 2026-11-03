# 🌙 Nghe chuyện — Design

**Mục tiêu (v0.7.0):** bé nghe truyện (video YouTube) ngay trong app với giới hạn do bố mẹ đặt (số truyện hoặc thời gian). Hết giới hạn → Elsa chúc ngủ ngon, về màn chính; muốn nghe tiếp phải qua cổng toán.

## Quyết định đã chốt
- Nguồn: YouTube phát **nhúng** trong app (`youtube_player_iframe`). Premium không áp dụng trong trình phát nhúng → có thể có quảng cáo; không phát nền (màn hình luôn sáng khi phát, `wakelock_plus`).
- Hai chế độ: 🎬 Xem video / 🌙 Chỉ nghe (video bị che bởi màn đêm, chỉ nghe tiếng).
- Danh sách: gói soạn sẵn `content/packs/stories.json` + bố mẹ dán link thêm trong khu bố mẹ; ẩn truyện có sẵn, xóa truyện tự thêm.
- Bé tự chọn truyện trong lưới; bố mẹ đặt chủ đề + giới hạn.
- Hết giờ giữa truyện: bố mẹ chọn mỗi phiên — *nghe hết truyện* (lố tối đa 10 phút) hoặc *dừng ngay* (nhỏ dần 5 s).
- Không tải luồng âm thanh YouTube ra ngoài trình phát chính thức (vi phạm điều khoản).

## Luồng
1. **Màn chính**: thêm nút 🌙 (phrase `game_story` "Nghe chuyện"). Bấm → `MathGateScreen`.
2. **Cổng toán**: phép cộng `a + b` với a, b ∈ [11, 49], tổng có nhớ (đơn vị a + đơn vị b ≥ 10). Bàn phím số 0–9 to, ⌫, ô đáp số tối đa 3 chữ số; nhập đủ số chữ số của đáp án → tự kiểm tra. Sai → rung nhẹ, đổi phép mới. ← về màn chính. Cổng không nói (dành cho bố mẹ). Không có trạng thái "đã mở khóa" lưu lại.
3. **Cài đặt phiên** (`StorySetupScreen`, dành cho bố mẹ, chữ thường):
   - Chủ đề (chọn nhiều, mặc định Tất cả): `fairy_vi` Cổ tích Việt Nam · `princess` Công chúa & Elsa · `english` Truyện tiếng Anh · `other` Khác. Chỉ hiện chủ đề có ≥1 truyện hiển thị.
   - Giới hạn: **Số truyện** 1–5 (mặc định 2) hoặc **Thời gian** 10/15/20/30/45/60 phút (mặc định 15).
   - Khi chọn thời gian: **Nghe hết truyện đang dở** (mặc định) / **Dừng ngay khi hết giờ**.
   - Chế độ: 🎬 Xem video / 🌙 Chỉ nghe (mặc định Chỉ nghe).
   - Lựa chọn lần trước được nhớ (DB) làm mặc định lần sau.
   - **Bắt đầu** → `StoryGridScreen` (thay thế màn cài đặt và cổng: back không quay lại cài đặt).
4. **Lưới truyện** (`StoryGridScreen`): nền đêm; dòng trên cùng "Còn 2 truyện" / "Còn 12 phút" (+ ⏳ biểu tượng); lưới 2 cột ảnh `https://i.ytimg.com/vi/<id>/hqdefault.jpg` + tên (2 dòng, cắt …); Elsa nói `story_pick` "Xoài chọn truyện muốn nghe nào!" khi vào lưới (mỗi lần quay lại lưới). Lọc: chủ đề đã chọn, không ẩn; chế độ thời gian + *nghe hết* → ẩn truyện có `durationSec > còn lại + 600` (truyện chưa rõ độ dài luôn hiện). Nếu lọc xong rỗng → kết thúc phiên. 🏠 / back → kết thúc phiên.
5. **Màn phát** (`StoryPlayerScreen`): trình phát YouTube (không controls YouTube, không fullscreen, `strictRelatedVideos`, không bàn phím, tự phát); lớp `AbsorbPointer` phủ kín video (chạm vào video không làm gì; điều hướng ra ngoài bị chặn). Nút của app: ⏸/▶ to, 🏠 (về lưới — không kết thúc phiên), thanh tiến độ chỉ xem. Chế độ Chỉ nghe: lớp phủ đục bầu trời đêm, Elsa, sao lấp lánh nhẹ, tên truyện, ⏸/▶. Wakelock bật khi ở màn phát.
   - Hết video (`ended`) → về lưới (hoặc kết thúc phiên nếu hết giới hạn).
   - Lỗi phát / video chặn nhúng → Elsa `story_error` "Truyện này chưa mở được, Xoài chọn truyện khác nha!" → về lưới; truyện đó ẩn khỏi lưới trong phiên này; không trừ lượt.
6. **Kết thúc phiên**: Elsa `story_bye` "Hết giờ nghe chuyện rồi, Xoài ngủ ngon nhé!" (màn đêm + Elsa, tối thiểu 2 s, không bấm được gì) → về màn chính (`popUntil` first). Không có cách tiếp tục ngoài qua cổng toán lại.
7. **Không có mạng** (kiểm tra khi vào lưới: tra DNS `www.youtube.com` thất bại trong 3 s) → `story_offline` "Cần có mạng để nghe chuyện nha!" → về màn chính.

## Quy tắc phiên (`StorySession`, logic thuần, đồng hồ tiêm vào)
- `StoryLimit.count(n)` hoặc `StoryLimit.time(Duration, StoryOverrun.finish|stopNow)`.
- Đồng hồ phiên: `Stopwatch`-like, chạy khi app ở foreground (lưới + phát + tạm dừng), dừng khi app vào nền (`AppLifecycleState` paused/hidden). Màn phát tạm dừng video khi vào nền.
- Lượt: truyện được tính "đã nghe" khi thời gian phát thực tế của nó ≥ 60 s (hoặc kết thúc tự nhiên). Rời truyện trước 60 s → không trừ lượt.
- Hết giới hạn khi: count — số truyện đã nghe ≥ n (kiểm tra khi rời/hết truyện; đang nghe truyện thứ n thì nghe hết); time + finish — đã hết giờ và không đang phát, hoặc đang phát nhưng đã lố 10 phút sau hạn; time + stopNow — đúng lúc hết giờ: nhỏ dần âm lượng 100 → 0 trong 5 s rồi dừng.
- Ở lưới, khi đã hết giờ → kết thúc ngay.
- Thoát app (process chết) → phiên mất.

## Quản lý truyện (khu bố mẹ → ListTile "📖 Truyện")
- `StoriesManageScreen`: danh sách theo chủ đề; mỗi dòng: ảnh nhỏ, tên, độ dài, nhãn "Có sẵn"/"Tự thêm"; công tắc hiện/ẩn (có sẵn) hoặc 🗑 xóa (tự thêm, có xác nhận).
- **Thêm truyện**: ô dán link → trích mã video (`youtube.com/watch?v=`, `youtu.be/`, `youtube.com/shorts/`, `m.youtube.com`, `youtube.com/embed/`, có/không tham số; mã 11 ký tự `[A-Za-z0-9_-]`). Lỗi định dạng → "Link không hợp lệ". Trùng → "Truyện đã có".
  - Lấy tên qua oEmbed `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=<id>&format=json` (dio, timeout 8 s); 401/403 → "Video này không cho phát trong app"; lỗi mạng → báo lỗi.
  - Xem thử: trình phát nhỏ phát video (có controls) → lấy độ dài khi sẵn sàng; lỗi phát → không cho lưu.
  - Chọn chủ đề (mặc định `fairy_vi`), sửa được tên → Lưu.
- Đặt lại tiến độ game **không** xóa truyện tự thêm / danh sách ẩn / lựa chọn cài đặt.

## Dữ liệu
- `content/packs/stories.json`: `{"pack":"stories","version":1,"items":[{"id":"yt:<videoId>","videoId":"...","title":"...","topic":"fairy_vi","durationSec":612}]}`; manifest + validator (id duy nhất = `yt:`+videoId, videoId đúng mẫu, topic thuộc 4 chủ đề, `durationSec` > 0, title không rỗng). Gói bắt buộc nhưng được phép rỗng.
- DB schema v4: bảng `user_stories(videoId PK, title, topic, durationSec nullable, addedAt)`, `hidden_stories(storyId PK)`, cột `profile.storySetup` (TEXT JSON, nullable). Migration từ v3 (và v1/v2) giữ dữ liệu.
- Danh sách soạn sẵn: 20–30 truyện (ưu tiên tiếng Việt cho bé ~5 tuổi, dài 5–20 phút, kênh truyện thiếu nhi, nội dung nhẹ nhàng), mỗi video kiểm tra oEmbed 200 + độ dài; ghi nguồn kênh trong `THIRD_PARTY_NOTICES` (chỉ là liên kết nhúng).

## Thành phần
- `lib/features/story/`: `story_models.dart` (`Story`, `StoryTopic`), `story_library.dart` (gộp + lọc), `story_session.dart`, `math_gate.dart` (generator + `MathGateScreen`), `story_setup_screen.dart`, `story_grid_screen.dart`, `story_player_screen.dart`, `story_player.dart` (interface `StoryPlayerController`: load, play, pause, setVolume, stream trạng thái {ready, playing, paused, ended, error}, position, duration; triển khai `YoutubeStoryPlayer`; `FakeStoryPlayer` cho test), `night_sky.dart`.
- `lib/features/parent/stories_manage_screen.dart`, `youtube_link.dart` (trích mã), `oembed_client.dart`.
- `lib/core/stories/story_store.dart` (DB) + `MemoryStoryStore`.
- Mạng: `ConnectivityProbe` interface (thật: `InternetAddress.lookup`; giả trong test).
- Phrases mới (vi, giọng Ngọc Huyền, có clip; phrase cố định nên thuộc kind `fixed` — coverage đã bắt buộc): `game_story`, `story_pick`, `story_error`, `story_bye`, `story_offline` (dùng `{name_vi}` thay "Xoài").

## Kiểm thử
- `StorySession`: count (nghe < 60 s không trừ; truyện thứ n nghe hết), time+finish (lố ≤ 10 phút, lọc lưới theo độ dài), time+stopNow (nhỏ dần rồi kết thúc), đồng hồ dừng khi vào nền.
- Math gate: phép luôn có nhớ, trong khoảng; đúng → mở; sai → phép mới.
- Link parser: các dạng link hợp lệ/không hợp lệ.
- Widget (với `FakeStoryPlayer`, `FakeConnectivity`, store bộ nhớ): luồng đầy đủ home → cổng → cài đặt → lưới → phát → hết → lưới → hết lượt → bye → home; lỗi video; offline; 🏠 ở lưới kết thúc phiên; chế độ chỉ nghe có lớp phủ; màn quản lý thêm/ẩn/xóa; vừa 360×640.
- Migration v3 → v4.
- `flutter analyze --no-fatal-infos` sạch; `flutter test` xanh; build APK.

## Ngoài phạm vi
Phát nền, chặn quảng cáo, đăng nhập YouTube, tải video offline, truyện tự tạo giọng (phương án B — để sau).
