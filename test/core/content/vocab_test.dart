import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/vocab.dart';
import 'package:xoai_castle/features/story/story_models.dart';

import '../../support/content_fixture.dart';

void main() {
  test('vocabVars capitalises the first letter of word and vi', () {
    const w = VocabItem(id: 'lion', word: 'lion', vi: 'con sư tử', emoji: '🦁', topic: 'animals');
    expect(vocabVars(w), {'word': 'lion', 'Word': 'Lion', 'vi': 'con sư tử', 'Vi': 'Con sư tử'});
  });

  test('the shipped content has 45 vocabulary words with images', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.vocab, hasLength(45));
    expect(bundle.vocab.map((w) => w.id).toSet(), hasLength(45));
    expect(bundle.vocab.map((w) => w.topic).toSet(), {'animals', 'fruits', 'vegetables', 'vehicles'});
    final lion = bundle.vocab.firstWhere((w) => w.id == 'lion');
    expect(lion.vi, 'con sư tử');
    expect(lion.image, 'images/vocab/lion.png');
  });

  test('ContentBundle.fromFiles reads the stories pack', () {
    final stories = ContentBundle.fromFiles(validFiles()).stories;
    expect(stories.map((s) => s.id), ['yt:aaaaaaaaaaa', 'yt:bbbbbbbbbbb']);
    expect(stories.first.topic, StoryTopic.fairyVi);
    expect(stories.first.duration, const Duration(minutes: 10));
    expect(stories.first.userAdded, isFalse);
  });

  test('the shipped stories pack loads (it may still be empty)', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.stories, isA<List<Story>>());
  });

  test('the shipped content has 8 conversation items', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.conversation, hasLength(8));
    final name = bundle.conversation.first;
    expect(name.id, 'name');
    expect(name.accept.first, ['name', 'an']);
    // "and" is only accepted after "name", never as a lone alias of "an".
    expect(name.aliases['an'], isNot(contains('and')));
    expect(name.accept, anyElement(equals(['name', 'and'])));
    expect(bundle.conversation.last.aliases['thank'], contains('tank'));
  });
}
