import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/balloon/balloon_logic.dart';
import 'package:xoai_castle/features/games/pick_session.dart';

const _alphabet = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];

final _letters = [for (final c in _alphabet) LetterItem(char: c, exampleWord: c, exampleEmoji: '⭐')];

void main() {
  group('buildBalloonRound', () {
    test('picks 5 different letters for a fresh player', () {
      for (var seed = 0; seed < 50; seed++) {
        final round = buildBalloonRound(letters: _letters, stats: const <String, ItemStat>{}, picker: QuestionPicker(Random(seed)));
        expect(round, hasLength(5));
        expect(round.map((l) => l.char).toSet(), hasLength(5));
      }
      expect(balloonKey(_letters.first), 'balloon_en_upper:A');
    });

    test('caps unseen letters at maxNew when enough seen letters exist', () {
      final stats = {
        for (final l in _letters.take(10)) balloonKey(l): ItemStat(key: balloonKey(l), mastery: 1),
      };
      for (var seed = 0; seed < 50; seed++) {
        final round = buildBalloonRound(letters: _letters, stats: stats, picker: QuestionPicker(Random(seed)));
        expect(round.map((l) => l.char).toSet(), hasLength(5));
        expect(round.where((l) => !stats.containsKey(balloonKey(l))).length, lessThanOrEqualTo(3));
      }
    });

    test('returns fewer letters when the alphabet is smaller than count', () {
      final round = buildBalloonRound(letters: _letters.take(3).toList(), stats: const {}, picker: QuestionPicker(Random(1)));
      expect(round, hasLength(3));
    });
  });

  group('BalloonSpawner', () {
    test('never returns a letter already on screen (1000 simulated steps)', () {
      final random = Random(7);
      final spawner = BalloonSpawner(alphabet: _alphabet, random: random);
      const target = 'M';
      final onScreen = <String>{};
      for (var step = 0; step < 1000; step++) {
        // Pop or drift away random balloons so the set keeps changing.
        onScreen.removeWhere((_) => random.nextInt(4) == 0);
        while (onScreen.length < 6) {
          final targetPending = random.nextBool();
          final letter = spawner.nextLetter(onScreen: onScreen, target: target, targetPending: targetPending);
          expect(onScreen, isNot(contains(letter)), reason: 'step $step');
          expect(_alphabet, contains(letter));
          onScreen.add(letter);
        }
      }
    });

    test('always returns the target when it is absent and not pending', () {
      final random = Random(3);
      final spawner = BalloonSpawner(alphabet: _alphabet, random: random);
      for (var i = 0; i < 500; i++) {
        final onScreen = {for (final c in _alphabet) if (c != 'Q' && random.nextInt(4) == 0) c};
        expect(spawner.nextLetter(onScreen: onScreen, target: 'Q', targetPending: false), 'Q');
      }
    });

    test('sometimes but not always picks the absent target when it is pending', () {
      final spawner = BalloonSpawner(alphabet: _alphabet, random: Random(11));
      var hits = 0;
      for (var i = 0; i < 1000; i++) {
        if (spawner.nextLetter(onScreen: {'A', 'B'}, target: 'Q', targetPending: true) == 'Q') hits++;
      }
      expect(hits, inInclusiveRange(150, 350)); // about 1/4
    });

    test('never returns the target when it is already on screen', () {
      final spawner = BalloonSpawner(alphabet: _alphabet, random: Random(5));
      for (var i = 0; i < 300; i++) {
        expect(spawner.nextLetter(onScreen: {'Q'}, target: 'Q', targetPending: false), isNot('Q'));
      }
    });

    test('throws when every letter is on screen', () {
      final spawner = BalloonSpawner(alphabet: const ['A', 'B'], random: Random(1));
      expect(() => spawner.nextLetter(onScreen: {'A', 'B'}, target: 'A', targetPending: false), throwsStateError);
    });
  });

  group('Balloon', () {
    test('random balloons have valid colour, position, speed and phase', () {
      final random = Random(2);
      for (var i = 0; i < 500; i++) {
        final b = Balloon.random(id: i, letter: 'A', startTime: 1.5, random: random);
        expect(b.colorIndex, inInclusiveRange(0, kBalloonColors - 1));
        expect(b.x, inInclusiveRange(0.0, 1.0));
        expect(b.duration, inInclusiveRange(7.0, 9.0));
        expect(b.wobblePhase, inInclusiveRange(0.0, 2 * pi));
        expect(b.popped, isFalse);
        expect(b.startTime, 1.5);
      }
    });

    test('progress runs from 0 at start to 1 after duration', () {
      final b = Balloon(id: 1, letter: 'A', colorIndex: 0, x: 0.5, startTime: 2, duration: 8, wobblePhase: 0);
      expect(b.progress(2), 0);
      expect(b.progress(6), closeTo(0.5, 1e-9));
      expect(b.progress(10), closeTo(1, 1e-9));
      expect(b.progress(0), lessThanOrEqualTo(0)); // not yet visible
    });

    test('balloonY goes from bottom (1) to top (0)', () {
      expect(balloonY(0), 1);
      expect(balloonY(0.5), 0.5);
      expect(balloonY(1), 0);
    });

    test('popped can be set', () {
      final b = Balloon(id: 1, letter: 'A', colorIndex: 0, x: 0.5, startTime: 0, duration: 8, wobblePhase: 0);
      b.popped = true;
      expect(b.popped, isTrue);
    });
  });

  group('BalloonQuestion with PickSession', () {
    test('wrong twice shows the hint and the result is hinted', () {
      final session = PickSession([for (final l in _letters.take(2)) BalloonQuestion(l)]);
      expect(session.current.key, 'balloon_en_upper:A');
      expect(session.current.answer, 'A');
      expect(session.tap('B'), TapResult.wrong);
      expect(session.showHint, isFalse);
      expect(session.tap('C'), TapResult.wrong);
      expect(session.showHint, isTrue);
      expect(session.tap('A'), TapResult.correct);
      expect(session.outcomes, [AnswerOutcome.hinted]);
      session.next();
      expect(session.tap('B'), TapResult.correct);
      expect(session.outcomes.last, AnswerOutcome.firstTry);
    });
  });
}
