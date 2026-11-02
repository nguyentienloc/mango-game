import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/updater/version_compare.dart';

void main() {
  test('normalizeVersion strips v prefix and build/pre-release suffixes', () {
    expect(normalizeVersion('v1.2.3'), '1.2.3');
    expect(normalizeVersion('1.2.3+7'), '1.2.3');
    expect(normalizeVersion(' V0.1.0-beta '), '0.1.0');
  });

  test('isNewerVersion compares numerically', () {
    expect(isNewerVersion('1.2.0', '1.1.9'), isTrue);
    expect(isNewerVersion('v1.2.0', '1.2.0'), isFalse);
    expect(isNewerVersion('1.10.0', '1.9.9'), isTrue);
    expect(isNewerVersion('1.2.0+5', '1.2.0'), isFalse);
    expect(isNewerVersion('0.2', '0.1.9'), isTrue);
    expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
  });

  test('unparseable versions are never newer', () {
    expect(isNewerVersion('latest', '0.1.0'), isFalse);
    expect(isNewerVersion('1.0.0', 'abc'), isFalse);
  });
}
