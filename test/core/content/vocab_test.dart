import 'dart:io';

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

  test('the shipped content has 71 vocabulary words in 6 topics, each with an image', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.vocab, hasLength(71));
    expect(bundle.vocab.map((w) => w.id).toSet(), hasLength(71));
    final byTopic = <String, int>{};
    for (final w in bundle.vocab) {
      byTopic[w.topic] = (byTopic[w.topic] ?? 0) + 1;
    }
    expect(byTopic, {'christmas': 12, 'toys': 12, 'food': 12, 'body': 11, 'clothes': 12, 'nature': 12});
    for (final w in bundle.vocab) {
      expect(w.image, 'images/vocab/${w.id}.png', reason: w.id);
      expect(File('content/${w.image}').existsSync(), isTrue, reason: w.id);
    }
    final tree = bundle.vocab.firstWhere((w) => w.id == 'christmas_tree');
    expect(tree.word, 'Christmas tree');
    expect(tree.vi, 'cây thông Noel');
  });

  test('only shipped words have a picture file', () {
    final files = Directory('content/images/vocab').listSync().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.png'));
    expect(files, hasLength(71));
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

  test('the shipped content has 18 conversation items', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.conversation, hasLength(18));
    final name = bundle.conversation.first;
    expect(name.id, 'name');
    expect(name.accept.first, ['name', 'an']);
    // "and" is only accepted after "name", never as a lone alias of "an".
    expect(name.aliases['an'], isNot(contains('and')));
    expect(name.accept, anyElement(equals(['name', 'and'])));
    final byId = {for (final i in bundle.conversation) i.id: i};
    expect(byId['thank_you']!.aliases['thank'], contains('tank'));
    expect(byId['what_tree']!.image, 'christmas_tree');
    expect(byId['what_gift']!.image, 'gift');
    expect(byId['how_many_stars']!.emojiRow, '⭐⭐⭐');
    expect(byId['name']!.image, isNull);
    expect(byId['name']!.emojiRow, isNull);
  });
}
