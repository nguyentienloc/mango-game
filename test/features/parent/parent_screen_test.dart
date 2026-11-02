import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xoai_castle/app/providers.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
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
    await tester.pumpWidget(
      testApp(content: content, tts: FakeTts(), home: const ParentScreen(), missingVoices: missing),
    );
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
    await tester.pumpWidget(
      testApp(
        content: content,
        tts: FakeTts(),
        home: const ParentScreen(),
        updateFuture: Completer<UpdateCheck>().future,
      ),
    );
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
    final tts = FakeTts();
    await tester.pumpWidget(
      testApp(content: content, tts: tts, home: const HomeScreen(), rewards: rewards, resetter: resetter),
    );
    await tester.pump();
    expect(find.text('❄️ 50'), findsOneWidget);
    const greeting = 'Chào Xoài! Hôm nay mình chơi gì nào?';
    final greetedBefore = tts.texts.where((t) => t == greeting).length;
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
    expect(tts.texts.where((t) => t == greeting).length, greetedBefore + 1);
  });

  testWidgets('a failing reset shows a message and stays on the parent screen', (tester) async {
    final resetter = FakeProgressResetter()..onReset = () async => throw StateError('db broken');
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const ParentScreen(), resetter: resetter));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Đặt lại dữ liệu game'), 200);
    await tester.tap(find.text('Đặt lại dữ liệu game'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Xóa'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(resetter.calls, 1);
    expect(find.text('Không đặt lại được dữ liệu, thử lại nhé'), findsOneWidget);
    expect(find.byType(ParentScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('voice speed', () {
    Finder sliderIn(String title) =>
        find.descendant(of: find.widgetWithText(ListTile, title), matching: find.byType(Slider));

    testWidgets('two sliders with labels show the stored speeds', (tester) async {
      await tester.pumpWidget(
        testApp(
          content: content,
          tts: FakeTts(),
          home: const ParentScreen(),
          profile: MemoryProfileStore(speeds: const VoiceSpeeds(en: 0.7, vi: 1.25)),
        ),
      );
      await tester.pump();
      await tester.pump();
      final en = tester.widget<Slider>(sliderIn('Tốc độ đọc tiếng Anh'));
      final vi = tester.widget<Slider>(sliderIn('Tốc độ đọc tiếng Việt'));
      expect([en.min, en.max, en.divisions], [0.6, 1.3, 14]);
      expect([vi.min, vi.max, vi.divisions], [0.6, 1.3, 14]);
      expect([en.value, vi.value], [0.7, 1.25]);
      expect(en.label, '0,70×');
      expect(vi.label, '1,25×');
    });

    testWidgets('releasing the English slider saves, applies to the voice and speaks the sample', (tester) async {
      final profile = MemoryProfileStore();
      final tts = FakeTts();
      await tester.pumpWidget(testApp(content: content, tts: tts, home: const ParentScreen(), profile: profile));
      await tester.pump();
      await tester.pump();
      // The centre of the slider is the middle of 0.6..1.3, i.e. 0.95.
      await tester.tap(sliderIn('Tốc độ đọc tiếng Anh'));
      await tester.pump();
      await tester.pump();
      expect(profile.speeds.en, closeTo(0.95, 1e-9));
      expect(profile.speeds.vi, 1.0);
      final container = ProviderScope.containerOf(tester.element(find.byType(ParentScreen)));
      expect(container.read(voiceProvider).speeds.en, closeTo(0.95, 1e-9));
      expect(tts.spoken.last, (text: 'Find the lion!', lang: 'en'));
      expect(tts.speeds.last, closeTo(0.95, 1e-9));
    });

    testWidgets('releasing the Vietnamese slider speaks the greeting', (tester) async {
      final profile = MemoryProfileStore();
      final tts = FakeTts();
      await tester.pumpWidget(testApp(content: content, tts: tts, home: const ParentScreen(), profile: profile));
      await tester.pump();
      await tester.pump();
      await tester.tap(sliderIn('Tốc độ đọc tiếng Việt'));
      await tester.pump();
      await tester.pump();
      expect(profile.speeds.vi, closeTo(0.95, 1e-9));
      expect(profile.speeds.en, 0.85);
      expect(tts.spoken.last, (text: 'Chào Xoài! Hôm nay mình chơi gì nào?', lang: 'vi'));
      expect(tts.speeds.last, closeTo(0.95, 1e-9));
    });

    testWidgets('Mặc định puts both speeds back to 0.85 / 1.0', (tester) async {
      final profile = MemoryProfileStore(speeds: const VoiceSpeeds(en: 0.7, vi: 1.25));
      final tts = FakeTts();
      await tester.pumpWidget(testApp(content: content, tts: tts, home: const ParentScreen(), profile: profile));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Mặc định'));
      await tester.pump();
      await tester.pump();
      expect(profile.speeds, const VoiceSpeeds());
      expect(tester.widget<Slider>(sliderIn('Tốc độ đọc tiếng Anh')).value, 0.85);
      expect(tester.widget<Slider>(sliderIn('Tốc độ đọc tiếng Việt')).value, 1.0);
      expect(tts.spoken.last, (text: 'Find the lion!', lang: 'en'));
      expect(tts.speeds.last, 0.85);
    });
  });
}
