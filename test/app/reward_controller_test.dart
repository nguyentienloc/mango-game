import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/app/providers.dart';
import 'package:xoai_castle/app/reward_controller.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';

import '../support/fakes.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  test('completeRound applies rules, saves and updates state', () async {
    final store = MemoryRewardStore();
    final container = ProviderContainer(overrides: [
      contentProvider.overrideWithValue(content),
      rewardStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 9)),
    ]);
    addTearDown(container.dispose);

    await container.read(rewardStateProvider.future);
    final outcome = await container.read(rewardStateProvider.notifier).completeRound(6);

    expect(outcome.earned, 11);
    expect(store.state.snowflakesTotal, 11);
    expect(store.state.dailyQuestDate, '2026-11-02');
    expect(container.read(rewardStateProvider).value!.snowflakesTotal, 11);
  });
}
