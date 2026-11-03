import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Big round push-to-talk button: hold to listen, let go to stop. Holding past
/// [maxHold] stops by itself. While [enabled] is false (Elsa is talking or an
/// answer is being judged) it is dimmed and ignores touches.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.enabled,
    this.waiting = false,
    required this.onHoldStart,
    required this.onHoldEnd,
    this.maxHold = const Duration(seconds: 8),
  });

  static const size = 130.0;

  final bool enabled;

  /// The hold is over and the answer is being worked out: shows a spinner ring.
  final bool waiting;
  final VoidCallback onHoldStart;

  /// Called once per hold: on release, on auto-stop, or when the button gets locked.
  final VoidCallback onHoldEnd;
  final Duration maxHold;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Timer? _limit;
  bool _holding = false;

  /// The finger that owns the current hold: only its up/cancel ends it.
  int? _owner;

  /// Fingers that went down while the button could not start a hold; if one is
  /// still down when the button unlocks, the hold starts then.
  final Set<int> _waitingPointers = {};

  void _onDown(int pointer) {
    if (_holding) return; // a second finger never joins or steals a hold
    if (!widget.enabled) {
      _waitingPointers.add(pointer);
      return;
    }
    _begin(pointer);
  }

  void _begin(int pointer) {
    _owner = pointer;
    _waitingPointers.remove(pointer);
    setState(() => _holding = true);
    _wave.repeat();
    _limit = Timer(widget.maxHold, _end);
    widget.onHoldStart();
  }

  void _onUpOrCancel(int pointer) {
    _waitingPointers.remove(pointer);
    if (pointer == _owner) _end();
  }

  void _end() {
    if (!_holding) return;
    _limit?.cancel();
    _wave.stop();
    _owner = null;
    setState(() => _holding = false);
    widget.onHoldEnd();
  }

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _holding) {
      // Defer: onHoldEnd may call setState on the parent while it is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _end();
      });
    } else if (widget.enabled && !old.enabled && !_holding && _waitingPointers.isNotEmpty) {
      // The child pressed early and is still holding: start now.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _holding || !widget.enabled || _waitingPointers.isEmpty) return;
        _begin(_waitingPointers.first);
      });
    }
  }

  @override
  void dispose() {
    _limit?.cancel();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const box = MicButton.size * 1.4;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _onDown(e.pointer),
      onPointerUp: (e) => _onUpOrCancel(e.pointer),
      onPointerCancel: (e) => _onUpOrCancel(e.pointer),
      child: SizedBox(
        width: box,
        height: box,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: widget.enabled || widget.waiting ? 1 : 0.45,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_holding)
                    AnimatedBuilder(
                      animation: _wave,
                      builder: (context, _) => Container(
                        width: MicButton.size * (1 + 0.4 * _wave.value),
                        height: MicButton.size * (1 + 0.4 * _wave.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: IceColors.frost.withValues(alpha: 0.6 * (1 - _wave.value)),
                        ),
                      ),
                    ),
                  Container(
                    width: MicButton.size,
                    height: MicButton.size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Colors.white, _holding ? IceColors.glow : IceColors.frost]),
                      boxShadow: [BoxShadow(color: IceColors.deep.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: const Text('🎤', style: TextStyle(fontSize: MicButton.size * 0.5)),
                  ),
                ],
              ),
            ),
            if (widget.waiting)
              const SizedBox(
                key: Key('mic-waiting'),
                width: MicButton.size + 16,
                height: MicButton.size + 16,
                child: CircularProgressIndicator(strokeWidth: 8, color: IceColors.deep),
              ),
          ],
        ),
      ),
    );
  }
}
