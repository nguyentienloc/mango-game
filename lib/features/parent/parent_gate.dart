import 'dart:math';

import 'package:flutter/material.dart';

/// Asks a two-digit addition; resolves true only for the right answer.
Future<bool> showParentGate(BuildContext context, {Random? random}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => ParentGateDialog(random: random ?? Random()),
  );
  return ok ?? false;
}

class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key, required this.random});

  final Random random;

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  final _controller = TextEditingController();
  late int _a;
  late int _b;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _newQuestion() {
    _a = 10 + widget.random.nextInt(40);
    _b = 10 + widget.random.nextInt(40);
    _controller.clear();
  }

  void _submit() {
    if (int.tryParse(_controller.text.trim()) == _a + _b) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _wrong = true;
      _newQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dành cho bố mẹ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_a + $_b = ?', key: const Key('parent-gate-question'), style: const TextStyle(fontSize: 32)),
          TextField(
            key: const Key('parent-gate-input'),
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_wrong) const Text('Chưa đúng, thử lại nhé', style: TextStyle(color: Colors.red)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
