import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/stories/story_store.dart';
import 'package:xoai_castle/features/parent/add_story_sheet.dart';
import 'package:xoai_castle/features/parent/stories_manage_screen.dart';
import 'package:xoai_castle/features/story/oembed_client.dart';
import 'package:xoai_castle/features/story/story_models.dart';
import 'package:xoai_castle/features/story/story_player.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

const _tam = Story(
  videoId: 'aaaaaaaaaaa',
  title: 'Tấm Cám',
  topic: StoryTopic.fairyVi,
  duration: Duration(minutes: 10, seconds: 5),
);
const _elsa = Story(videoId: 'ccccccccccc', title: 'Elsa', topic: StoryTopic.princess, duration: Duration(minutes: 8));
const _mine = Story(videoId: 'uuuuuuuuuuu', title: 'Truyện của mẹ', topic: StoryTopic.other, userAdded: true);
const _newId = 'NEWvideo_-1';

Finder _row(String videoId) => find.byKey(Key('story-row-$videoId'));
Finder _inRow(String videoId, Finder f) => find.descendant(of: _row(videoId), matching: f);
final _save = find.byKey(const Key('story-save'));
final _check = find.byKey(const Key('story-check'));
final _link = find.byKey(const Key('story-link'));
final _error = find.byKey(const Key('story-add-error'));

class _Env {
  _Env(this.store, this.players, this.oembed);

  final MemoryStoryStore store;
  final FakeStoryPlayers players;
  final FakeOEmbedClient oembed;
}

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<_Env> pumpManage(WidgetTester tester, {OEmbedResult oembed = const OEmbedOk('Sự tích cây vú sữa')}) async {
    final store = MemoryStoryStore();
    await store.addUserStory(_mine);
    final players = FakeStoryPlayers();
    final client = FakeOEmbedClient(result: oembed);
    await tester.pumpWidget(
      testApp(
        content: withStories(content, const [_tam, _elsa]),
        tts: FakeTts(),
        stories: store,
        storyPlayer: players.create,
        oembed: client,
        home: const StoriesManageScreen(),
      ),
    );
    await tester.pumpAndSettle();
    return _Env(store, players, client);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('story-add')));
    await tester.pumpAndSettle();
    expect(find.byType(AddStorySheet), findsOneWidget);
  }

  Future<void> checkLink(WidgetTester tester, String link) async {
    await tester.enterText(_link, link);
    await tester.tap(_check);
    await tester.pumpAndSettle();
  }

  String errorText(WidgetTester tester) => tester.widget<Text>(_error).data!;

  bool saveEnabled(WidgetTester tester) => tester.widget<FilledButton>(_save).onPressed != null;

  testWidgets('lists stories by topic with length and origin', (tester) async {
    await pumpManage(tester);
    for (final t in [StoryTopic.fairyVi, StoryTopic.princess, StoryTopic.other]) {
      expect(find.text(t.label), findsOneWidget);
    }
    expect(find.text(StoryTopic.english.label), findsNothing);
    expect(
      tester.getTopLeft(find.text(StoryTopic.fairyVi.label)).dy,
      lessThan(tester.getTopLeft(_row(_tam.videoId)).dy),
    );
    expect(
      tester.getTopLeft(_row(_tam.videoId)).dy,
      lessThan(tester.getTopLeft(find.text(StoryTopic.princess.label)).dy),
    );

    expect(_inRow(_tam.videoId, find.text('Tấm Cám')), findsOneWidget);
    expect(_inRow(_tam.videoId, find.textContaining('10:05')), findsOneWidget);
    expect(_inRow(_tam.videoId, find.textContaining('Có sẵn')), findsOneWidget);
    expect(find.byKey(Key('story-visible-${_tam.videoId}')), findsOneWidget);
    expect(find.byKey(Key('story-delete-${_tam.videoId}')), findsNothing);

    expect(_inRow(_mine.videoId, find.textContaining('—')), findsOneWidget);
    expect(_inRow(_mine.videoId, find.textContaining('Tự thêm')), findsOneWidget);
    expect(find.byKey(Key('story-delete-${_mine.videoId}')), findsOneWidget);
    expect(find.byKey(Key('story-visible-${_mine.videoId}')), findsNothing);
    final thumb = tester.getSize(find.byKey(Key('story-thumb-${_tam.videoId}')));
    expect(thumb, const Size(64, 36));
  });

  testWidgets('the switch hides and shows a bundled story, saved in the store', (tester) async {
    final env = await pumpManage(tester);
    final toggle = find.byKey(Key('story-visible-${_elsa.videoId}'));
    expect(tester.widget<Switch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(await env.store.hiddenIds(), {_elsa.id});
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(await env.store.hiddenIds(), isEmpty);
    expect(tester.widget<Switch>(toggle).value, isTrue);
  });

  testWidgets('deleting an added story asks first', (tester) async {
    final env = await pumpManage(tester);
    final delete = find.byKey(Key('story-delete-${_mine.videoId}'));
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(await env.store.userStories(), hasLength(1));
    expect(_row(_mine.videoId), findsOneWidget);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(await env.store.userStories(), isEmpty);
    expect(_row(_mine.videoId), findsNothing);
    expect(find.text(StoryTopic.other.label), findsNothing);
  });

  testWidgets('add: a bad link and a story already listed are refused before asking YouTube', (tester) async {
    final env = await pumpManage(tester);
    await openSheet(tester);
    await checkLink(tester, 'https://example.com/watch?v=abc');
    expect(errorText(tester), 'Link không hợp lệ');
    await checkLink(tester, 'https://youtu.be/${_tam.videoId}');
    expect(errorText(tester), 'Truyện đã có');
    await checkLink(tester, 'https://www.youtube.com/watch?v=${_mine.videoId}');
    expect(errorText(tester), 'Truyện đã có');
    expect(env.oembed.asked, isEmpty);
    expect(env.players.players, isEmpty);
    expect(_save, findsNothing);
  });

  for (final (result, message) in [
    (const OEmbedNotEmbeddable(), 'Video này không cho phát trong app'),
    (const OEmbedNotFound(), 'Không tìm thấy video'),
    (const OEmbedFailed(), 'Không kết nối được, thử lại nhé'),
  ]) {
    testWidgets('add: oEmbed ${result.runtimeType} says "$message"', (tester) async {
      final env = await pumpManage(tester, oembed: result);
      await openSheet(tester);
      await checkLink(tester, 'https://youtu.be/$_newId');
      expect(env.oembed.asked, [_newId]);
      expect(errorText(tester), message);
      expect(env.players.players, isEmpty);
      expect(_save, findsNothing);
    });
  }

  testWidgets('add: OK previews the video, takes its length once playing, then Lưu adds it to the list', (
    tester,
  ) async {
    final env = await pumpManage(tester);
    await openSheet(tester);
    await checkLink(tester, 'https://m.youtube.com/watch?v=$_newId&t=10');
    expect(_error, findsNothing);
    final player = env.players.last;
    expect(player.controls, isTrue);
    expect(player.loaded, [_newId]);
    expect(find.byKey(const Key('fake-story-video')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('story-title'))).controller!.text, 'Sự tích cây vú sữa');
    expect(tester.widget<DropdownButton<StoryTopic>>(find.byKey(const Key('story-topic'))).value, StoryTopic.fairyVi);
    expect(saveEnabled(tester), isFalse, reason: 'not known to play yet');

    player.knownDuration = const Duration(minutes: 7, seconds: 5);
    player.emit(StoryPlayerState.playing);
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isTrue);

    await tester.enterText(find.byKey(const Key('story-title')), 'Cây vú sữa');
    await tester.ensureVisible(find.byKey(const Key('story-topic')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('story-topic')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(StoryTopic.other.label).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(_save);
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(find.byType(AddStorySheet), findsNothing);
    expect(player.disposed, isTrue);
    final added = (await env.store.userStories()).firstWhere((s) => s.videoId == _newId);
    expect(
      [added.title, added.topic, added.duration, added.userAdded],
      ['Cây vú sữa', StoryTopic.other, const Duration(minutes: 7, seconds: 5), true],
    );
    expect(_inRow(_newId, find.text('Cây vú sữa')), findsOneWidget);
    expect(_inRow(_newId, find.textContaining('7:05')), findsOneWidget);
    expect(_inRow(_newId, find.textContaining('Tự thêm')), findsOneWidget);
  });

  testWidgets('add: a preview that fails to play cannot be saved', (tester) async {
    final env = await pumpManage(tester);
    await openSheet(tester);
    await checkLink(tester, _newId);
    env.players.last.emit(StoryPlayerState.error);
    await tester.pumpAndSettle();
    expect(errorText(tester), 'Video này không phát được');
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('add: closing the sheet without saving disposes the preview and adds nothing', (tester) async {
    final env = await pumpManage(tester);
    await openSheet(tester);
    await checkLink(tester, _newId);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AddStorySheet), findsNothing);
    expect(env.players.last.disposed, isTrue);
    expect((await env.store.userStories()).map((s) => s.videoId), [_mine.videoId]);
  });

  testWidgets('add: the list reloads whenever the sheet closes, saved or not', (tester) async {
    final env = await pumpManage(tester);
    await openSheet(tester);
    // Changed behind the list's back while the sheet is open.
    await env.store.addUserStory(const Story(videoId: _newId, title: 'Mới thêm', topic: StoryTopic.other, userAdded: true));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AddStorySheet), findsNothing);
    expect(_inRow(_newId, find.text('Mới thêm')), findsOneWidget);
  });

  testWidgets('add: the sheet cannot be dragged away (the preview takes drags)', (tester) async {
    await pumpManage(tester);
    await openSheet(tester);
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag, isFalse);
    await tester.drag(find.byType(AddStorySheet), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.byType(AddStorySheet), findsOneWidget);
  });

  testWidgets('add: Dán pastes the link from the clipboard', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'https://youtu.be/$_newId'};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpManage(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('story-paste')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_link).controller!.text, 'https://youtu.be/$_newId');
  });

  testWidgets('fits a 360x640 phone: list and add sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final env = await pumpManage(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(const Key('story-add'))).bottom, lessThanOrEqualTo(640));
    await openSheet(tester);
    await checkLink(tester, _newId);
    env.players.last.knownDuration = const Duration(minutes: 3);
    env.players.last.emit(StoryPlayerState.playing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(_save);
    await tester.pumpAndSettle();
    expect(tester.getRect(_save).bottom, lessThanOrEqualTo(640));
    expect(tester.getRect(_save).right, lessThanOrEqualTo(360));
  });
}
