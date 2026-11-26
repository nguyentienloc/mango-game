import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/app/theme.dart';

/// [text] is gold with a dark soft shadow, so it reads on white snow as well as on the sky.
void expectGoldOnSnow(WidgetTester tester, Finder text) {
  final style = tester.widget<Text>(text).style!;
  expect(style.color, NoelColors.gold);
  expect(
    style.shadows?.any((s) => s.blurRadius >= 6 && s.color.computeLuminance() < 0.05 && s.color.a > 0.5),
    isTrue,
    reason: '$text needs a dark shadow (blur 6) to read on snow',
  );
}
