import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Endless decorative animations. Off in widget tests, so `pumpAndSettle` can settle.
final animationsEnabledProvider = Provider<bool>((ref) => true);

/// The snow falling over the whole app; follows [animationsEnabledProvider] by default.
final snowfallEnabledProvider = Provider<bool>((ref) => ref.watch(animationsEnabledProvider));

/// True while something wants the snow to hold still (a story video is playing). The
/// snow stops its clock completely, so no frames are drawn for it, and goes on after.
/// A plain [ValueNotifier] so a screen may set it from any lifecycle method.
final snowfallPausedProvider = Provider<ValueNotifier<bool>>((ref) {
  final paused = ValueNotifier(false);
  ref.onDispose(paused.dispose);
  return paused;
});
