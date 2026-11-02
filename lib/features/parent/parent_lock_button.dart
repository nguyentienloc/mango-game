import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'parent_gate.dart';
import 'parent_screen.dart';

/// Small lock in the corner: hold for 2 seconds to reach the parent gate.
class ParentLockButton extends StatefulWidget {
  const ParentLockButton({super.key, required this.hasUpdate});

  final bool hasUpdate;

  @override
  State<ParentLockButton> createState() => _ParentLockButtonState();
}

class _ParentLockButtonState extends State<ParentLockButton> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _open();
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    _hold.reset();
    final ok = await showParentGate(context);
    if (!ok || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ParentScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const Key('parent-lock'),
      onPointerDown: (_) => _hold.forward(from: 0),
      onPointerUp: (_) => _hold.reset(),
      onPointerCancel: (_) => _hold.reset(),
      child: SizedBox.square(
        dimension: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _hold,
              builder: (context, child) => CircularProgressIndicator(value: _hold.value, color: IceColors.deep),
            ),
            const Text('🔒', style: TextStyle(fontSize: 24)),
            if (widget.hasUpdate)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  key: const Key('update-dot'),
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
