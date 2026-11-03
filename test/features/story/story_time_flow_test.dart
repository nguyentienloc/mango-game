import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/stories/story_store.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/story/math_gate_screen.dart';
import 'package:xoai_castle/features/story/story_end_screen.dart';
import 'package:xoai_castle/features/story/story_grid_screen.dart';
import 'package:xoai_castle/features/story/story_models.dart';
import 'package:xoai_castle/features/story/story_player.dart';
import 'package:xoai_castle/features/story/story_player_screen.dart';
import 'package:xoai_castle/features/story/story_setup_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

const _bye = 'Hết giờ nghe chuyện rồi, Xoài ngủ ngon nhé!';

const _stories = [
  Story(videoId: 'aaaaaaaaaaa', title: 'Tấm Cám', topic: StoryTopic.fairyVi, duration: Duration(minutes: 10)),
  Story(videoId: 'bbbbbbbbbbb', title: 'Elsa', topic: StoryTopic.princess, duration: Duration(minutes: 8)),
];

/// The whole story time, on the real route stack: home → 🌙 → gate → setup → grid
/// → stories until the limit → good night → home, with nothing left behind.
void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  /// Frames for route transitions and pending futures (the night sky never settles).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('home → gate → setup → grid → two stories → good night → home', (tester) async {
    final tts = FakeTts();
    final players = FakeStoryPlayers();
    final awake = FakeScreenAwake();
    await tester.pumpWidget(
      testApp(
        content: withStories(content, _stories),
        tts: tts,
        stories: MemoryStoryStore(),
        storyPlayer: players.create,
        screenAwake: awake,
        home: const HomeScreen(),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('🌙'));
    await settle(tester);
    expect(find.byType(MathGateScreen), findsOneWidget);

    final problem = (tester.widget(find.byKey(const Key('gate-problem'))) as Text).data!;
    final m = RegExp(r'^(\d+) \+ (\d+) = \?$').firstMatch(problem)!;
    for (final d in '${int.parse(m[1]!) + int.parse(m[2]!)}'.split('')) {
      await tester.tap(find.byKey(Key('gate-key-$d')));
      await tester.pump();
    }
    await settle(tester);
    expect(find.byType(StorySetupScreen), findsOneWidget);
    expect(find.byType(MathGateScreen, skipOffstage: false), findsNothing, reason: 'the gate was replaced');

    final start = find.byKey(const Key('story-start'));
    await tester.scrollUntilVisible(start, 200);
    await tester.tap(start);
    await settle(tester);
    expect(find.byType(StoryGridScreen), findsOneWidget);
    expect(find.byType(StorySetupScreen, skipOffstage: false), findsNothing, reason: 'the setup was replaced');

    // Default setup: two stories.
    for (final id in ['aaaaaaaaaaa', 'bbbbbbbbbbb']) {
      await tester.tap(find.byKey(Key('story-$id')));
      await settle(tester);
      expect(find.byType(StoryPlayerScreen), findsOneWidget);
      expect(players.last.loaded, [id]);
      players.last.emit(StoryPlayerState.playing);
      await tester.pump();
      players.last.emit(StoryPlayerState.ended);
      await tester.pump();
      await settle(tester);
    }

    expect(find.byType(StoryEndScreen), findsOneWidget);
    expect(tts.texts.last, _bye);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    for (final type in [MathGateScreen, StorySetupScreen, StoryGridScreen, StoryPlayerScreen, StoryEndScreen]) {
      expect(find.byType(type, skipOffstage: false), findsNothing, reason: '$type left behind');
    }
    expect(Navigator.of(tester.element(find.byType(HomeScreen))).canPop(), isFalse);
    expect(awake.on, isFalse);
    expect(players.players.every((p) => p.disposed), isTrue);
  });
}
