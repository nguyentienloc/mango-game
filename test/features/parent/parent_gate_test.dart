import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
import 'package:xoai_castle/features/parent/parent_gate.dart';
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

  int answer(WidgetTester tester) {
    final q = tester.widget<Text>(find.byKey(const Key('parent-gate-question'))).data!;
    final m = RegExp(r'(\d+) \+ (\d+)').firstMatch(q)!;
    return int.parse(m[1]!) + int.parse(m[2]!);
  }

  testWidgets('a short press does not open the gate', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 500));
    expect(find.byType(ParentGateDialog), findsNothing);
  });

  testWidgets('holding 2s and answering correctly opens the parent area', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 2100));
    expect(find.byType(ParentGateDialog), findsOneWidget);

    await tester.enterText(find.byKey(const Key('parent-gate-input')), '${answer(tester)}');
    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(find.byType(ParentScreen), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('Đang dùng bản mới nhất'), findsOneWidget);
  });

  testWidgets('a wrong answer keeps the gate closed and asks again', (tester) async {
    await holdLock(tester, const Duration(milliseconds: 2100));
    final first = answer(tester);
    await tester.enterText(find.byKey(const Key('parent-gate-input')), '${first + 1}');
    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(find.byType(ParentScreen), findsNothing);
    expect(find.text('Chưa đúng, thử lại nhé'), findsOneWidget);
    expect(find.byType(ParentGateDialog), findsOneWidget);
  });
}
