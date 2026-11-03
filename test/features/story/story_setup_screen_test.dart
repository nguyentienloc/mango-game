import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/stories/story_store.dart';
import 'package:xoai_castle/features/story/story_grid_screen.dart';
import 'package:xoai_castle/features/story/story_models.dart';
import 'package:xoai_castle/features/story/story_setup_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

const _stories = [
  Story(videoId: 'aaaaaaaaaaa', title: 'Tấm Cám', topic: StoryTopic.fairyVi, duration: Duration(minutes: 10)),
  Story(videoId: 'bbbbbbbbbbb', title: 'Elsa', topic: StoryTopic.princess, duration: Duration(minutes: 8)),
  Story(videoId: 'ccccccccccc', title: 'Cinderella', topic: StoryTopic.english, duration: Duration(minutes: 12)),
];

final _start = find.byKey(const Key('story-start'));
const _finish = 'Nghe hết truyện đang dở';
const _stopNow = 'Dừng ngay khi hết giờ';

Finder _chip(String label) => find.widgetWithText(FilterChip, label);
Finder _choice(String label) => find.widgetWithText(ChoiceChip, label);

bool _selected(WidgetTester tester, Finder f) {
  final w = tester.widget(f);
  return switch (w) {
    FilterChip(:final selected) => selected,
    ChoiceChip(:final selected) => selected,
    _ => throw StateError('not a chip'),
  };
}

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<void> pumpSetup(WidgetTester tester, {required MemoryStoryStore store, List<Story> bundled = _stories}) async {
    await tester.pumpWidget(
      testApp(
        content: withStories(content, bundled),
        tts: FakeTts(),
        stories: store,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StorySetupScreen())),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 100, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('defaults: all topics, 2 stories, listen only; only topics that have stories', (tester) async {
    await pumpSetup(tester, store: MemoryStoryStore());
    expect(_selected(tester, _chip('Tất cả')), isTrue);
    for (final t in [StoryTopic.fairyVi, StoryTopic.princess, StoryTopic.english]) {
      expect(_selected(tester, _chip(t.label)), isFalse);
    }
    expect(_chip(StoryTopic.other.label), findsNothing);
    expect(_selected(tester, _choice('2')), isTrue);
    expect(find.text(_finish), findsNothing, reason: 'overrun only shows for a time limit');
    final mode = tester.widget<SegmentedButton<StoryViewMode>>(find.byType(SegmentedButton<StoryViewMode>));
    expect(mode.selected, {StoryViewMode.listen});
  });

  testWidgets('loads the last setup, dropping topics that have no stories any more', (tester) async {
    final store = MemoryStoryStore();
    await store.saveSetup(
      const StorySetup(
        topics: {StoryTopic.english, StoryTopic.other},
        limit: TimeLimit(Duration(minutes: 30), StoryOverrun.stopNow),
        mode: StoryViewMode.watch,
      ),
    );
    await pumpSetup(tester, store: store);
    expect(_selected(tester, _chip('Tất cả')), isFalse);
    expect(_selected(tester, _chip(StoryTopic.english.label)), isTrue);
    expect(_selected(tester, _chip(StoryTopic.fairyVi.label)), isFalse);
    expect(_selected(tester, _choice('30 phút')), isTrue);
    await scrollTo(tester, find.text(_stopNow));
    final group = tester.widget<RadioGroup<StoryOverrun>>(find.byType(RadioGroup<StoryOverrun>));
    expect(group.groupValue, StoryOverrun.stopNow);
    final mode = tester.widget<SegmentedButton<StoryViewMode>>(find.byType(SegmentedButton<StoryViewMode>));
    expect(mode.selected, {StoryViewMode.watch});

    await scrollTo(tester, _start);
    await tester.tap(_start);
    await tester.pump();
    await tester.pump();
    expect((await store.lastSetup()).topics, {StoryTopic.english}, reason: 'the stale topic is not saved back');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('choosing time shows the overrun options; "Tất cả" clears the topics', (tester) async {
    await pumpSetup(tester, store: MemoryStoryStore());
    await tester.tap(_chip(StoryTopic.princess.label));
    await tester.pumpAndSettle();
    expect(_selected(tester, _chip(StoryTopic.princess.label)), isTrue);
    expect(_selected(tester, _chip('Tất cả')), isFalse);
    await tester.tap(_chip('Tất cả'));
    await tester.pumpAndSettle();
    expect(_selected(tester, _chip('Tất cả')), isTrue);
    expect(_selected(tester, _chip(StoryTopic.princess.label)), isFalse);

    await tester.tap(find.text('Thời gian'));
    await tester.pumpAndSettle();
    expect(_choice('2'), findsNothing);
    expect(_selected(tester, _choice('15 phút')), isTrue);
    await scrollTo(tester, find.text(_stopNow));
    expect(find.text(_finish), findsOneWidget);
    final group = tester.widget<RadioGroup<StoryOverrun>>(find.byType(RadioGroup<StoryOverrun>));
    expect(group.groupValue, StoryOverrun.finish);
  });

  testWidgets('Bắt đầu saves the setup and opens the grid in place of the setup screen', (tester) async {
    final store = MemoryStoryStore();
    await pumpSetup(tester, store: store);
    await tester.tap(_chip(StoryTopic.fairyVi.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thời gian'));
    await tester.pumpAndSettle();
    await tester.tap(_choice('45 phút'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text(_stopNow));
    await tester.tap(find.text(_stopNow));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('🎬 Xem video'));
    await tester.tap(find.text('🎬 Xem video'));
    await tester.pumpAndSettle();
    await scrollTo(tester, _start);
    await tester.tap(_start);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      await store.lastSetup(),
      const StorySetup(
        topics: {StoryTopic.fairyVi},
        limit: TimeLimit(Duration(minutes: 45), StoryOverrun.stopNow),
        mode: StoryViewMode.watch,
      ),
    );
    final grid = tester.widget<StoryGridScreen>(find.byType(StoryGridScreen));
    expect(grid.run.setup, await store.lastSetup());
    expect(grid.run.library.all.map((s) => s.videoId), [for (final s in _stories) s.videoId]);
    expect(find.byType(StorySetupScreen, skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty library says how to add stories and Bắt đầu is off', (tester) async {
    final store = MemoryStoryStore();
    await pumpSetup(tester, store: store, bundled: const []);
    expect(find.text('Chưa có truyện. Vào khu bố mẹ → Truyện để thêm.'), findsOneWidget);
    await scrollTo(tester, _start);
    expect(tester.widget<FilledButton>(_start).onPressed, isNull);
  });

  testWidgets('hidden stories do not count: all hidden is an empty library', (tester) async {
    final store = MemoryStoryStore();
    for (final s in _stories) {
      await store.setHidden(s.id, true);
    }
    await pumpSetup(tester, store: store);
    expect(find.text('Chưa có truyện. Vào khu bố mẹ → Truyện để thêm.'), findsOneWidget);
  });

  testWidgets('fits a 360x640 phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpSetup(tester, store: MemoryStoryStore());
    await tester.tap(find.text('Thời gian'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await scrollTo(tester, _start);
    expect(tester.getRect(_start).bottom, lessThanOrEqualTo(640));
    expect(tester.getRect(_start).right, lessThanOrEqualTo(360));
  });
}
