import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rewards/reward_rules.dart';
import '../core/rewards/reward_state.dart';
import '../core/time.dart';
import 'providers.dart';

final rewardStateProvider = AsyncNotifierProvider<RewardController, RewardState>(RewardController.new);

class RewardController extends AsyncNotifier<RewardState> {
  @override
  Future<RewardState> build() => ref.watch(rewardStoreProvider).load();

  Future<RewardOutcome> completeRound(int firstTryCorrect) async {
    final current = state.value ?? await future;
    final outcome = applyRound(
      current,
      firstTryCorrect: firstTryCorrect,
      today: dayKey(ref.read(clockProvider)()),
      levels: ref.read(contentProvider).castle,
    );
    await ref.read(rewardStoreProvider).save(outcome.state);
    state = AsyncData(outcome.state);
    return outcome;
  }
}
