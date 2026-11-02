import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/games/find_letter/example_card.dart';
import 'package:xoai_castle/shared/character_view.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  testWidgets('a character with a missing image file falls back to its emoji', (tester) async {
    final withImage = ContentBundle(
      lettersEn: content.lettersEn,
      phrases: content.phrases,
      castle: content.castle,
      characters: {'olaf': const CharacterDef(id: 'olaf', name: 'Olaf', emoji: '⛄', image: 'missing/olaf.png')},
      profileDefaults: content.profileDefaults,
    );
    await tester.pumpWidget(testApp(content: withImage, tts: FakeTts(), home: const CharacterView(id: 'olaf')));
    await tester.pump();
    await tester.pump();
    expect(find.text('⛄'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an example card with a missing image file falls back to the emoji', (tester) async {
    const item = LetterItem(char: 'A', exampleWord: 'Apple', exampleEmoji: '🍎', exampleImage: 'missing/apple.png');
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const ExampleCard(item: item)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('🍎'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
