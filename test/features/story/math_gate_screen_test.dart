import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/features/story/math_gate_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

final _problem = find.byKey(const Key('gate-problem'));

String _problemText(WidgetTester tester) => (tester.widget(_problem) as Text).data!;

int _answer(WidgetTester tester) {
  final m = RegExp(r'^(\d+) \+ (\d+) = \?$').firstMatch(_problemText(tester))!;
  return int.parse(m[1]!) + int.parse(m[2]!);
}

Future<void> _type(WidgetTester tester, int n) async {
  for (final d in '$n'.split('')) {
    await tester.tap(find.byKey(Key('gate-key-$d')));
    await tester.pump();
  }
}

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  Future<FakeTts> pumpGate(WidgetTester tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(
      testApp(
        content: content,
        tts: tts,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MathGateScreen(onPassed: (_) => const Text('opened', textDirection: TextDirection.ltr)),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    return tts;
  }

  testWidgets('shows a carry sum for the parent and says nothing', (tester) async {
    final tts = await pumpGate(tester);
    expect(find.text('Bố mẹ giải phép tính để mở nhé'), findsOneWidget);
    final m = RegExp(r'^(\d+) \+ (\d+) = \?$').firstMatch(_problemText(tester))!;
    final a = int.parse(m[1]!), b = int.parse(m[2]!);
    expect(a, inInclusiveRange(11, 49));
    expect(b, inInclusiveRange(11, 49));
    expect(a % 10 + b % 10, greaterThanOrEqualTo(10));
    for (var d = 0; d <= 9; d++) {
      expect(find.byKey(Key('gate-key-$d')), findsOneWidget);
    }
    expect(find.byKey(const Key('gate-back')), findsOneWidget);
    expect(tts.spoken, isEmpty);
  });

  testWidgets('the right answer typed on the keypad opens the next screen in place of the gate', (tester) async {
    await pumpGate(tester);
    await _type(tester, _answer(tester));
    await tester.pumpAndSettle();
    expect(find.text('opened'), findsOneWidget);
    expect(find.byType(MathGateScreen), findsNothing);
    Navigator.of(tester.element(find.text('opened'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget, reason: 'the gate was replaced, back goes home');
  });

  testWidgets('a wrong answer buzzes, shows red, then gives a new sum', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpGate(tester);
    final before = _problemText(tester);
    final wrong = _answer(tester) + 1;
    await _type(tester, wrong);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    final shown = tester.widget<Text>(find.byKey(const Key('gate-answer')));
    expect(shown.data, '$wrong');
    expect(shown.style?.color, Colors.red);
    expect(_problemText(tester), before, reason: 'the wrong answer stays visible for a moment');

    await tester.pump(const Duration(milliseconds: 650));
    expect(_problemText(tester), isNot(before));
    expect(tester.widget<Text>(find.byKey(const Key('gate-answer'))).data, '');
    expect(find.text('opened'), findsNothing);

    await _type(tester, _answer(tester));
    await tester.pumpAndSettle();
    expect(find.text('opened'), findsOneWidget);
  });

  Future<void> typeWrong(WidgetTester tester) async {
    await _type(tester, _answer(tester) + 1);
    await tester.pump(const Duration(milliseconds: 650));
  }

  testWidgets('three wrong answers in a row send the child back home', (tester) async {
    await pumpGate(tester);
    await typeWrong(tester);
    await typeWrong(tester);
    expect(find.byType(MathGateScreen), findsOneWidget, reason: 'two misses still get another sum');
    await typeWrong(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MathGateScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('opened'), findsNothing);
  });

  testWidgets('two wrong answers, then the right one, still opens', (tester) async {
    await pumpGate(tester);
    await typeWrong(tester);
    await typeWrong(tester);
    await _type(tester, _answer(tester));
    await tester.pumpAndSettle();
    expect(find.text('opened'), findsOneWidget);
  });

  testWidgets('⌫ removes the last digit', (tester) async {
    await pumpGate(tester);
    final answer = _answer(tester);
    final first = answer ~/ 10;
    await tester.tap(find.byKey(Key('gate-key-${(first + 1) % 10}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gate-back')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('gate-answer'))).data, '');
    await _type(tester, answer);
    await tester.pumpAndSettle();
    expect(find.text('opened'), findsOneWidget);
  });

  testWidgets('the back arrow returns home', (tester) async {
    await pumpGate(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(MathGateScreen), findsNothing);
  });

  testWidgets('fits a 360x640 phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpGate(tester);
    expect(tester.takeException(), isNull);
    for (final k in [for (var d = 0; d <= 9; d++) 'gate-key-$d', 'gate-back']) {
      final r = tester.getRect(find.byKey(Key(k)));
      expect(r.bottom, lessThanOrEqualTo(640), reason: k);
      expect(r.right, lessThanOrEqualTo(360), reason: k);
      expect(r.height, greaterThanOrEqualTo(48), reason: k);
    }
  });
}
