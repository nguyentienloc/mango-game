import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on (while a story plays).
abstract interface class ScreenAwake {
  Future<void> enable();

  Future<void> disable();
}

class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  // A failing wakelock only means the screen may dim; never break the story for it.
  @override
  Future<void> enable() => WakelockPlus.enable().catchError((Object e) => debugPrint('Wakelock on failed: $e'));

  @override
  Future<void> disable() => WakelockPlus.disable().catchError((Object e) => debugPrint('Wakelock off failed: $e'));
}
