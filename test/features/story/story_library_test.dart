import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/story/story_library.dart';
import 'package:xoai_castle/features/story/story_models.dart';

Story _s(String id, StoryTopic t, {bool user = false}) => Story(videoId: id, title: 'T $id', topic: t, userAdded: user);

void main() {
  final tam = _s('aaaaaaaaaaa', StoryTopic.fairyVi);
  final elsa = _s('bbbbbbbbbbb', StoryTopic.princess);
  final bed = _s('ccccccccccc', StoryTopic.english);
  final mine = _s('ddddddddddd', StoryTopic.other, user: true);

  test('all lists bundled first, then user stories', () {
    final lib = StoryLibrary(bundled: [tam, elsa], user: [mine], hidden: const {});
    expect(lib.all.map((s) => s.videoId), ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ddddddddddd']);
  });

  test('a user story with the same videoId as a bundled one is dropped', () {
    final dup = _s('aaaaaaaaaaa', StoryTopic.other, user: true);
    final lib = StoryLibrary(bundled: [tam], user: [dup, mine], hidden: const {});
    expect(lib.all, [tam, mine]);
    expect(lib.all.first.userAdded, isFalse);
  });

  test('visible drops hidden stories', () {
    final lib = StoryLibrary(bundled: [tam, elsa], user: [mine], hidden: {elsa.id});
    expect(lib.visible().map((s) => s.videoId), ['aaaaaaaaaaa', 'ddddddddddd']);
    expect(lib.isHidden(elsa), isTrue);
    expect(lib.isHidden(tam), isFalse);
    expect(lib.all, hasLength(3));
  });

  test('visible filters by topic; empty set means all', () {
    final lib = StoryLibrary(bundled: [tam, elsa, bed], user: [mine], hidden: const {});
    expect(lib.visible(topics: {StoryTopic.princess, StoryTopic.english}).map((s) => s.videoId), [
      'bbbbbbbbbbb',
      'ccccccccccc',
    ]);
    expect(lib.visible(topics: const {}), hasLength(4));
  });

  test('topicsWithStories only counts topics with a visible story', () {
    final lib = StoryLibrary(bundled: [tam, elsa, bed], user: [mine], hidden: {elsa.id});
    expect(lib.topicsWithStories, {StoryTopic.fairyVi, StoryTopic.english, StoryTopic.other});
  });

  test('empty library has no topics and nothing visible', () {
    final lib = StoryLibrary(bundled: const [], user: const [], hidden: const {});
    expect(lib.visible(), isEmpty);
    expect(lib.topicsWithStories, isEmpty);
  });

  test('all cannot be changed from outside', () {
    final lib = StoryLibrary(bundled: [tam], user: const [], hidden: const {});
    expect(() => lib.all.add(elsa), throwsUnsupportedError);
  });
}
