import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Endless decorative animations (the sky's twinkle). Off in widget tests, so
/// `pumpAndSettle` can settle.
final animationsEnabledProvider = Provider<bool>((ref) => true);

/// The snow falling over the whole app; follows [animationsEnabledProvider] by default.
final snowfallEnabledProvider = Provider<bool>((ref) => ref.watch(animationsEnabledProvider));
