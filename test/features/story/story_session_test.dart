import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/story/story_models.dart';
import 'package:xoai_castle/features/story/story_session.dart';

Story story(String id, {int? sec, StoryTopic topic = StoryTopic.fairyVi}) => Story(
      videoId: id.padRight(11, 'x'),
      title: 'Truyện $id',
      topic: topic,
      duration: sec == null ? null : Duration(seconds: sec),
    );

void main() {
  group('Story', () {
    test('id and thumbnail derive from the video id', () {
      final s = story('abc');
      expect(s.id, 'yt:abcxxxxxxxx');
      expect(s.thumbnailUrl, 'https://i.ytimg.com/vi/abcxxxxxxxx/hqdefault.jpg');
    });

    test('fromJson reads a pack item', () {
      final s = Story.fromJson({
        'id': 'yt:aaaaaaaaaaa',
        'videoId': 'aaaaaaaaaaa',
        'title': 'Tấm Cám',
        'topic': 'fairy_vi',
        'durationSec': 600,
      });
      expect(s.videoId, 'aaaaaaaaaaa');
      expect(s.title, 'Tấm Cám');
      expect(s.topic, StoryTopic.fairyVi);
      expect(s.duration, const Duration(minutes: 10));
      expect(s.userAdded, isFalse);
    });

    test('StoryTopic.fromId finds topics and rejects unknown ids', () {
      expect(StoryTopic.fromId('princess'), StoryTopic.princess);
      expect(StoryTopic.fromId('nope'), isNull);
      expect(StoryTopic.values.map((t) => t.id), ['fairy_vi', 'princess', 'english', 'other']);
    });
  });

  group('StorySetup', () {
    test('defaults', () {
      const s = StorySetup();
      expect(s.topics, isEmpty);
      expect(s.limit, const CountLimit(2));
      expect(s.mode, StoryViewMode.listen);
    });

    test('count setup round-trips', () {
      const s = StorySetup(topics: {StoryTopic.english, StoryTopic.other}, limit: CountLimit(4), mode: StoryViewMode.watch);
      expect(StorySetup.fromJson(s.toJson()), s);
    });

    test('time setup round-trips', () {
      const s = StorySetup(topics: {StoryTopic.princess}, limit: TimeLimit(Duration(minutes: 45), StoryOverrun.stopNow));
      expect(StorySetup.fromJson(s.toJson()), s);
      expect(s.toJson()['limit'], {'kind': 'time', 'minutes': 45, 'overrun': 'stopNow'});
    });

    test('default setup round-trips', () {
      expect(StorySetup.fromJson(const StorySetup().toJson()), const StorySetup());
    });

    test('equal setups have equal hash codes', () {
      expect(
        const StorySetup(topics: {StoryTopic.english}, limit: TimeLimit(Duration(minutes: 15), StoryOverrun.finish)).hashCode,
        const StorySetup(topics: {StoryTopic.english}, limit: TimeLimit(Duration(minutes: 15), StoryOverrun.finish)).hashCode,
      );
      expect(const StorySetup(limit: CountLimit(2)) == const StorySetup(limit: CountLimit(3)), isFalse);
    });

    test('empty or broken json gives defaults', () {
      expect(StorySetup.fromJson({}), const StorySetup());
      expect(StorySetup.fromJson({'topics': 'x', 'limit': 5, 'mode': 3}), const StorySetup());
      expect(StorySetup.fromJson({'limit': {'kind': 'weird'}}), const StorySetup());
    });

    test('unknown topics are dropped and bad modes fall back', () {
      final s = StorySetup.fromJson({
        'topics': ['english', 'nope', 7],
        'mode': 'sideways',
      });
      expect(s.topics, {StoryTopic.english});
      expect(s.mode, StoryViewMode.listen);
    });

    test('values outside the option lists fall back to defaults', () {
      expect(StorySetup.fromJson({'limit': {'kind': 'count', 'stories': 9}}).limit, const CountLimit(2));
      expect(StorySetup.fromJson({'limit': {'kind': 'count', 'stories': 0}}).limit, const CountLimit(2));
      expect(StorySetup.fromJson({'limit': {'kind': 'count', 'stories': 'x'}}).limit, const CountLimit(2));
      expect(
        StorySetup.fromJson({'limit': {'kind': 'time', 'minutes': 25, 'overrun': 'finish'}}).limit,
        const TimeLimit(Duration(minutes: 15), StoryOverrun.finish),
      );
      expect(
        StorySetup.fromJson({'limit': {'kind': 'time', 'minutes': 30, 'overrun': 'bogus'}}).limit,
        const TimeLimit(Duration(minutes: 30), StoryOverrun.finish),
      );
    });
  });

  group('StorySession count limit', () {
    test('starts empty', () {
      final s = StorySession(const CountLimit(2));
      expect(s.listened, 0);
      expect(s.current, isNull);
      expect(s.storiesLeft, 2);
      expect(s.timeLeft, isNull);
      expect(s.limitReached, isFalse);
      expect(s.mustStopPlayback, isFalse);
    });

    test('leaving after 59 s does not count', () {
      final s = StorySession(const CountLimit(2))..startStory(story('a'));
      s.advance(const Duration(seconds: 59), playing: true);
      s.finishStory(completed: false);
      expect(s.listened, 0);
      expect(s.storiesLeft, 2);
      expect(s.current, isNull);
    });

    test('leaving after 60 s counts', () {
      final s = StorySession(const CountLimit(2))..startStory(story('a'));
      s.advance(const Duration(seconds: 60), playing: true);
      s.finishStory(completed: false);
      expect(s.listened, 1);
      expect(s.storiesLeft, 1);
    });

    test('a completed story always counts', () {
      final s = StorySession(const CountLimit(2))..startStory(story('a'));
      s.advance(const Duration(seconds: 5), playing: true);
      s.finishStory(completed: true);
      expect(s.listened, 1);
    });

    test('the last story keeps playing until finishStory', () {
      final s = StorySession(const CountLimit(1))..startStory(story('a'));
      s.advance(const Duration(minutes: 20), playing: true);
      expect(s.mustStopPlayback, isFalse);
      expect(s.current, isNotNull);
      s.finishStory(completed: true);
      expect(s.limitReached, isTrue);
      expect(s.storiesLeft, 0);
    });

    test('storiesLeft never goes below zero', () {
      final s = StorySession(const CountLimit(1));
      for (final id in ['a', 'b']) {
        s.startStory(story(id));
        s.finishStory(completed: true);
      }
      expect(s.listened, 2);
      expect(s.storiesLeft, 0);
    });

    test('canPick is always true', () {
      final s = StorySession(const CountLimit(1));
      expect(s.canPick(story('a', sec: 99999)), isTrue);
      expect(s.canPick(story('b')), isTrue);
    });

    test('finishStory without a current story does nothing (ended + dispose may both call it)', () {
      final s = StorySession(const CountLimit(2))..startStory(story('a'));
      s.finishStory(completed: true);
      s.finishStory(completed: true);
      s.finishStory(completed: false);
      expect(s.listened, 1);
      expect(s.storiesLeft, 1);
    });

    test('played time resets for each story', () {
      final s = StorySession(const CountLimit(3))..startStory(story('a'));
      s.advance(const Duration(seconds: 30), playing: true);
      expect(s.currentPlayed, const Duration(seconds: 30));
      s.finishStory(completed: false);
      s.startStory(story('b'));
      expect(s.currentPlayed, Duration.zero);
      expect(s.current!.videoId, story('b').videoId);
    });
  });

  group('StorySession count limit, 60-minute ceiling', () {
    test('ends the sitting at 60 minutes even if no story counted (hopping between stories)', () {
      final s = StorySession(const CountLimit(5));
      s.advance(const Duration(minutes: 59, seconds: 59), playing: false);
      expect(s.limitReached, isFalse);
      expect(s.mustStopPlayback, isFalse);
      s.advance(const Duration(seconds: 1), playing: false);
      expect(storyCountModeCeiling, const Duration(minutes: 60));
      expect(s.listened, 0);
      expect(s.limitReached, isTrue);
      expect(s.mustStopPlayback, isTrue);
    });

    test('cuts a story still playing at the ceiling', () {
      final s = StorySession(const CountLimit(1))..startStory(story('a'));
      s.advance(const Duration(minutes: 60), playing: true);
      expect(s.mustStopPlayback, isTrue);
    });
  });

  group('StorySession time + finish', () {
    StorySession make() => StorySession(const TimeLimit(Duration(minutes: 15), StoryOverrun.finish));

    test('timeLeft counts down and stops at zero', () {
      final s = make();
      expect(s.timeLeft, const Duration(minutes: 15));
      expect(s.storiesLeft, isNull);
      s.advance(const Duration(minutes: 10), playing: false);
      expect(s.timeLeft, const Duration(minutes: 5));
      s.advance(const Duration(minutes: 10), playing: false);
      expect(s.timeLeft, Duration.zero);
    });

    test('elapsed counts time while paused, currentPlayed does not', () {
      final s = make()..startStory(story('a'));
      s.advance(const Duration(seconds: 40), playing: true);
      s.advance(const Duration(seconds: 30), playing: false);
      expect(s.elapsed, const Duration(seconds: 70));
      expect(s.currentPlayed, const Duration(seconds: 40));
      s.finishStory(completed: false);
      expect(s.listened, 0);
    });

    test('canPick allows stories up to timeLeft + 10 minutes', () {
      final s = make();
      expect(s.canPick(story('a', sec: 25 * 60)), isTrue);
      expect(s.canPick(story('b', sec: 25 * 60 + 1)), isFalse);
      s.advance(const Duration(minutes: 10), playing: false);
      expect(s.canPick(story('c', sec: 15 * 60)), isTrue);
      expect(s.canPick(story('d', sec: 15 * 60 + 1)), isFalse);
    });

    test('canPick allows stories of unknown length', () {
      expect(make().canPick(story('a')), isTrue);
    });

    test('limitReached when time is up but playback continues for the overrun', () {
      final s = make()..startStory(story('a'));
      s.advance(const Duration(minutes: 15), playing: true);
      expect(s.limitReached, isTrue);
      expect(s.mustStopPlayback, isFalse);
      s.advance(const Duration(minutes: 9, seconds: 59), playing: true);
      expect(s.mustStopPlayback, isFalse);
      s.advance(const Duration(seconds: 1), playing: true);
      expect(s.mustStopPlayback, isTrue);
    });

    test('limitReached is false before time is up', () {
      final s = make();
      s.advance(const Duration(minutes: 14, seconds: 59), playing: true);
      expect(s.limitReached, isFalse);
    });
  });

  group('StorySession time + stopNow', () {
    StorySession make() => StorySession(const TimeLimit(Duration(minutes: 10), StoryOverrun.stopNow));

    test('mustStopPlayback exactly at the limit', () {
      final s = make()..startStory(story('a'));
      s.advance(const Duration(minutes: 10) - const Duration(seconds: 1), playing: true);
      expect(s.mustStopPlayback, isFalse);
      s.advance(const Duration(seconds: 1), playing: true);
      expect(s.mustStopPlayback, isTrue);
      expect(s.limitReached, isTrue);
    });

    test('canPick ignores story length', () {
      expect(make().canPick(story('a', sec: 99999)), isTrue);
    });
  });

  group('abandonStory', () {
    test('never counts, even after a long play', () {
      final s = StorySession(const CountLimit(2))..startStory(story('a'));
      s.advance(const Duration(minutes: 5), playing: true);
      s.abandonStory();
      expect(s.listened, 0);
      expect(s.current, isNull);
      expect(s.currentPlayed, Duration.zero);
    });

    test('a new story can start afterwards', () {
      final s = StorySession(const CountLimit(2))..startStory(story('a'));
      s.abandonStory();
      s.startStory(story('b'));
      expect(s.current, isNotNull);
    });
  });
}
