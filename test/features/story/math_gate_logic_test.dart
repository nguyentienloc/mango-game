import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/story/math_gate_logic.dart';

void main() {
  test('answer is the sum', () {
    expect(const MathProblem(17, 28).answer, 45);
  });

  test('2000 random problems stay in range and always carry', () {
    for (var seed = 0; seed < 2000; seed++) {
      final p = MathProblem.random(Random(seed));
      expect(p.a, inInclusiveRange(11, 49), reason: 'seed $seed');
      expect(p.b, inInclusiveRange(11, 49), reason: 'seed $seed');
      expect((p.a % 10) + (p.b % 10), greaterThanOrEqualTo(10), reason: 'seed $seed');
    }
  });

  test('problems vary', () {
    final r = Random(1);
    expect({for (var i = 0; i < 50; i++) MathProblem.random(r).answer}.length, greaterThan(5));
  });
}
