import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/story/story_end_screen.dart';
import 'package:xoai_castle/features/story/story_grid_screen.dart';
import 'package:xoai_castle/features/story/story_library.dart';
import 'package:xoai_castle/features/story/story_models.dart';
import 'package:xoai_castle/features/story/story_player.dart';
import 'package:xoai_castle/features/story/story_player_screen.dart';
import 'package:xoai_castle/features/story/story_run.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

const _pick = 'Xoài chọn truyện muốn nghe nào!';
const _bye = 'Hết giờ nghe chuyện rồi, Xoài ngủ ngon nhé!';
const _error = 'Truyện này chưa mở được, Xoài chọn truyện khác nha!';
const _offline = 'Cần có mạng để nghe chuyện nha!';

const _stories = [
  Story(videoId: 'aaaaaaaaaaa', title: 'Tấm Cám', topic: StoryTopic.fairyVi, duration: Duration(minutes: 10)),
  Story(videoId: 'bbbbbbbbbbb', title: 'Cô bé quàng khăn đỏ', topic: StoryTopic.fairyVi, duration: Duration(minutes: 8)),
  Story(videoId: 'ccccccccccc', title: 'Elsa và Anna đi trượt băng trên hồ', topic: StoryTopic.princess),
  Story(videoId: 'ddddddddddd', title: 'The Little Mermaid', topic: StoryTopic.english, duration: Duration(minutes: 12)),
];

Finder _card(String videoId) => find.byKey(Key('story-$videoId'));
final _home = find.byKey(const Key('story-home'));
final _gridHome = find.byKey(const Key('story-grid-home'));
final _playPause = find.byKey(const Key('story-playpause'));
final _remaining = find.byKey(const Key('story-remaining'));

class _Env {
  _Env(this.tts, this.players, this.awake, this.probe, this.run);

  final FakeTts tts;
  final FakeStoryPlayers players;
  final FakeScreenAwake awake;
  final FakeConnectivityProbe probe;
  final StoryRun run;

  FakeStoryPlayer get player => players.last;

  int said(String text) => tts.texts.where((t) => t == text).length;

  String get remaining => (find.byKey(const Key('story-remaining')).evaluate().single.widget as Text).data!;
}

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

  Future<_Env> pumpGrid(
    WidgetTester tester, {
    StorySetup setup = const StorySetup(),
    bool online = true,
  }) async {
    final tts = FakeTts();
    final players = FakeStoryPlayers();
    final awake = FakeScreenAwake();
    final probe = FakeConnectivityProbe(isOnline: online);
    final run = StoryRun(
      setup: setup,
      library: StoryLibrary(bundled: _stories, user: const [], hidden: const {}),
    );
    await tester.pumpWidget(
      testApp(
        content: content,
        tts: tts,
        storyPlayer: players.create,
        connectivity: probe,
        screenAwake: awake,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StoryGridScreen(run: run))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return _Env(tts, players, awake, probe, run);
  }

  Future<void> openStory(WidgetTester tester, _Env env, String videoId) async {
    await tester.tap(_card(videoId));
    await settle(tester);
    expect(find.byType(StoryPlayerScreen), findsOneWidget);
  }

  Future<void> emit(WidgetTester tester, _Env env, StoryPlayerState s) async {
    env.player.emit(s);
    await tester.pump();
  }

  /// The end screen is up; after its phrase and at least 2 s it goes back to the first route.
  Future<void> expectEndThenHome(WidgetTester tester, _Env env, String phrase) async {
    expect(find.byType(StoryEndScreen), findsOneWidget);
    expect(env.tts.texts.last, phrase);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(StoryEndScreen), findsOneWidget, reason: 'stays at least 2 s');
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.byType(StoryEndScreen), findsNothing);
    expect(find.byType(StoryGridScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  }

  testWidgets('count 2: two stories end naturally, then good night and back home', (tester) async {
    final env = await pumpGrid(tester);
    expect(env.probe.checks, 1);
    expect(env.said(_pick), 1);
    expect(env.remaining, 'Còn 2 truyện');
    for (final s in _stories) {
      expect(_card(s.videoId), findsOneWidget);
    }

    await openStory(tester, env, 'aaaaaaaaaaa');
    expect(env.player.loaded, ['aaaaaaaaaaa']);
    expect(env.player.controls, isFalse);
    expect(env.player.volumes, [100]);
    expect(env.awake.on, isTrue);
    expect(env.tts.calls, contains('stop'), reason: 'Elsa stops talking when the story starts');
    await emit(tester, env, StoryPlayerState.playing);
    expect(env.run.isPlaying, isTrue);
    expect(find.text('⏸️'), findsOneWidget);
    await emit(tester, env, StoryPlayerState.ended);
    await settle(tester);

    expect(find.byType(StoryPlayerScreen), findsNothing);
    expect(env.players.players.first.disposed, isTrue);
    expect(env.awake.on, isFalse);
    expect(env.run.isPlaying, isFalse);
    expect(env.remaining, 'Còn 1 truyện');
    expect(env.said(_pick), 2, reason: 'back on the grid Elsa asks again');

    await openStory(tester, env, 'bbbbbbbbbbb');
    await emit(tester, env, StoryPlayerState.playing);
    await emit(tester, env, StoryPlayerState.ended);
    await settle(tester);
    await expectEndThenHome(tester, env, _bye);
  });

  testWidgets('leaving a story after 30 s with 🏠 does not use up a story', (tester) async {
    final env = await pumpGrid(tester);
    await openStory(tester, env, 'aaaaaaaaaaa');
    await emit(tester, env, StoryPlayerState.playing);
    await tester.pump(const Duration(seconds: 30));
    expect(env.run.session.currentPlayed, greaterThanOrEqualTo(const Duration(seconds: 29)));
    await tester.tap(_home);
    await settle(tester);
    expect(find.byType(StoryGridScreen), findsOneWidget);
    expect(find.byType(StoryPlayerScreen), findsNothing);
    expect(env.run.session.listened, 0);
    expect(env.run.session.current, isNull);
    expect(env.remaining, 'Còn 2 truyện');
    expect(env.said(_pick), 2);
  });

  testWidgets('the back gesture in the player is 🏠: back to the grid, the session goes on', (tester) async {
    final env = await pumpGrid(tester);
    await openStory(tester, env, 'aaaaaaaaaaa');
    await emit(tester, env, StoryPlayerState.playing);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(StoryGridScreen), findsOneWidget);
    expect(env.run.session.current, isNull);
    expect(env.remaining, 'Còn 2 truyện');
  });

  testWidgets('a story that fails: Elsa says so, it leaves the grid and no story is used up', (tester) async {
    final env = await pumpGrid(tester);
    await openStory(tester, env, 'aaaaaaaaaaa');
    await emit(tester, env, StoryPlayerState.error);
    expect(env.tts.texts.last, _error);
    await settle(tester);
    expect(find.byType(StoryGridScreen), findsOneWidget);
    expect(find.byType(StoryPlayerScreen), findsNothing);
    expect(_card('aaaaaaaaaaa'), findsNothing);
    expect(_card('bbbbbbbbbbb'), findsOneWidget);
    expect(env.run.failedThisRun, {'yt:aaaaaaaaaaa'});
    expect(env.remaining, 'Còn 2 truyện');
    expect(env.said(_pick), 1, reason: 'the error phrase already asks for another story');
  });

  testWidgets('offline: Elsa says the internet is needed and goes back home', (tester) async {
    final env = await pumpGrid(tester, online: false);
    expect(find.byType(StoryGridScreen), findsNothing);
    expect(env.said(_pick), 0);
    await expectEndThenHome(tester, env, _offline);
  });

  testWidgets('🏠 on the grid ends the session', (tester) async {
    final env = await pumpGrid(tester);
    await tester.tap(_gridHome);
    await settle(tester);
    await expectEndThenHome(tester, env, _bye);
  });

  testWidgets('the back gesture on the grid ends the session', (tester) async {
    final env = await pumpGrid(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await expectEndThenHome(tester, env, _bye);
  });

  testWidgets('a double tap on a card opens one story', (tester) async {
    final env = await pumpGrid(tester);
    // Two taps before the player route is up (a real second tap could land during the push).
    final card = tester.widget<GestureDetector>(_card('aaaaaaaaaaa'));
    card.onTap!();
    card.onTap!();
    await settle(tester);
    expect(env.players.players, hasLength(1));
    expect(find.byType(StoryPlayerScreen), findsOneWidget);
  });

  testWidgets('time 10 min + stop now: at the limit the sound fades to 0, then good night', (tester) async {
    final env = await pumpGrid(tester, setup: const StorySetup(limit: TimeLimit(Duration(minutes: 10), StoryOverrun.stopNow)));
    expect(env.remaining, 'Còn 10 phút');
    await openStory(tester, env, 'aaaaaaaaaaa');
    await emit(tester, env, StoryPlayerState.playing);
    await tester.pump(const Duration(minutes: 10));
    expect(env.player.pauses, 0, reason: 'still fading');
    await tester.pump(const Duration(seconds: 6));
    expect(env.player.volumes, [100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0]);
    expect(env.player.pauses, 1);
    await settle(tester);
    expect(find.byType(StoryPlayerScreen), findsNothing);
    await expectEndThenHome(tester, env, _bye);
  });

  testWidgets('time + finish: the story playing at the limit plays on, then good night when it ends', (tester) async {
    final env = await pumpGrid(tester, setup: const StorySetup(limit: TimeLimit(Duration(minutes: 10), StoryOverrun.finish)));
    await openStory(tester, env, 'aaaaaaaaaaa');
    await emit(tester, env, StoryPlayerState.playing);
    await tester.pump(const Duration(minutes: 11));
    expect(find.byType(StoryPlayerScreen), findsOneWidget);
    expect(env.player.volumes, [100]);
    expect(env.player.pauses, 0);
    await emit(tester, env, StoryPlayerState.ended);
    await settle(tester);
    await expectEndThenHome(tester, env, _bye);
  });

  testWidgets('time + finish: a story is cut 10 minutes past the limit', (tester) async {
    final env = await pumpGrid(tester, setup: const StorySetup(limit: TimeLimit(Duration(minutes: 10), StoryOverrun.finish)));
    await openStory(tester, env, 'ccccccccccc'); // length unknown
    await emit(tester, env, StoryPlayerState.playing);
    await tester.pump(const Duration(minutes: 20));
    await tester.pump(const Duration(seconds: 6));
    expect(env.player.volumes.last, 0);
    expect(env.player.pauses, 1);
    await settle(tester);
    await expectEndThenHome(tester, env, _bye);
  });

  testWidgets('time runs out while on the grid: good night', (tester) async {
    final env = await pumpGrid(tester, setup: const StorySetup(limit: TimeLimit(Duration(minutes: 10), StoryOverrun.finish)));
    await tester.pump(const Duration(seconds: 30));
    expect(env.remaining, 'Còn 10 phút', reason: 'minutes round up');
    await tester.pump(const Duration(seconds: 40));
    expect(env.remaining, 'Còn 9 phút');
    await tester.pump(const Duration(minutes: 10));
    await settle(tester);
    await expectEndThenHome(tester, env, _bye);
  });

  testWidgets('in the background the video pauses and the clock stops; back in front it waits for ▶', (tester) async {
    final env = await pumpGrid(tester, setup: const StorySetup(limit: TimeLimit(Duration(minutes: 10), StoryOverrun.finish)));
    await openStory(tester, env, 'aaaaaaaaaaa');
    await emit(tester, env, StoryPlayerState.playing);
    final before = env.run.session.elapsed;
    // The engine reports every step on the way out and back in.
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(minutes: 5));
    expect(env.player.pauses, 1);
    expect(env.run.isPlaying, isFalse);
    expect(env.run.session.elapsed, before);
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(env.player.plays, 0);
    expect(find.text('▶️'), findsOneWidget);
    await tester.tap(_playPause);
    await tester.pump();
    expect(env.player.plays, 1);
    expect(env.run.isPlaying, isTrue);
    await tester.tap(_playPause);
    await tester.pump();
    expect(env.player.pauses, 2);
  });

  testWidgets('listen mode covers the video with Elsa and the title; watch mode shows it', (tester) async {
    final env = await pumpGrid(tester);
    await openStory(tester, env, 'aaaaaaaaaaa');
    expect(find.byKey(const Key('story-listen-cover')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('story-listen-cover')), matching: find.text('Tấm Cám')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await pumpGrid(tester, setup: const StorySetup(mode: StoryViewMode.watch));
    await tester.tap(_card('aaaaaaaaaaa'));
    await settle(tester);
    expect(find.byKey(const Key('story-listen-cover')), findsNothing);
    expect(find.byKey(const Key('fake-story-video')), findsOneWidget);
  });

  testWidgets('taps on the video do nothing', (tester) async {
    final env = await pumpGrid(tester, setup: const StorySetup(mode: StoryViewMode.watch));
    await openStory(tester, env, 'aaaaaaaaaaa');
    await emit(tester, env, StoryPlayerState.playing);
    final video = find.byKey(const Key('fake-story-video'));
    expect(video.hitTestable(), findsNothing);
    await tester.tapAt(tester.getCenter(video));
    await tester.pump();
    expect(find.byType(StoryPlayerScreen), findsOneWidget);
    expect(env.player.pauses, 0);
  });

  testWidgets('fits a 360x640 phone: grid, player (both modes) and end screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var env = await pumpGrid(tester);
    expect(tester.takeException(), isNull);
    for (final s in _stories) {
      final r = tester.getRect(_card(s.videoId));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(360));
    }
    expect(tester.getRect(_remaining).right, lessThanOrEqualTo(360));
    await openStory(tester, env, 'ccccccccccc');
    expect(tester.takeException(), isNull);
    expect(tester.getRect(_playPause).bottom, lessThanOrEqualTo(640));
    expect(tester.getRect(_home).bottom, lessThanOrEqualTo(640));
    await tester.pumpWidget(const SizedBox());

    env = await pumpGrid(tester, setup: const StorySetup(mode: StoryViewMode.watch));
    await openStory(tester, env, 'ddddddddddd');
    expect(tester.takeException(), isNull);
    expect(tester.getRect(_playPause).bottom, lessThanOrEqualTo(640));
    await tester.tap(_home);
    await settle(tester);
    await tester.tap(_gridHome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StoryEndScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
  });
}
