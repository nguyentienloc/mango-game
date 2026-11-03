import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/story/story_models.dart';
import '../db/database.dart';

abstract interface class StoryStore {
  /// Stories a parent added (userAdded: true), oldest first.
  Future<List<Story>> userStories();

  /// Adds the story, or replaces the one with the same videoId (keeps its place in the list).
  Future<void> addUserStory(Story s);

  Future<void> deleteUserStory(String videoId);

  /// [Story.id] values the parent hid.
  Future<Set<String>> hiddenIds();

  Future<void> setHidden(String storyId, bool hidden);

  /// The last setup; defaults when none was saved or the stored JSON is broken.
  Future<StorySetup> lastSetup();

  Future<void> saveSetup(StorySetup s);
}

class DriftStoryStore implements StoryStore {
  DriftStoryStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<Story>> userStories() async {
    final rows = await (_db.select(_db.userStories)..orderBy([(t) => OrderingTerm.asc(t.addedAt)])).get();
    return [
      for (final r in rows)
        Story(
          videoId: r.videoId,
          title: r.title,
          topic: StoryTopic.fromId(r.topic) ?? StoryTopic.other,
          duration: r.durationSec == null ? null : Duration(seconds: r.durationSec!),
          userAdded: true,
        ),
    ];
  }

  @override
  Future<void> addUserStory(Story s) => _db.transaction(() async {
    final existing = await (_db.select(_db.userStories)..where((t) => t.videoId.equals(s.videoId))).getSingleOrNull();
    await _db
        .into(_db.userStories)
        .insertOnConflictUpdate(
          UserStoriesCompanion.insert(
            videoId: s.videoId,
            title: s.title,
            topic: s.topic.id,
            durationSec: Value(s.duration?.inSeconds),
            addedAt: existing?.addedAt ?? DateTime.now(),
          ),
        );
  });

  @override
  Future<void> deleteUserStory(String videoId) async {
    await (_db.delete(_db.userStories)..where((t) => t.videoId.equals(videoId))).go();
  }

  @override
  Future<Set<String>> hiddenIds() async => {for (final r in await _db.select(_db.hiddenStories).get()) r.storyId};

  @override
  Future<void> setHidden(String storyId, bool hidden) async {
    if (hidden) {
      await _db.into(_db.hiddenStories).insertOnConflictUpdate(HiddenStoriesCompanion.insert(storyId: storyId));
    } else {
      await (_db.delete(_db.hiddenStories)..where((t) => t.storyId.equals(storyId))).go();
    }
  }

  @override
  Future<StorySetup> lastSetup() async {
    final row = await (_db.select(_db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();
    final raw = row?.storySetup;
    if (raw == null) return const StorySetup();
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? StorySetup.fromJson(json) : const StorySetup();
    } on FormatException {
      return const StorySetup();
    }
  }

  /// Needs the profile row, which the app creates at start-up; without it nothing is saved.
  @override
  Future<void> saveSetup(StorySetup s) async {
    await (_db.update(
      _db.profile,
    )..where((t) => t.id.equals(1))).write(ProfileCompanion(storySetup: Value(jsonEncode(s.toJson()))));
  }
}

/// In-memory store for tests.
class MemoryStoryStore implements StoryStore {
  final _user = <String, Story>{};
  final _hidden = <String>{};
  StorySetup _setup = const StorySetup();

  @override
  Future<List<Story>> userStories() async => [..._user.values];

  @override
  Future<void> addUserStory(Story s) async => _user[s.videoId] = s;

  @override
  Future<void> deleteUserStory(String videoId) async => _user.remove(videoId);

  @override
  Future<Set<String>> hiddenIds() async => {..._hidden};

  @override
  Future<void> setHidden(String storyId, bool hidden) async => hidden ? _hidden.add(storyId) : _hidden.remove(storyId);

  @override
  Future<StorySetup> lastSetup() async => _setup;

  @override
  Future<void> saveSetup(StorySetup s) async => _setup = s;
}
