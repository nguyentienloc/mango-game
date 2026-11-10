import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';

import '../../support/content_fixture.dart';

class MapContentSource implements ContentSource {
  MapContentSource(this.files);
  final Map<String, String> files;

  @override
  Future<String> readText(String path) async => files[path] ?? (throw StateError('missing $path'));
}

void main() {
  test('loads a bundle from valid files', () async {
    final bundle = await ContentRepository(MapContentSource(validFiles())).load();
    expect(bundle.lettersEn.map((l) => l.char), ['A', 'B']);
    expect(bundle.lettersEn.first.exampleEmoji, '🍎');
    expect(bundle.lettersEn.first.lower, 'a');
    expect(bundle.lettersVi.map((l) => l.char), ['A', 'Ă']);
    expect(bundle.lettersVi.map((l) => l.spoken), ['a', 'á']);
    expect(bundle.digits.map((l) => l.char), [for (var d = 0; d < 10; d++) '$d']);
    expect(bundle.digits.first.strokes, isNotEmpty);
    expect(bundle.phrases['try_again_vi_1']!.allParts.single.lang, 'vi');
    expect(bundle.castle.map((l) => l.snowflakes), [0, 20]);
    expect(bundle.castle[1].friend, 'olaf');
    expect(bundle.characters['olaf']!.emoji, '⛄');
    expect(bundle.characters['elsa']!.image, isNull);
    expect(bundle.profileDefaults.nameVi, 'Xoài');
    expect(bundle.profileDefaults.dailyLimitMin, 20);
  });

  test('throws ContentException listing errors for invalid content', () async {
    final files = {...validFiles(), 'castle.json': '{oops'};
    expect(
      () => ContentRepository(MapContentSource(files)).load(),
      throwsA(isA<ContentException>().having((e) => e.errors.single, 'error', startsWith('castle.json'))),
    );
  });

  test('loads the shipped content directory', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.lettersEn, hasLength(26));
    expect(bundle.digits, hasLength(10));
    expect(bundle.castle, hasLength(8));
  });
}
