import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/voice/clip_library.dart';
import 'package:xoai_castle/core/voice/utterance.dart';

class _Source implements ContentSource {
  _Source(this.text);
  final String? text;
  @override
  Future<String> readText(String path) async => text ?? (throw StateError('missing'));
}

void main() {
  test('finds the asset for a known part by lang|text', () {
    final lib = ClipLibrary.parse('{"clips": {"en|Lion!": "abc.ogg", "vi|Con sư tử!": "def.ogg"}}');
    expect(lib.assetFor(const UtterancePart('en', 'Lion!')), 'content/audio/abc.ogg');
    expect(lib.assetFor(const UtterancePart('vi', 'Con sư tử!')), 'content/audio/def.ogg');
    expect(lib.assetFor(const UtterancePart('en', 'Cat!')), isNull);
    expect(lib.assetFor(const UtterancePart('vi', 'Lion!')), isNull, reason: 'language is part of the key');
    expect(lib.length, 2);
  });

  test('part key is lang|text and joins into the utterance key', () {
    expect(const UtterancePart('en', 'Lion!').key, 'en|Lion!');
    expect(const Utterance([UtterancePart('en', 'Lion!'), UtterancePart('vi', 'Sư tử!')]).key, 'en|Lion! || vi|Sư tử!');
  });

  test('a missing or broken index gives an empty library', () async {
    expect((await ClipLibrary.load(_Source(null))).length, 0);
    expect((await ClipLibrary.load(_Source('{oops'))).length, 0);
  });

  test('an index with a non-string value gives an empty library', () async {
    expect((await ClipLibrary.load(_Source('{"clips": {"en|Hi": 5}}'))).length, 0);
  });
}
