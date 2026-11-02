import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Parent switch: show the 🎈 find-letter game on the home screen.
final showFindLetterProvider = AsyncNotifierProvider<ShowFindLetterController, bool>(ShowFindLetterController.new);

class ShowFindLetterController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(profileStoreProvider).showFindLetter();

  Future<void> set(bool value) async {
    await ref.read(profileStoreProvider).setShowFindLetter(value);
    state = AsyncData(value);
  }
}
