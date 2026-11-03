# 🌙 Nghe chuyện — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** v0.7.0 — nút 🌙 trên màn chính → cổng toán → bố mẹ đặt chủ đề + giới hạn → bé chọn truyện (video YouTube nhúng, chế độ xem hoặc chỉ nghe) → hết giới hạn thì Elsa chúc ngủ ngon và về màn chính.

**Spec:** `docs/superpowers/specs/2026-11-03-story-time-design.md` (đọc trước — mọi quy tắc trong spec là bắt buộc).

**Architecture:** Logic thuần (`StorySession`, `MathProblem`, `parseYoutubeId`) tách khỏi UI và được test đơn vị. Trình phát YouTube nằm sau interface `StoryPlayerController` (bản thật `youtube_player_iframe`, bản giả cho widget test vì WebView không chạy trong `flutter test`). Mạng, giữ màn hình sáng, oEmbed đều qua interface + provider để test thay được. DB v4 lưu truyện tự thêm, truyện ẩn, lựa chọn cài đặt.

**Tech Stack:** Flutter 3.47.9, Riverpod 3.4.3, drift, `youtube_player_iframe` ^6.0.2, `wakelock_plus` ^1.8.2, dio.

## Global Constraints
- Nhánh `feat/story` (đã có commit spec). Phát hành `0.7.0+8`, tag `v0.7.0`.
- Chủ đề (id → nhãn): `fairy_vi` Cổ tích Việt Nam · `princess` Công chúa & Elsa · `english` Truyện tiếng Anh · `other` Khác.
- Giới hạn: số truyện 1–5 (mặc định 2) / thời gian 10, 15, 20, 30, 45, 60 phút (mặc định 15); overrun `finish` (mặc định, lố tối đa 10 phút) / `stopNow` (nhỏ dần 5 s); chế độ `listen` (mặc định) / `watch`.
- Truyện được tính đã nghe khi phát thực ≥ 60 s hoặc kết thúc tự nhiên.
- Đồng hồ phiên chạy khi app ở foreground (lưới, phát, tạm dừng); dừng khi app vào nền.
- Phrases mới (vi, `group` "story"): `game_story` "Nghe chuyện" · `story_pick` "Xoài chọn truyện muốn nghe nào!" → dùng `{name_vi}`: "{name_vi} chọn truyện muốn nghe nào!" · `story_error` "Truyện này chưa mở được, {name_vi} chọn truyện khác nha!" · `story_bye` "Hết giờ nghe chuyện rồi, {name_vi} ngủ ngon nhé!" · `story_offline` "Cần có mạng để nghe chuyện nha!". Tất cả là phrase cố định (không biến item) → thuộc kind `fixed` của `enumerateUtterances`, coverage test đã bắt buộc có clip; thêm cả 5 vào `requiredPhraseIds`.
- Không đọc/in/commit credentials (`~/.config/xoai/*`); `tool/gen_voice.dart` tự đọc.
- Đặt lại tiến độ (`DriftProgressResetter`) không đụng bảng truyện / cột `storySetup`.
- Mọi chạm điều hướng phía bé có tiếng; mọi màn vừa 360×640; `flutter analyze --no-fatal-infos` sạch lỗi/cảnh báo; `flutter test` xanh trước mỗi commit.

---

### Task 1: Logic thuần + gói nội dung
**Files:** Create `lib/features/story/story_models.dart`, `story_session.dart`, `math_gate_logic.dart`, `lib/features/story/youtube_link.dart`, `content/packs/stories.json`; Modify `content/manifest.json`, `lib/core/content/models.dart` (`ContentBundle.stories`), `lib/core/content/content_validator.dart`, `test/support/content_fixture.dart`; Tests `test/features/story/story_session_test.dart`, `math_gate_logic_test.dart`, `youtube_link_test.dart`, `test/core/content/*` (validator).

**Produces:**
```dart
enum StoryTopic { fairyVi('fairy_vi', 'Cổ tích Việt Nam'), princess('princess', 'Công chúa & Elsa'), english('english', 'Truyện tiếng Anh'), other('other', 'Khác');
  const StoryTopic(this.id, this.label); final String id; final String label;
  static StoryTopic? fromId(String id); }
@immutable class Story { const Story({required this.videoId, required this.title, required this.topic, this.duration, this.userAdded = false});
  final String videoId; final String title; final StoryTopic topic; final Duration? duration; final bool userAdded;
  String get id => 'yt:$videoId'; String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
  factory Story.fromJson(Map<String, dynamic> j); }  // pack item: {id, videoId, title, topic, durationSec}
enum StoryOverrun { finish, stopNow }
enum StoryViewMode { listen, watch }
sealed class StoryLimit { const StoryLimit(); }
class CountLimit extends StoryLimit { const CountLimit(this.stories); final int stories; }
class TimeLimit extends StoryLimit { const TimeLimit(this.duration, this.overrun); final Duration duration; final StoryOverrun overrun; }
@immutable class StorySetup { const StorySetup({this.topics = const {}, this.limit = const CountLimit(2), this.mode = StoryViewMode.listen});
  final Set<StoryTopic> topics; /* empty = all */ final StoryLimit limit; final StoryViewMode mode;
  Map<String, dynamic> toJson(); static StorySetup fromJson(Map<String, dynamic> j); /* unknown/invalid → defaults, values clamped to allowed lists */ }
const storyCountOptions = [1, 2, 3, 4, 5];
const storyMinuteOptions = [10, 15, 20, 30, 45, 60];
const storyOverrunCap = Duration(minutes: 10);
const storyCountsAfter = Duration(seconds: 60);
const storyFadeOut = Duration(seconds: 5);

class StorySession {
  StorySession(this.limit);
  final StoryLimit limit;
  Duration get elapsed; int get listened; Story? get current; Duration get currentPlayed;
  int? get storiesLeft;      // CountLimit: stories - listened (≥0); else null
  Duration? get timeLeft;    // TimeLimit: max(0, duration - elapsed); else null
  void advance(Duration dt, {required bool playing}); // foreground time; playing also adds to currentPlayed
  void startStory(Story s);  // asserts no current
  void finishStory({required bool completed}); // counts if completed || currentPlayed >= storyCountsAfter; clears current
  void abandonStory();       // error path: never counts
  bool canPick(Story s);     // TimeLimit+finish: s.duration == null || s.duration! <= timeLeft! + storyOverrunCap; else true
  bool get limitReached;     // Count: listened >= stories; Time: elapsed >= duration
  bool get mustStopPlayback; // Time+stopNow: elapsed >= duration; Time+finish: elapsed >= duration + storyOverrunCap; Count: false
}

class MathProblem { const MathProblem(this.a, this.b); final int a, b; int get answer => a + b;
  static MathProblem random(Random r); } // a, b in 11..49, (a%10)+(b%10) >= 10

String? parseYoutubeId(String input); // watch?v=, youtu.be/, shorts/, embed/, live/, m. & music. hosts, extra params, bare 11-char id; trims; else null
```
- [ ] Viết test trước cho cả ba file logic (thấy fail): session — count (bỏ truyện sau 59 s không trừ, sau 60 s trừ, `completed` luôn trừ, truyện thứ n vẫn chạy tới khi `finishStory`), time+finish (`canPick` theo độ dài, `mustStopPlayback` chỉ sau hạn + 10 phút, `limitReached` khi hết giờ), time+stopNow, `advance(playing:false)` không cộng `currentPlayed`, `abandonStory` không trừ; math — 2000 seed đều trong khoảng và có nhớ; link — ≥ 10 dạng hợp lệ, ≥ 6 dạng sai (domain khác, id 10 ký tự, rỗng, `youtube.com/channel/...`).
- [ ] Cài đặt cho pass. `StorySetup.fromJson` chịu được JSON hỏng (trả mặc định).
- [ ] Gói `content/packs/stories.json` `{"pack":"stories","version":1,"items":[]}` (Task 2 điền truyện), manifest `"stories": 1`. `ContentBundle.stories` (`List<Story>`, mặc định `const []`). Lưu ý `fromFiles` lặp `packs` chỉ lấy tên `vocab_*` — giữ nguyên.
- [ ] Validator: gói `stories` bắt buộc (được rỗng); mỗi item: `videoId` khớp `^[A-Za-z0-9_-]{11}$`, `id == 'yt:'+videoId`, id duy nhất, `title` không rỗng, `topic` thuộc 4 id, `durationSec` int > 0. Test lỗi cho từng luật. Cập nhật content fixture của test.
- [ ] `flutter test`, analyze, `dart run tool/validate_content.dart`. Commit `feat: story session logic, math gate and story pack`.

### Task 2: Lưu trữ + thư viện + danh sách truyện soạn sẵn
**Files:** Modify `lib/core/db/database.dart` (+ `database.g.dart` qua `dart run build_runner build --delete-conflicting-outputs`), Create `lib/core/stories/story_store.dart`, `lib/features/story/story_library.dart`, `lib/features/story/oembed_client.dart`, Modify `lib/app/providers.dart`, `test/support/fakes.dart`, `test/support/test_app.dart`, `content/packs/stories.json`, `THIRD_PARTY_NOTICES`; Tests `test/core/db/*migration*` (theo khuôn test migration v2→v3 hiện có), `test/core/stories/story_store_test.dart`, `test/features/story/story_library_test.dart`, `oembed_client_test.dart`.

**Consumes:** `Story`, `StoryTopic`, `StorySetup` (Task 1).
**Produces:**
```dart
abstract interface class StoryStore {
  Future<List<Story>> userStories();            // userAdded: true, ordered by addedAt
  Future<void> addUserStory(Story s);           // upsert by videoId
  Future<void> deleteUserStory(String videoId);
  Future<Set<String>> hiddenIds();              // Story.id values
  Future<void> setHidden(String storyId, bool hidden);
  Future<StorySetup> lastSetup();               // defaults if none / bad JSON
  Future<void> saveSetup(StorySetup s);
}
class DriftStoryStore implements StoryStore { DriftStoryStore(AppDatabase db); }
class MemoryStoryStore implements StoryStore { /* in lib/core/stories/story_store.dart, used by tests */ }

class StoryLibrary {
  StoryLibrary({required List<Story> bundled, required List<Story> user, required Set<String> hidden});
  List<Story> get all;      // bundled then user; a user story with the same videoId as a bundled one is dropped
  List<Story> visible({Set<StoryTopic> topics = const {}}); // not hidden, topic filter (empty = all)
  Set<StoryTopic> get topicsWithStories; // topics having ≥1 visible story
  bool isHidden(Story s);
}
final storyStoreProvider = Provider<StoryStore>((ref) => DriftStoryStore(ref.watch(databaseProvider)));
/// Reloads after the parent edits; screens `ref.invalidate(storyLibraryProvider)`.
final storyLibraryProvider = FutureProvider<StoryLibrary>(...); // contentProvider.stories + store

sealed class OEmbedResult {}
class OEmbedOk extends OEmbedResult { OEmbedOk(this.title); final String title; }
class OEmbedNotEmbeddable extends OEmbedResult {}  // HTTP 401 / 403
class OEmbedNotFound extends OEmbedResult {}       // 404 / 400
class OEmbedFailed extends OEmbedResult {}         // network / other
class OEmbedClient { OEmbedClient(Dio dio); Future<OEmbedResult> fetch(String videoId); } // GET https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=<id>&format=json, 8 s timeouts, validateStatus: (_) => true
final oembedClientProvider = Provider<OEmbedClient>(...);
```
- [ ] Schema v4: bảng `UserStories(videoId TEXT PK, title, topic, durationSec INT nullable, addedAt DATETIME)`, `HiddenStories(storyId TEXT PK)`, cột `profile.storySetup` TEXT nullable. `onUpgrade`: giữ các bước cũ, `from < 4` → `createTable` hai bảng + `addColumn`. Test migration v3 → v4 bằng DDL v3 thật (chép từ `database.g.dart` trước khi sửa) giữ dữ liệu; và v1 → v4. Test `DriftProgressResetter` không xóa truyện/ẩn/setup.
- [ ] `DriftStoryStore`, `MemoryStoryStore` + test (thêm, upsert, xóa, ẩn/hiện, setup lưu/đọc, setup JSON hỏng → mặc định). `test_app.dart` nhận `StoryStore? stories` (mặc định `MemoryStoryStore()`).
- [ ] `StoryLibrary` + test (trùng videoId, ẩn, lọc chủ đề, `topicsWithStories`). `OEmbedClient` + test với Dio adapter giả (200 → title, 401/403, 404, lỗi mạng).
- [ ] **Danh sách soạn sẵn** (20–30 truyện): tìm trên web video YouTube cho bé ~5 tuổi, dài 5–20 phút, kênh truyện thiếu nhi, nội dung nhẹ nhàng, không bạo lực/kinh dị: ~12 `fairy_vi` (Tấm Cám, Sọ Dừa, Thánh Gióng, Sự tích dưa hấu, Cây tre trăm đốt, Ăn khế trả vàng, Sự tích trầu cau, Con cóc là cậu ông trời, Cô bé quàng khăn đỏ bản Việt...), ~8 `princess` (công chúa / Elsa / Frozen kể chuyện tiếng Việt), ~6 `english` (bedtime stories tiếng Anh đơn giản). Với từng ứng viên: `curl -s -o /dev/null -w '%{http_code}' 'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=<id>&format=json'` phải 200 (lấy `title`, `author_name` từ body); độ dài lấy từ trang xem (`curl -sL 'https://www.youtube.com/watch?v=<id>' | grep -o '"lengthSeconds":"[0-9]*"' | head -1`) hoặc `yt-dlp --print duration` nếu có (không tải video). Bỏ video 401/403, < 3 phút hoặc > 30 phút. Rút gọn `title` cho dễ đọc (bỏ hashtag/tên kênh, ≤ 50 ký tự). Ghi `THIRD_PARTY_NOTICES` mục "Stories (YouTube embeds)": tên kênh + link từng video. Validate.
- [ ] `flutter test`, analyze, validate. Commit `feat: story storage, library and starter list`.

### Task 3: Trình phát + màn lưới / phát / kết thúc
**Files:** `pubspec.yaml` (`youtube_player_iframe`, `wakelock_plus`), Create `lib/features/story/story_player.dart`, `youtube_story_player.dart`, `story_run.dart`, `story_grid_screen.dart`, `story_player_screen.dart`, `story_end_screen.dart`, `night_sky.dart`, `lib/core/net/connectivity_probe.dart`, `lib/core/screen/screen_awake.dart`; Modify `lib/app/providers.dart`, `test/support/fakes.dart`, `test/support/test_app.dart`, `content/phrases.json` (+manifest bump, `requiredPhraseIds`), `content/audio/*`; Tests `test/features/story/story_run_test.dart`, `story_screens_test.dart`.

**Consumes:** Task 1 + Task 2 types, `voiceProvider`.
**Produces:**
```dart
enum StoryPlayerState { loading, playing, paused, ended, error }
abstract interface class StoryPlayerController {
  Stream<StoryPlayerState> get states;
  Future<Duration?> duration();            // null until known
  Future<void> load(String videoId);       // autoplay
  Future<void> play(); Future<void> pause();
  Future<void> setVolume(int percent);     // 0..100
  Widget buildView();                      // the video surface (no touch)
  void dispose();
}
typedef StoryPlayerFactory = StoryPlayerController Function({required bool controls});
final storyPlayerFactoryProvider = Provider<StoryPlayerFactory>((ref) => YoutubeStoryPlayer.new);
class FakeStoryPlayer implements StoryPlayerController { /* test/support/fakes.dart: emit(StoryPlayerState), loaded ids, volumes, playing flag */ }

abstract interface class ConnectivityProbe { Future<bool> online(); } // real: InternetAddress.lookup('www.youtube.com') with 3 s timeout
final connectivityProbeProvider = Provider<ConnectivityProbe>(...);
abstract interface class ScreenAwake { Future<void> enable(); Future<void> disable(); } // real: WakelockPlus
final screenAwakeProvider = Provider<ScreenAwake>(...);

/// Owns the StorySession for one sitting: 1 s Timer.periodic → session.advance(1 s, playing: isPlaying)
/// only while the app lifecycle is resumed (WidgetsBindingObserver); notifies listeners each tick.
class StoryRun extends ChangeNotifier with WidgetsBindingObserver {
  StoryRun({required this.setup, required this.library});
  final StorySetup setup; final StoryLibrary library; late final StorySession session;
  bool isPlaying; // set by the player screen from player states
  Set<String> failedThisRun; // story ids that errored; hidden from the grid
  List<Story> get pickable; // library.visible(topics) minus failed, filtered by session.canPick
  bool get shouldEnd;       // session.limitReached && session.current == null, or pickable.isEmpty && current == null
  @override void dispose();
}
class StoryGridScreen extends ConsumerStatefulWidget { const StoryGridScreen({super.key, required this.run}); final StoryRun run; }
class StoryPlayerScreen extends ConsumerStatefulWidget { const StoryPlayerScreen({super.key, required this.run, required this.story}); }
enum StoryEndReason { finished, offline }
class StoryEndScreen extends ConsumerStatefulWidget { const StoryEndScreen({super.key, required this.reason}); }
```
- [ ] Đọc API `youtube_player_iframe` bản cài (`~/.pub-cache/hosted/pub.dev/youtube_player_iframe-*/lib`): `YoutubePlayerController(params: YoutubePlayerParams(showControls:, showFullscreenButton: false, strictRelatedVideos: true, enableCaption: false, pointerEvents: ...))`, `loadVideoById`, `playVideo`/`pauseVideo`, `setVolume`, `duration`, `stream`/`listen` (`playerState`, `error`), widget `YoutubePlayer(controller:)`. Ghi tóm tắt vào report. `YoutubeStoryPlayer` ánh xạ trạng thái; lỗi (`YoutubeError` khác `none`, kể cả 101/150 chặn nhúng) → `error`; nếu sau 20 s vẫn `loading` → `error`. Chặn điều hướng ra ngoài (nếu gói có `onWebResourceError`/`NavigationDelegate` hoặc `url_launcher` cho link ngoài — vô hiệu hóa: không mở app/trình duyệt khác).
- [ ] Android: kiểm tra `INTERNET` trong `AndroidManifest.xml` (đã có cho cập nhật); `minSdk` đủ cho `webview_flutter_android`.
- [ ] Test `StoryRun` trước (fake_async): tick chỉ khi resumed; `isPlaying` cộng thời gian truyện; `pickable` lọc; `shouldEnd`.
- [ ] `StoryGridScreen`: `NightSky` nền; dòng "Còn N truyện" / "Còn M phút" (làm tròn lên; `Key('story-remaining')`); `GridView` 2 cột thẻ (`Key('story-<videoId>')`, `Image.network` thumbnail có `errorBuilder` → ô màu + 📖, tên 2 dòng); vào/quay lại lưới → `say('story_pick')`; lần đầu vào lưới kiểm tra mạng → offline thì `pushReplacement(StoryEndScreen(offline))`; `shouldEnd` → `pushReplacement(StoryEndScreen(finished))` (kiểm tra khi vào, khi quay về từ màn phát, và mỗi tick); 🏠 / back → kết thúc (`StoryEndScreen(finished)`); bấm thẻ → `voice.stop()`, `session.startStory`, push `StoryPlayerScreen`, chặn bấm đúp.
- [ ] `StoryPlayerScreen`: `factory(controls: false)`; `load` ngay; `screenAwake.enable()` (disable khi dispose); Stack: `buildView()` trong `IgnorePointer` + lớp `AbsorbPointer` trong suốt phủ kín; chế độ `listen` → lớp phủ đục `NightSky` + Elsa (`CharacterView`) + tên truyện (`Key('story-listen-cover')`); hàng nút: 🏠 (`Key('story-home')` → `finishStory(completed:false)`, pop về lưới), ⏸/▶ (`Key('story-playpause')`). Trạng thái `playing` ↔ `run.isPlaying`. `ended` → `finishStory(completed:true)`, pop. `error` → `abandonStory`, thêm vào `failedThisRun`, `say('story_error')` (chờ tối đa 5 s), pop. Back gesture = 🏠. App vào nền → `pause()`; quay lại không tự phát (bé bấm ▶). Mỗi tick: `session.mustStopPlayback` → time+stopNow: giảm âm lượng 100→0 trong `storyFadeOut` (10 bước), `pause`, `finishStory(completed:true)`, pop; time+finish (lố 10 phút): như trên.
- [ ] `StoryEndScreen`: `NightSky` + Elsa; `say('story_bye')` hoặc `say('story_offline')`; sau khi câu xong và tối thiểu 2 s → `Navigator.popUntil((r) => r.isFirst)`; không có nút; `PopScope(canPop: false)`.
- [ ] Phrases (Global Constraints) vào `content/phrases.json` (manifest bump) + `requiredPhraseIds`; tạo giọng `dart run tool/gen_voice.dart --dry-run` → `--allow-api` → `--prune`; báo số đoạn mới.
- [ ] Widget test (FakeStoryPlayer, fake probe, fake awake, MemoryStoryStore, library ≥ 4 truyện): count=2 — chọn truyện → `ended` → lưới "Còn 1 truyện" → truyện 2 `ended` → màn kết thúc nói "Hết giờ nghe chuyện rồi, Xoài ngủ ngon nhé!" → về route đầu; bỏ truyện sau 30 s không trừ lượt; `error` → nói `story_error`, truyện biến khỏi lưới, không trừ; offline → `story_offline` → về đầu; 🏠 ở lưới → kết thúc; time 10 phút + stopNow → pump 10 phút khi đang phát → âm lượng giảm về 0 → kết thúc; time+finish → hết giờ khi đang phát vẫn phát tiếp, `ended` → kết thúc; chế độ listen có `story-listen-cover`, watch không có; vừa 360×640.
- [ ] `flutter test`, analyze, validate, `flutter build apk --debug`. Commit `feat: story player, grid and end screens`.

### Task 4: Cổng toán, cài đặt phiên, màn chính, quản lý truyện
**Files:** Create `lib/features/story/math_gate_screen.dart`, `story_setup_screen.dart`, `lib/features/parent/stories_manage_screen.dart`, `add_story_sheet.dart`; Modify `lib/features/home/home_screen.dart`, `lib/features/parent/parent_screen.dart`; Tests `test/features/story/math_gate_screen_test.dart`, `story_setup_screen_test.dart`, `test/features/parent/stories_manage_screen_test.dart`, home tests.

**Consumes:** mọi thứ ở Task 1–3.
**Produces:** `MathGateScreen({required WidgetBuilder onPassed})` (đúng → `pushReplacement(onPassed)`), `StorySetupScreen()`, `StoriesManageScreen()`.
- [ ] `MathGateScreen`: chữ "Bố mẹ giải phép tính để mở nhé" + `"$a + $b = ?"` (`Key('gate-problem')`); ô đáp số; bàn phím 3×4 (`Key('gate-key-<d>')`, `Key('gate-back')` ⌫); đủ số chữ số của đáp án → kiểm tra; sai → `HapticFeedback.mediumImpact`, chữ đỏ 0,6 s, phép mới (`MathProblem.random(ref.read(randomProvider))`); AppBar ← về màn chính. Không nói.
- [ ] `StorySetupScreen` (chữ cho bố mẹ, theme sáng như `ParentScreen`): `FilterChip` chủ đề (chỉ `topicsWithStories`; "Tất cả" = bỏ chọn hết), `SegmentedButton` Số truyện / Thời gian, `ChoiceChip` các giá trị, khi Thời gian: `RadioListTile` Nghe hết truyện đang dở / Dừng ngay khi hết giờ, `SegmentedButton` 🌙 Chỉ nghe / 🎬 Xem video, nút **Bắt đầu** (`Key('story-start')`) → `saveSetup` → `pushReplacement(StoryGridScreen(run: StoryRun(...)))`. Nạp `lastSetup()` làm giá trị đầu (bỏ chủ đề không còn truyện). Thư viện rỗng → chữ "Chưa có truyện. Vào khu bố mẹ → Truyện để thêm." và nút Bắt đầu tắt. `StoryRun` do màn lưới sở hữu và dispose.
- [ ] Màn chính: thêm `_GameEntry('🌙', 'game_story', (_) => MathGateScreen(onPassed: (_) => const StorySetupScreen()))` cuối danh sách; kiểm tra 6 nút vừa 360×640 (giảm `BigButton` size về 80 nếu tràn — chỉ ở home).
- [ ] `ParentScreen`: `ListTile` "📖 Truyện" (`Key('parent-stories')`) → `StoriesManageScreen`.
- [ ] `StoriesManageScreen`: danh sách nhóm theo chủ đề; dòng: thumbnail 64×36, tên, độ dài `m:ss` hoặc "—", nhãn Có sẵn/Tự thêm; có sẵn → `Switch` hiện/ẩn (`Key('story-visible-<videoId>')`); tự thêm → 🗑 (`Key('story-delete-<videoId>')`, `AlertDialog` xác nhận). FAB ➕ (`Key('story-add')`) → `AddStorySheet`. Sau mọi thay đổi → `ref.invalidate(storyLibraryProvider)`.
- [ ] `AddStorySheet` (bottom sheet toàn màn): `TextField` link (nút Dán từ clipboard); **Kiểm tra** → `parseYoutubeId` (null → "Link không hợp lệ"; đã có → "Truyện đã có") → `OEmbedClient.fetch` (NotEmbeddable → "Video này không cho phát trong app"; NotFound → "Không tìm thấy video"; Failed → "Không kết nối được, thử lại nhé") → OK: hiện trình phát xem thử `factory(controls: true)` + ô tên (điền sẵn title, sửa được) + chọn chủ đề (`DropdownButton`, mặc định `fairy_vi`); khi player báo `playing` lần đầu → đọc `duration()`; player `error` → "Video này không phát được" và tắt Lưu; **Lưu** (bật khi đã nhận `playing` hoặc đã có duration) → `addUserStory(Story(..., userAdded: true))`, đóng.
- [ ] Tests: cổng — sai đổi phép, đúng mở setup (gõ đáp số qua phím); setup — nạp lần trước, chọn thời gian hiện lựa chọn overrun, Bắt đầu lưu setup và mở lưới, thư viện rỗng tắt nút; home — 🌙 nói "Nghe chuyện" rồi mở cổng; parent → Truyện; quản lý — ẩn/hiện có sẵn lưu store, xóa tự thêm có xác nhận, thêm: link sai, NotEmbeddable, OK + fake player `playing` → Lưu → xuất hiện trong danh sách với độ dài; vừa 360×640.
- [ ] `flutter test`, analyze, validate, `flutter build apk --debug`. Commit `feat: story time gate, setup and parent story list`.

### Task 5 (controller): review toàn nhánh → sửa → `0.7.0+8` → PR → CI → merge → tag `v0.7.0`.
