import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/story/story_library.dart';
import 'package:xoai_castle/features/story/story_models.dart';
import 'package:xoai_castle/features/story/story_run.dart';

Story story(String id, {int? min, StoryTopic topic = StoryTopic.fairyVi}) => Story(
  videoId: id.padRight(11, 'x'),
  title: 'Truyện $id',
  topic: topic,
  duration: min == null ? null : Duration(minutes: min),
);

StoryLibrary library(List<Story> stories, {Set<String> hidden = const {}}) =>
    StoryLibrary(bundled: stories, user: const [], hidden: hidden);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

  StoryRun newRun({StorySetup setup = const StorySetup(), List<Story>? stories, DateTime Function()? now}) =>
      StoryRun(setup: setup, library: library(stories ?? [story('a'), story('b')]), now: now);

  group('clock', () {
    test('ticks once a second while the app is in the foreground and notifies each tick', () {
      fakeAsync((async) {
        final run = newRun();
        var notified = 0;
        run.addListener(() => notified++);
        async.elapse(const Duration(seconds: 5));
        expect(run.session.elapsed, const Duration(seconds: 5));
        expect(notified, 5);
        run.dispose();
      });
    });

    test('stops while the app is in the background (paused or hidden) and goes on when resumed', () {
      fakeAsync((async) {
        final run = newRun();
        async.elapse(const Duration(seconds: 3));
        WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        async.elapse(const Duration(seconds: 30));
        expect(run.session.elapsed, const Duration(seconds: 3));
        WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        async.elapse(const Duration(seconds: 30));
        expect(run.session.elapsed, const Duration(seconds: 3));
        WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 2));
        expect(run.session.elapsed, const Duration(seconds: 5));
        run.dispose();
      });
    });

    test('keeps ticking while only inactive (e.g. the notification shade is down)', () {
      fakeAsync((async) {
        final run = newRun();
        WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        async.elapse(const Duration(seconds: 4));
        expect(run.session.elapsed, const Duration(seconds: 4));
        run.dispose();
      });
    });

    test('story time only grows while isPlaying', () {
      fakeAsync((async) {
        final run = newRun();
        run.session.startStory(story('a'));
        async.elapse(const Duration(seconds: 10));
        expect(run.session.currentPlayed, Duration.zero);
        run.isPlaying = true;
        async.elapse(const Duration(seconds: 7));
        expect(run.session.currentPlayed, const Duration(seconds: 7));
        expect(run.session.elapsed, const Duration(seconds: 17));
        run.dispose();
      });
    });

    test('dispose stops the clock and the lifecycle observer', () {
      fakeAsync((async) {
        final run = newRun();
        async.elapse(const Duration(seconds: 2));
        run.dispose();
        async.elapse(const Duration(seconds: 10));
        WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(run.session.elapsed, const Duration(seconds: 2));
        expect(async.periodicTimerCount, 0);
      });
    });
  });

  group('background expiry', () {
    void away(Duration d, void Function(Duration) advanceClock) {
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        WidgetsBinding.instance.handleAppLifecycleStateChanged(s);
      }
      advanceClock(d);
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        WidgetsBinding.instance.handleAppLifecycleStateChanged(s);
      }
    }

    test('away 10 minutes or more: the sitting has expired and should end', () {
      var now = DateTime(2026, 11, 3, 20);
      final run = newRun(now: () => now);
      var notified = 0;
      run.addListener(() => notified++);
      expect(storyBackgroundExpiry, const Duration(minutes: 10));
      away(const Duration(minutes: 10), (d) => now = now.add(d));
      expect(run.expired, isTrue);
      expect(run.shouldEnd, isTrue);
      expect(notified, greaterThan(0), reason: 'screens hear about it at once');
      run.dispose();
    });

    test('away 5 minutes: the sitting goes on', () {
      var now = DateTime(2026, 11, 3, 20);
      final run = newRun(now: () => now);
      away(const Duration(minutes: 5), (d) => now = now.add(d));
      expect(run.expired, isFalse);
      expect(run.shouldEnd, isFalse);
      run.dispose();
    });

    test('short trips away do not add up', () {
      var now = DateTime(2026, 11, 3, 20);
      final run = newRun(now: () => now);
      for (var i = 0; i < 3; i++) {
        away(const Duration(minutes: 6), (d) => now = now.add(d));
      }
      expect(run.expired, isFalse);
      run.dispose();
    });

    test('expired with a story playing: shouldEnd waits for the player to end it', () {
      var now = DateTime(2026, 11, 3, 20);
      final run = newRun(now: () => now);
      run.session.startStory(story('a'));
      away(const Duration(minutes: 20), (d) => now = now.add(d));
      expect(run.expired, isTrue);
      expect(run.shouldEnd, isFalse);
      run.session.finishStory(completed: false);
      expect(run.shouldEnd, isTrue);
      run.dispose();
    });
  });

  group('pickable', () {
    test('visible stories of the chosen topics', () {
      final run = StoryRun(
        setup: const StorySetup(topics: {StoryTopic.princess}),
        library: library([
          story('a'),
          story('b', topic: StoryTopic.princess),
          story('c', topic: StoryTopic.princess),
        ], hidden: {story('c').id}),
      );
      expect(run.pickable.map((s) => s.title), ['Truyện b']);
      run.dispose();
    });

    test('all topics when none chosen; stories that failed this run are left out', () {
      final run = newRun(stories: [story('a'), story('b'), story('c')]);
      expect(run.pickable, hasLength(3));
      run.failedThisRun.add(story('b').id);
      expect(run.pickable.map((s) => s.title), ['Truyện a', 'Truyện c']);
      run.dispose();
    });

    test('time + finish hides stories longer than the time left + 10 minutes', () {
      fakeAsync((async) {
        final run = newRun(
          setup: const StorySetup(limit: TimeLimit(Duration(minutes: 10), StoryOverrun.finish)),
          stories: [story('short', min: 5), story('long', min: 19), story('unknown')],
        );
        expect(run.pickable, hasLength(3));
        async.elapse(const Duration(minutes: 2));
        expect(run.pickable.map((s) => s.title), ['Truyện short', 'Truyện unknown']);
        run.dispose();
      });
    });
  });

  group('shouldEnd', () {
    test('when the count limit is reached and no story is playing', () {
      final run = newRun(setup: const StorySetup(limit: CountLimit(1)));
      expect(run.shouldEnd, isFalse);
      run.session.startStory(story('a'));
      expect(run.shouldEnd, isFalse);
      run.session.finishStory(completed: true);
      expect(run.session.limitReached, isTrue);
      expect(run.shouldEnd, isTrue);
      run.dispose();
    });

    test('not while the last story is still playing past the time limit', () {
      fakeAsync((async) {
        final run = newRun(setup: const StorySetup(limit: TimeLimit(Duration(minutes: 10), StoryOverrun.finish)));
        run.session.startStory(story('a'));
        run.isPlaying = true;
        async.elapse(const Duration(minutes: 11));
        expect(run.session.limitReached, isTrue);
        expect(run.shouldEnd, isFalse);
        run.session.finishStory(completed: true);
        expect(run.shouldEnd, isTrue);
        run.dispose();
      });
    });

    test('when nothing is left to pick', () {
      final run = newRun(stories: [story('a')]);
      expect(run.shouldEnd, isFalse);
      run.failedThisRun.add(story('a').id);
      expect(run.shouldEnd, isTrue);
      run.dispose();
    });
  });
}
