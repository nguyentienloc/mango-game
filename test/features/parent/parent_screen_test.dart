import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';
import 'package:xoai_castle/features/home/home_screen.dart';
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

  testWidgets('the find-letter switch is off by default and saves when toggled', (tester) async {
    final profile = MemoryProfileStore();
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const ParentScreen(), profile: profile));
    await tester.pump();
    final tile = find.widgetWithText(SwitchListTile, 'Hiện trò Tìm chữ cái');
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pump();
    expect(profile.show, isTrue);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });

  testWidgets('reset asks for confirmation; cancel keeps data', (tester) async {
    final resetter = FakeProgressResetter();
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const ParentScreen(), resetter: resetter));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Đặt lại dữ liệu game'), 200);
    await tester.tap(find.text('Đặt lại dữ liệu game'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Xóa toàn bộ tiến độ của Xoài? Không khôi phục được.'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(resetter.calls, 0);
  });

  testWidgets('confirming reset clears progress and refreshes the snowflakes', (tester) async {
    final rewards = MemoryRewardStore(const RewardState(snowflakesTotal: 50, castleLevel: 3));
    final resetter = FakeProgressResetter()..onReset = () async => rewards.state = const RewardState();
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const HomeScreen(), rewards: rewards, resetter: resetter));
    await tester.pump();
    expect(find.text('❄️ 50'), findsOneWidget);
    Navigator.of(tester.element(find.byType(HomeScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const ParentScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text('Đặt lại dữ liệu game'), 200);
    await tester.tap(find.text('Đặt lại dữ liệu game'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Xóa'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(resetter.calls, 1);
    expect(find.byType(ParentScreen), findsNothing);
    expect(find.text('❄️ 0'), findsOneWidget);
  });
}
