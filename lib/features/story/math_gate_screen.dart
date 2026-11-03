import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'math_gate_logic.dart';

/// A sum only a grown-up can solve before story time. Silent (it is for the
/// parent); the right answer replaces this screen with [onPassed], a wrong one
/// buzzes, flashes red and brings a new sum — after [maxWrong] wrong answers in
/// a row it goes back home instead (no guessing by trial). Nothing is
/// remembered: every visit asks again.
class MathGateScreen extends ConsumerStatefulWidget {
  const MathGateScreen({super.key, required this.onPassed});

  final WidgetBuilder onPassed;

  static const maxWrong = 3;

  @override
  ConsumerState<MathGateScreen> createState() => _MathGateScreenState();
}

class _MathGateScreenState extends ConsumerState<MathGateScreen> {
  static const _wrongFor = Duration(milliseconds: 600);

  late MathProblem _problem = MathProblem.random(ref.read(randomProvider));
  String _input = '';
  bool _wrong = false;
  bool _passed = false;
  int _wrongInRow = 0;
  Timer? _wrongTimer;

  @override
  void dispose() {
    _wrongTimer?.cancel();
    super.dispose();
  }

  void _digit(int d) {
    if (_wrong || _passed) return;
    final answer = '${_problem.answer}';
    if (_input.length >= answer.length) return;
    setState(() => _input += '$d');
    if (_input.length < answer.length) return;
    if (_input == answer) {
      _passed = true;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: widget.onPassed));
    } else {
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _wrong = true);
      _wrongInRow++;
      _wrongTimer = Timer(_wrongFor, _wrongInRow >= MathGateScreen.maxWrong ? _giveUp : _nextProblem);
    }
  }

  void _back() {
    if (_wrong || _passed || _input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _giveUp() {
    if (mounted) Navigator.of(context).pop();
  }

  void _nextProblem() {
    if (!mounted) return;
    final random = ref.read(randomProvider);
    var next = MathProblem.random(random);
    while (next.a == _problem.a && next.b == _problem.b) {
      next = MathProblem.random(random);
    }
    setState(() {
      _problem = next;
      _input = '';
      _wrong = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nghe chuyện')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  const Text('Bố mẹ giải phép tính để mở nhé', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 12),
                  Text(
                    '${_problem.a} + ${_problem.b} = ?',
                    key: const Key('gate-problem'),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 140,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: _wrong ? Colors.red : scheme.outline, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _input,
                      key: const Key('gate-answer'),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _wrong ? Colors.red : scheme.onSurface,
                      ),
                    ),
                  ),
                  const Spacer(),
                  for (final row in const [
                    [1, 2, 3],
                    [4, 5, 6],
                    [7, 8, 9],
                    [null, 0, -1],
                  ])
                    Row(
                      children: [
                        for (final k in row)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: switch (k) {
                                null => const SizedBox(height: _keyHeight),
                                -1 => _Key(key: const Key('gate-back'), label: '⌫', onTap: _back),
                                _ => _Key(key: Key('gate-key-$k'), label: '$k', onTap: () => _digit(k)),
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _keyHeight = 64.0;

class _Key extends StatelessWidget {
  const _Key({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _keyHeight,
    child: FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Text(label, style: const TextStyle(fontSize: 28)),
    ),
  );
}
