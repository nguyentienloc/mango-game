// No Flutter imports: content models are also used by the dart-only tools (tool/gen_voice.dart).
import 'package:meta/meta.dart' show immutable;

/// How many stories can be picked in one session.
const storyCountOptions = [1, 2, 3, 4, 5];

/// Time limits a parent can choose, in minutes.
const storyMinuteOptions = [10, 15, 20, 30, 45, 60];

/// How far past a time limit the last story may run (overrun "finish").
const storyOverrunCap = Duration(minutes: 10);

/// A story counts as listened once it has really played this long.
const storyCountsAfter = Duration(seconds: 60);

/// Fade-out before playback is cut at a time limit (overrun "stopNow").
const storyFadeOut = Duration(seconds: 5);

const _defaultCount = 2;
const _defaultMinutes = 15;

enum StoryTopic {
  fairyVi('fairy_vi', 'Cổ tích Việt Nam'),
  princess('princess', 'Công chúa & Elsa'),
  english('english', 'Truyện tiếng Anh'),
  other('other', 'Khác');

  const StoryTopic(this.id, this.label);

  final String id;
  final String label;

  static StoryTopic? fromId(String id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// A YouTube story: one from the bundled pack, or one a parent added.
@immutable
class Story {
  const Story({
    required this.videoId,
    required this.title,
    required this.topic,
    this.duration,
    this.userAdded = false,
  });

  /// Reads a pack item: `{id, videoId, title, topic, durationSec}`.
  factory Story.fromJson(Map<String, dynamic> j) => Story(
        videoId: j['videoId'] as String,
        title: j['title'] as String,
        topic: StoryTopic.fromId(j['topic'] as String) ?? StoryTopic.other,
        duration: switch (j['durationSec']) {
          final int sec => Duration(seconds: sec),
          _ => null,
        },
      );

  final String videoId;
  final String title;
  final StoryTopic topic;

  /// Null when the length is not known (links parents add themselves).
  final Duration? duration;
  final bool userAdded;

  String get id => 'yt:$videoId';
  String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
}

enum StoryOverrun { finish, stopNow }

enum StoryViewMode { listen, watch }

sealed class StoryLimit {
  const StoryLimit();
}

/// Stop after [stories] stories have been listened to.
@immutable
class CountLimit extends StoryLimit {
  const CountLimit(this.stories);

  final int stories;

  @override
  bool operator ==(Object other) => other is CountLimit && other.stories == stories;

  @override
  int get hashCode => Object.hash('count', stories);
}

/// Stop after [duration] of foreground story time.
@immutable
class TimeLimit extends StoryLimit {
  const TimeLimit(this.duration, this.overrun);

  final Duration duration;
  final StoryOverrun overrun;

  @override
  bool operator ==(Object other) => other is TimeLimit && other.duration == duration && other.overrun == overrun;

  @override
  int get hashCode => Object.hash('time', duration, overrun);
}

/// What the parent chose on the setup screen. Stored as JSON in settings.
@immutable
class StorySetup {
  const StorySetup({
    this.topics = const {},
    this.limit = const CountLimit(_defaultCount),
    this.mode = StoryViewMode.listen,
  });

  /// Reads stored JSON. Anything missing, broken or outside the allowed
  /// options falls back to the default for that part.
  static StorySetup fromJson(Map<String, dynamic> j) {
    final topics = j['topics'];
    final mode = j['mode'];
    return StorySetup(
      topics: {
        if (topics is List)
          for (final id in topics)
            if (id is String && StoryTopic.fromId(id) != null) StoryTopic.fromId(id)!,
      },
      limit: _limitFromJson(j['limit']),
      mode: StoryViewMode.values.where((m) => m.name == mode).firstOrNull ?? StoryViewMode.listen,
    );
  }

  /// Empty means all topics.
  final Set<StoryTopic> topics;
  final StoryLimit limit;
  final StoryViewMode mode;

  Map<String, dynamic> toJson() => {
        'topics': [for (final t in topics) t.id],
        'limit': switch (limit) {
          CountLimit(:final stories) => {'kind': 'count', 'stories': stories},
          TimeLimit(:final duration, :final overrun) => {
              'kind': 'time',
              'minutes': duration.inMinutes,
              'overrun': overrun.name,
            },
        },
        'mode': mode.name,
      };

  @override
  bool operator ==(Object other) =>
      other is StorySetup && other.topics.length == topics.length && other.topics.containsAll(topics) && other.limit == limit && other.mode == mode;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(topics), limit, mode);
}

StoryLimit _limitFromJson(Object? raw) {
  if (raw is! Map) return const CountLimit(_defaultCount);
  switch (raw['kind']) {
    case 'count':
      final n = raw['stories'];
      return CountLimit(n is int && storyCountOptions.contains(n) ? n : _defaultCount);
    case 'time':
      final m = raw['minutes'];
      return TimeLimit(
        Duration(minutes: m is int && storyMinuteOptions.contains(m) ? m : _defaultMinutes),
        StoryOverrun.values.where((o) => o.name == raw['overrun']).firstOrNull ?? StoryOverrun.finish,
      );
    default:
      return const CountLimit(_defaultCount);
  }
}
