import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/voice_service.dart';

import '../../support/fakes.dart';

const phrases = {
  'hello': Phrase(id: 'hello', lang: 'vi', text: 'Chào {name_vi}!', group: 'greet'),
  'find': Phrase(id: 'find', lang: 'en', text: 'Find the letter {letter}, {name_en}!', group: 'instruction'),
  'try_a': Phrase(id: 'try_a', lang: 'en', text: 'Try again!', group: 'try_again'),
  'try_b': Phrase(id: 'try_b', lang: 'vi', text: 'Thử lại nha!', group: 'try_again'),
};

VoiceService voice(FakeTts tts, [int seed = 1]) =>
    VoiceService(tts: tts, phrases: phrases, names: const Names(en: 'An', vi: 'Xoài'), random: Random(seed));

void main() {
  test('render fills names and vars and keeps unknown placeholders', () {
    final v = voice(FakeTts());
    expect(v.render('Hi {name_en}, {name_vi}, {letter}', {'letter': 'B'}), 'Hi An, Xoài, B');
    expect(v.render('{nope}'), '{nope}');
  });

  test('say stops current speech then speaks the phrase in its language', () async {
    final tts = FakeTts();
    await voice(tts).say('find', vars: {'letter': 'B'});
    expect(tts.calls, ['stop', 'speak']);
    expect(tts.spoken.single, (text: 'Find the letter B, An!', lang: 'en'));
  });

  test('say with Vietnamese phrase uses vi', () async {
    final tts = FakeTts();
    await voice(tts).say('hello');
    expect(tts.spoken.single, (text: 'Chào Xoài!', lang: 'vi'));
  });

  test('say throws for unknown phrase ids', () {
    expect(() => voice(FakeTts()).say('missing'), throwsArgumentError);
  });

  test('sayGroup only picks phrases from the group and varies them', () async {
    final seen = <String>{};
    for (var seed = 0; seed < 20; seed++) {
      final tts = FakeTts();
      await voice(tts, seed).sayGroup('try_again');
      seen.add(tts.texts.single);
    }
    expect(seen, {'Try again!', 'Thử lại nha!'});
  });

  test('sayGroup throws for unknown groups', () {
    expect(() => voice(FakeTts()).sayGroup('nope'), throwsArgumentError);
  });

  test('multi-part phrases speak each part in its own language', () async {
    final tts = FakeTts();
    final v = VoiceService(
      tts: tts,
      phrases: const {
        'correct': Phrase.multi(id: 'correct', group: 'vocab', parts: [
          PhrasePart('en', '{Word}!'),
          PhrasePart('vi', '{Vi}!'),
        ]),
      },
      names: const Names(en: 'An', vi: 'Xoài'),
    );
    await v.say('correct', vars: {'Word': 'Lion', 'Vi': 'Con sư tử'});
    expect(tts.spoken, [(text: 'Lion!', lang: 'en'), (text: 'Con sư tử!', lang: 'vi')]);
  });

  test('utterance renders names and vars into parts', () {
    final v = voice(FakeTts());
    expect(v.utterance('find', vars: {'letter': 'B'}).key, 'en|Find the letter B, An!');
  });

  test('utterance throws for unknown phrase ids', () {
    expect(() => voice(FakeTts()).utterance('missing'), throwsArgumentError);
  });

  VoiceService twoParts(GatedTts tts) => VoiceService(
        tts: tts,
        phrases: const {
          'two': Phrase.multi(id: 'two', group: 'g', parts: [PhrasePart('en', 'One'), PhrasePart('vi', 'Hai')]),
          'next': Phrase(id: 'next', lang: 'en', text: 'Next', group: 'h'),
        },
        names: const Names(en: 'An', vi: 'Xoài'),
      );

  test('stop while the first part is speaking skips the remaining parts', () async {
    final tts = GatedTts();
    final v = twoParts(tts);
    final done = v.say('two');
    await Future<void>.delayed(Duration.zero);
    expect(tts.texts, ['One']);
    await v.stop();
    await done;
    expect(tts.texts, ['One']);
  });

  test('a new phrase cuts the remaining parts of the previous one', () async {
    final tts = GatedTts();
    final v = twoParts(tts);
    final first = v.say('two');
    await Future<void>.delayed(Duration.zero);
    final second = v.say('next');
    await Future<void>.delayed(Duration.zero);
    tts.release();
    await first;
    await second;
    expect(tts.texts, ['One', 'Next']);
  });
}
