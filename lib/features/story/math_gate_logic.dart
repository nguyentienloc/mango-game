import 'dart:math';

/// The sum a parent solves to open the parent area; the carry keeps a small
/// child from guessing it.
class MathProblem {
  const MathProblem(this.a, this.b);

  /// Two numbers in 11..49 whose last digits add up to 10 or more.
  static MathProblem random(Random r) {
    while (true) {
      final a = 11 + r.nextInt(39);
      final b = 11 + r.nextInt(39);
      if ((a % 10) + (b % 10) >= 10) return MathProblem(a, b);
    }
  }

  final int a, b;

  int get answer => a + b;
}
