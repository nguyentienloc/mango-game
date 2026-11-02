import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/voice/utterance.dart';

void main() {
  test('key and spoken text join the parts', () {
    const u = Utterance([UtterancePart('en', 'Lion!'), UtterancePart('vi', 'Con sư tử!')]);
    expect(u.key, 'en|Lion! || vi|Con sư tử!');
    expect(u.spokenText, 'Lion! Con sư tử!');
  });
}
