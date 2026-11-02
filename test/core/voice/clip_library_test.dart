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
  const lion = Utterance([UtterancePart('en', 'Lion!'), UtterancePart('vi', 'Con sư tử!')]);

  test('finds the asset for a known utterance', () {
    final lib = ClipLibrary.parse('{"clips": {"en|Lion! || vi|Con sư tử!": "abc.ogg"}}');
    expect(lib.assetFor(lion), 'content/audio/abc.ogg');
    expect(lib.assetFor(const Utterance([UtterancePart('en', 'Cat!')])), isNull);
    expect(lib.length, 1);
  });

  test('a missing or broken index gives an empty library', () async {
    expect((await ClipLibrary.load(_Source(null))).length, 0);
    expect((await ClipLibrary.load(_Source('{oops'))).length, 0);
  });

  test('an index with a non-string value gives an empty library', () async {
    expect((await ClipLibrary.load(_Source('{"clips": {"en|Hi": 5}}'))).length, 0);
  });
}
