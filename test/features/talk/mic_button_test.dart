import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/games/talk/mic_button.dart';

void main() {
  late ValueNotifier<bool> enabled;
  late int starts;
  late int ends;

  setUp(() {
    enabled = ValueNotifier(true);
    starts = 0;
    ends = 0;
  });

  Future<void> pumpMic(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, on, _) => MicButton(
                key: const Key('mic'),
                enabled: on,
                onHoldStart: () => starts++,
                onHoldEnd: () => ends++,
              ),
            ),
          ),
        ),
      ));

  testWidgets('hold starts, release ends once', (tester) async {
    await pumpMic(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('mic'))));
    await tester.pump();
    expect(starts, 1);
    await g.up();
    await tester.pump();
    expect(ends, 1);
    await tester.pump(const Duration(seconds: 9));
    expect(ends, 1);
  });

  testWidgets('pressed while locked and still held when it unlocks: listening starts', (tester) async {
    enabled.value = false;
    await pumpMic(tester);
    final centre = tester.getCenter(find.byKey(const Key('mic')));
    final g = await tester.startGesture(centre);
    await tester.pump(const Duration(milliseconds: 200));
    expect(starts, 0);
    enabled.value = true;
    await tester.pump(); // rebuild
    await tester.pump(); // after-frame start
    expect(starts, 1);
    await g.up();
    await tester.pump();
    expect(ends, 1);
  });

  testWidgets('pressed while locked and let go before it unlocks: nothing starts', (tester) async {
    enabled.value = false;
    await pumpMic(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('mic'))));
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await tester.pump();
    enabled.value = true;
    await tester.pump();
    await tester.pump();
    expect(starts, 0);
    expect(ends, 0);
  });

  testWidgets('a second finger lifting does not end the hold; only the owning finger does', (tester) async {
    await pumpMic(tester);
    final centre = tester.getCenter(find.byKey(const Key('mic')));
    final g1 = await tester.startGesture(centre, pointer: 1);
    await tester.pump();
    final g2 = await tester.startGesture(centre + const Offset(10, 10), pointer: 2);
    await tester.pump();
    expect(starts, 1);
    await g2.up();
    await tester.pump();
    expect(ends, 0);
    await g1.up();
    await tester.pump();
    expect(ends, 1);
  });

  testWidgets('a hold ended by the auto-stop does not restart when the same finger is still down', (tester) async {
    await pumpMic(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('mic'))));
    await tester.pump(const Duration(seconds: 9));
    expect(starts, 1);
    expect(ends, 1);
    enabled.value = false;
    await tester.pump();
    enabled.value = true;
    await tester.pump();
    await tester.pump();
    expect(starts, 1);
    await g.up();
    await tester.pump();
  });

  testWidgets('waiting shows the cue', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MicButton(key: const Key('mic'), enabled: false, waiting: true, onHoldStart: () {}, onHoldEnd: () {}),
      ),
    ));
    expect(find.byKey(const Key('mic-waiting')), findsOneWidget);
  });
}
