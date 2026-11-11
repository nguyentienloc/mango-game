import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/letter_game_spec.dart';
import 'package:xoai_castle/features/games/trace/tone_trace.dart';
import 'package:xoai_castle/features/games/trace/trace_logic.dart';
import 'package:xoai_castle/features/games/trace/trace_pad.dart';

double _length(List<TracePoint> pts) {
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    total += pts[i - 1].distanceTo(pts[i]);
  }
  return total;
}

List<TracePoint> _line(TracePoint a, TracePoint b, [int n = 20]) => [
      for (var i = 0; i <= n; i++) TracePoint(a.x + (b.x - a.x) * i / n, a.y + (b.y - a.y) * i / n),
    ];

void main() {
  late List<ToneItem> tones;
  late List<LetterItem> items;

  setUpAll(() async {
    tones = (await ContentRepository(FileContentSource('content')).load()).tones;
    items = buildToneItems(tones);
  });

  group('combined letters', () {
    const lower = {
      'sac': ['á', 'é', 'ó', 'ú', 'í'],
      'huyen': ['à', 'è', 'ò', 'ù', 'ì'],
      'hoi': ['ả', 'ẻ', 'ỏ', 'ủ', 'ỉ'],
      'nga': ['ã', 'ẽ', 'õ', 'ũ', 'ĩ'],
      'nang': ['ạ', 'ẹ', 'ọ', 'ụ', 'ị'],
    };
    const upper = {
      'sac': ['Á', 'É', 'Ó', 'Ú', 'Í'],
      'huyen': ['À', 'È', 'Ò', 'Ù', 'Ì'],
      'hoi': ['Ả', 'Ẻ', 'Ỏ', 'Ủ', 'Ỉ'],
      'nga': ['Ã', 'Ẽ', 'Õ', 'Ũ', 'Ĩ'],
      'nang': ['Ạ', 'Ẹ', 'Ọ', 'Ụ', 'Ị'],
    };

    test('the bases are a, e, o, u, i in that order', () {
      expect(toneBases, ['a', 'e', 'o', 'u', 'i']);
    });

    test('every tone on every base is one precomposed (NFC) character, lower and upper case', () {
      for (final id in lower.keys) {
        for (final (i, base) in toneBases.indexed) {
          final c = toneCombined(id, base);
          expect(c, lower[id]![i], reason: '$id $base');
          expect(c.runes, hasLength(1), reason: '$id $base is precomposed');
          final item = ToneTraceItem(tones.firstWhere((t) => t.id == id), base: base);
          expect(item.combined, lower[id]![i]);
          expect(item.combinedUpper, upper[id]![i]);
          expect(item.combinedUpper.runes, hasLength(1));
          expect(item.baseUpper, base.toUpperCase());
        }
      }
    });
  });

  group('items and rounds', () {
    test('one item per tone, keyed trace_tone:<id>, base a until a round places them', () {
      expect(items.map((l) => l.char), ['sac', 'huyen', 'hoi', 'nga', 'nang']);
      expect(items.map((l) => traceKey(l, toneTracePrefix)), [
        'trace_tone:sac',
        'trace_tone:huyen',
        'trace_tone:hoi',
        'trace_tone:nga',
        'trace_tone:nang',
      ]);
      for (final l in items) {
        expect((l as ToneTraceItem).base, 'a');
        expect(l.strokes, same(l.tone.strokes));
      }
    });

    test('a round of the five tones has ten items, each tone twice, never twice in a row', () {
      for (var seed = 0; seed < 30; seed++) {
        final round = buildTraceRound(
          letters: items,
          stats: const {},
          picker: QuestionPicker(Random(seed)),
          keyPrefix: toneTracePrefix,
        );
        expect(round, hasLength(10));
        for (final l in items) {
          expect(round.where((r) => r.char == l.char), hasLength(2), reason: 'seed $seed ${l.char}');
        }
        for (var i = 1; i < round.length; i++) {
          expect(round[i].char, isNot(round[i - 1].char), reason: 'seed $seed at $i');
        }
      }
    });

    test('placing the round gives the bases A E O U I in order of appearance, keeping the tones', () {
      final round = buildTraceRound(
        letters: items,
        stats: const {},
        picker: QuestionPicker(Random(3)),
        keyPrefix: toneTracePrefix,
      );
      final placed = withToneBases(round).cast<ToneTraceItem>();
      expect(placed.map((l) => l.char), round.map((l) => l.char));
      expect(placed.map((l) => l.base), ['a', 'e', 'o', 'u', 'i', 'a', 'e', 'o', 'u', 'i']);
      expect(placed.map((l) => l.baseUpper).join(), 'AEOUIAEOUI');
      expect(placed.first.combined, toneCombined(placed.first.tone.id, 'a'));
      expect(placed[1].combined, toneCombined(placed[1].tone.id, 'e'));
    });

    test('traceTones places the bases through its prepareRound hook', () {
      const spec = LetterGameSpec.traceTones;
      expect(spec.keyPrefix, 'trace_tone');
      expect(spec.sessionGame, 'trace_tone');
      expect(spec.popToRootOnExit, isTrue);
      final placed = spec.prepareRound!([items[0], items[1], items[0]]).cast<ToneTraceItem>();
      expect(placed.map((l) => l.base), ['a', 'e', 'o']);
    });

    test('traceTones says the tone, then base, tone and combined letter', () {
      const spec = LetterGameSpec.traceTones;
      final sac = ToneTraceItem(tones[0], base: 'a');
      final ngaU = ToneTraceItem(tones[3], base: 'u');
      expect(spec.vars(sac), {'tone': 'sắc', 'base': 'a', 'combined': 'á'});
      expect(spec.vars(ngaU), {'tone': 'ngã', 'base': 'u', 'combined': 'ũ'});
    });
  });

  group('tracing the shipped marks', () {
    void expectTraceable(LetterItem l, List<TracePoint> Function(List<TracePoint> guide) drawFrom, String how) {
      final session = TraceLetterSession(l);
      for (final (i, target) in session.targets.indexed) {
        final drawn = drawFrom(target);
        expect(scoreStroke(target, drawn).passed, isTrue, reason: '${l.char} stroke $i ($how)');
        expect(session.submit(drawn), isTrue, reason: '${l.char} stroke $i ($how)');
      }
      expect(session.isDone, isTrue);
      expect(session.outcome, AnswerOutcome.firstTry);
    }

    test('tracing right along each guide scores correct', () {
      for (final l in items) {
        expectTraceable(l, (guide) => guide, 'on the guide');
      }
    });

    test('a slightly shifted, coarse finger trace still scores correct', () {
      for (final l in items) {
        expectTraceable(
          l,
          (guide) => [
            for (var i = 0; i < guide.length; i += 3) TracePoint(guide[i].x + 0.04, guide[i].y - 0.03),
            TracePoint(guide.last.x + 0.04, guide.last.y - 0.03),
          ],
          'shifted',
        );
      }
    });

    test('tracing the guide backwards still counts (as for letters)', () {
      for (final l in items) {
        expectTraceable(l, (guide) => guide.reversed.toList(), 'backwards');
      }
    });

    test('a dab, a short scribble or a straight swipe across the middle does not pass', () {
      const c = TracePoint(0.5, 0.5);
      final lazy = {
        'dab': _line(c, const TracePoint(0.54, 0.52), 3),
        // A little zigzag in the middle, about 0.29 long.
        'short scribble': [for (var i = 0; i < 8; i++) TracePoint(0.48 + 0.04 * (i % 2), 0.47 + i * 0.008)],
        'horizontal swipe': _line(const TracePoint(0.22, 0.5), const TracePoint(0.78, 0.5)),
        'vertical swipe': _line(const TracePoint(0.5, 0.22), const TracePoint(0.5, 0.78)),
      };
      for (final l in items) {
        final target = TraceLetterSession(l).targets.single;
        for (final e in lazy.entries) {
          final s = scoreStroke(target, e.value);
          expect(s.passed, isFalse, reason: '${l.char}: ${e.key} (cov ${s.coverage}, prec ${s.precision}, len ${s.lengthRatio})');
        }
      }
    });

    test('nặng: a straight swipe through the dot at any angle does not pass, a round scribble on the ring does', () {
      final nang = TraceLetterSession(items.last).targets.single;
      for (var deg = 0; deg < 180; deg += 15) {
        final a = deg * pi / 180;
        for (final half in [0.2, 0.28]) {
          final swipe = _line(
            TracePoint(0.5 - half * cos(a), 0.5 - half * sin(a)),
            TracePoint(0.5 + half * cos(a), 0.5 + half * sin(a)),
          );
          expect(scoreStroke(nang, swipe).passed, isFalse, reason: 'swipe at $deg°, half $half');
        }
      }
      // A wobbly circle about the size of the guide, drawn clockwise from the right.
      final wobbly = [
        for (var i = 0; i <= 40; i++)
          TracePoint(0.5 + (0.11 + 0.03 * sin(i * 1.7)) * cos(i * 2 * pi / 40), 0.5 + (0.11 + 0.03 * sin(i * 1.7)) * sin(i * 2 * pi / 40)),
      ];
      expect(scoreStroke(nang, wobbly).passed, isTrue);
    });

    test('every mark is long enough to get a direction arrow next to its start dot', () {
      for (final l in items) {
        expect(shouldDrawArrow(_length(l.strokes.single.sample())), isTrue, reason: l.char);
      }
    });
  });
}
