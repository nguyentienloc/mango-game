import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/features/parent/parent_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<void> pumpParent(WidgetTester tester, {Set<String> missing = const {}}) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: FakeTts(),
      home: const ParentScreen(),
      missingVoices: missing,
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('warns when the Vietnamese voice is missing', (tester) async {
    await pumpParent(tester, missing: {'vi-VN'});
    expect(find.text('Máy chưa có giọng đọc: Tiếng Việt'), findsOneWidget);
    expect(find.textContaining('Chuyển văn bản thành giọng nói'), findsOneWidget);
  });

  testWidgets('lists every missing voice', (tester) async {
    await pumpParent(tester, missing: {'vi-VN', 'en-US'});
    expect(find.text('Máy chưa có giọng đọc: Tiếng Việt, Tiếng Anh'), findsOneWidget);
  });

  testWidgets('shows no voice warning when voices are installed', (tester) async {
    await pumpParent(tester);
    expect(find.textContaining('Máy chưa có giọng đọc'), findsNothing);
  });

  testWidgets('the checking tile has a retry button', (tester) async {
    await tester.pumpWidget(testApp(
      content: content,
      tts: FakeTts(),
      home: const ParentScreen(),
      updateFuture: Completer<UpdateCheck>().future,
    ));
    await tester.pump();
    expect(find.text('Đang kiểm tra cập nhật…'), findsOneWidget);
    expect(find.text('Kiểm tra lại'), findsOneWidget);
  });
}
