import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/games/balloon/balloon_field.dart';

final _balloonKey = RegExp(r'^balloon-[A-Z]$');

List<String> letters(WidgetTester tester) => [
      for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && _balloonKey.hasMatch((w.key! as ValueKey<String>).value)).evaluate())
        (e.widget.key! as ValueKey<String>).value.substring(8),
    ];

Future<void> run(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 20).round(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> mount(WidgetTester tester, {required String target, required bool Function(String) onPop}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: BalloonField(target: target, onPop: onPop, random: Random(7))),
  ));
}

Offset bodyCenter(WidgetTester tester, String letter) {
  final box = tester.getRect(find.byKey(Key('balloon-$letter')));
  final d = box.width - 24;
  return Offset(box.center.dx, box.top + 12 + d * 1.15 / 2);
}

void main() {
  testWidgets('a held target that the screen never replaces is released after about 3 seconds', (tester) async {
    await mount(tester, target: 'B', onPop: (_) => true);
    await run(tester, 1);
    expect(letters(tester), contains('B'));
    // Wait until the target is on screen at a spot nothing else covers, then pop it.
    await tester.tapAt(bodyCenter(tester, 'B'));
    await tester.pump();
    await run(tester, 0.5);
    expect(letters(tester), isNot(contains('B')), reason: 'held while the screen celebrates');
    await run(tester, 3.5); // the target never changes: the safety net lets go
    expect(letters(tester), contains('B'), reason: 'the target balloon is back');
  });

  testWidgets('a refused pop leaves the balloon in place and only wiggles it', (tester) async {
    final asked = <String>[];
    await mount(tester, target: 'B', onPop: (l) {
      asked.add(l);
      return false;
    });
    await run(tester, 3);
    final letter = letters(tester).first;
    await tester.tapAt(bodyCenter(tester, letter));
    await run(tester, 0.5);
    expect(asked, [letter]);
    expect(find.byKey(Key('balloon-$letter')), findsOneWidget);
    expect(find.byKey(Key('balloon-pop-$letter')), findsNothing);
  });

  testWidgets('a long stall moves the field by one capped step, not by the whole stall', (tester) async {
    await mount(tester, target: 'B', onPop: (_) => true);
    await run(tester, 2);
    final before = {for (final l in letters(tester)) l: tester.getRect(find.byKey(Key('balloon-$l'))).top};
    await tester.pump(const Duration(seconds: 20)); // an app resume
    var compared = 0;
    for (final l in letters(tester)) {
      final was = before[l];
      if (was == null) continue;
      compared++;
      // 0.05 s of a 7+ s crossing of a 640 dp field is under 5 dp.
      expect((tester.getRect(find.byKey(Key('balloon-$l'))).top - was).abs(), lessThan(10), reason: 'balloon $l');
    }
    expect(compared, greaterThan(2));
  });
}
