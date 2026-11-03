import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/db/database.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/stories/story_store.dart';
import 'package:xoai_castle/features/story/story_models.dart';

const _a = Story(
  videoId: 'aaaaaaaaaaa',
  title: 'Tấm Cám',
  topic: StoryTopic.fairyVi,
  duration: Duration(minutes: 8),
  userAdded: true,
);
const _b = Story(videoId: 'bbbbbbbbbbb', title: 'Elsa', topic: StoryTopic.princess, userAdded: true);

void _suite(String name, Future<StoryStore> Function() make) {
  group(name, () {
    test('starts empty with default setup', () async {
      final s = await make();
      expect(await s.userStories(), isEmpty);
      expect(await s.hiddenIds(), isEmpty);
      expect(await s.lastSetup(), const StorySetup());
    });

    test('adds user stories in the order they were added, all userAdded', () async {
      final s = await make();
      await s.addUserStory(_a);
      await s.addUserStory(_b);
      final list = await s.userStories();
      expect(list.map((x) => x.videoId), ['aaaaaaaaaaa', 'bbbbbbbbbbb']);
      expect(list.every((x) => x.userAdded), isTrue);
      expect(list.first.title, 'Tấm Cám');
      expect(list.first.topic, StoryTopic.fairyVi);
      expect(list.first.duration, const Duration(minutes: 8));
      expect(list.last.duration, isNull);
    });

    test('adding the same videoId again updates it in place', () async {
      final s = await make();
      await s.addUserStory(_a);
      await s.addUserStory(_b);
      await s.addUserStory(
        const Story(videoId: 'aaaaaaaaaaa', title: 'Mới', topic: StoryTopic.english, userAdded: true),
      );
      final list = await s.userStories();
      expect(list, hasLength(2));
      final a = list.firstWhere((x) => x.videoId == 'aaaaaaaaaaa');
      expect([a.title, a.topic], ['Mới', StoryTopic.english]);
    });

    test('deletes a user story; deleting an unknown one is harmless', () async {
      final s = await make();
      await s.addUserStory(_a);
      await s.deleteUserStory('aaaaaaaaaaa');
      await s.deleteUserStory('nope');
      expect(await s.userStories(), isEmpty);
    });

    test('deleting a user story also forgets that it was hidden', () async {
      final s = await make();
      await s.addUserStory(_a);
      await s.setHidden(_a.id, true);
      await s.setHidden('yt:other', true);
      await s.deleteUserStory(_a.videoId);
      expect(await s.hiddenIds(), {'yt:other'});
    });

    test('hides and shows again', () async {
      final s = await make();
      await s.setHidden('yt:x', true);
      await s.setHidden('yt:y', true);
      await s.setHidden('yt:x', true);
      expect(await s.hiddenIds(), {'yt:x', 'yt:y'});
      await s.setHidden('yt:x', false);
      expect(await s.hiddenIds(), {'yt:y'});
    });

    test('saves and reads the setup', () async {
      final s = await make();
      const setup = StorySetup(
        topics: {StoryTopic.fairyVi, StoryTopic.english},
        limit: TimeLimit(Duration(minutes: 30), StoryOverrun.stopNow),
        mode: StoryViewMode.watch,
      );
      await s.saveSetup(setup);
      expect(await s.lastSetup(), setup);
    });
  });
}

void main() {
  _suite('MemoryStoryStore', () async => MemoryStoryStore());
  _suite('DriftStoryStore', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // The app creates the profile row at start-up; the setup lives in it.
    await DriftProfileStore(db).loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
    return DriftStoryStore(db);
  });

  group('DriftStoryStore setup', () {
    test('broken JSON falls back to the default setup', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await DriftProfileStore(db).loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
      await db.customStatement("UPDATE profile SET story_setup = '{not json'");
      expect(await DriftStoryStore(db).lastSetup(), const StorySetup());
      await db.customStatement("UPDATE profile SET story_setup = '[1,2]'");
      expect(await DriftStoryStore(db).lastSetup(), const StorySetup());
    });

    test('saving the setup before the profile row exists does not create a nameless profile', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftStoryStore(db);
      await store.saveSetup(const StorySetup(mode: StoryViewMode.watch));
      expect(await store.lastSetup(), const StorySetup());
      final names = await DriftProfileStore(db)
          .loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
      expect(names.vi, 'Xoài');
    });
  });
}
