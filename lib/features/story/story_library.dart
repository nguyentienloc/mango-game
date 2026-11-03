import 'story_models.dart';

/// The stories a parent can choose from: the bundled pack plus the ones they added.
class StoryLibrary {
  StoryLibrary({required List<Story> bundled, required List<Story> user, required Set<String> hidden})
    // ignore: prefer_initializing_formals
    : _hidden = hidden,
      all = [
        ...bundled,
        for (final u in user)
          if (!bundled.any((b) => b.videoId == u.videoId)) u,
      ];

  final Set<String> _hidden;

  /// Bundled first, then user stories; a user story that is also bundled is dropped.
  final List<Story> all;

  bool isHidden(Story s) => _hidden.contains(s.id);

  /// Not hidden, in [topics] (empty = every topic).
  List<Story> visible({Set<StoryTopic> topics = const {}}) => [
    for (final s in all)
      if (!isHidden(s) && (topics.isEmpty || topics.contains(s.topic))) s,
  ];

  /// Topics that have at least one visible story.
  Set<StoryTopic> get topicsWithStories => {for (final s in visible()) s.topic};
}
