import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/parent/parent_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> holdLock(WidgetTester tester, Duration duration) async {
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const HomeScreen()));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('parent-lock'))));
    await tester.pump(Duration.zero); // ticker needs a first frame to set its start time
    await tester.pump(duration);
    await gesture.up();
    await settle(tester);
  }

  testWidgets('a short press does not open the parent area', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 500));
    expect(find.byType(ParentScreen), findsNothing);
  });

  testWidgets('holding 2s and releasing does not open it', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 2000));
    expect(find.byType(ParentScreen), findsNothing);
  });

  testWidgets('holding 3.1s opens the parent area directly, with no question', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 3100));

    expect(find.byType(ParentScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('Đang dùng bản mới nhất'), findsOneWidget);
  });

  testWidgets('releasing resets the progress ring', (tester) async {
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const HomeScreen()));
    await tester.pump();
    double ring() => tester.widget<CircularProgressIndicator>(find.descendant(of: find.byKey(const Key('parent-lock')), matching: find.byType(CircularProgressIndicator))).value!;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('parent-lock'))));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(ring(), closeTo(0.5, 0.05));
    await gesture.up();
    await tester.pump();
    expect(ring(), 0.0);
  });
}
