import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';

const _order = 'A Ă Â B C D Đ E Ê G H I K L M N O Ô Ơ P Q R S T U Ư V X Y';

const _spoken = {
  'A': 'a', 'Ă': 'á', 'Â': 'ớ', 'B': 'bờ', 'C': 'cờ', 'D': 'dờ', 'Đ': 'đờ', 'E': 'e', 'Ê': 'ê',
  'G': 'gờ', 'H': 'hờ', 'I': 'i', 'K': 'ca', 'L': 'lờ', 'M': 'mờ', 'N': 'nờ', 'O': 'o', 'Ô': 'ô',
  'Ơ': 'ơ', 'P': 'pờ', 'Q': 'quờ', 'R': 'rờ', 'S': 'sờ', 'T': 'tờ', 'U': 'u', 'Ư': 'ư', 'V': 'vờ',
  'X': 'xờ', 'Y': 'i dài',
};

// Accented letters and the English letter that shares their base shape.
const _base = {'Ă': 'A', 'Â': 'A', 'Đ': 'D', 'Ê': 'E', 'Ô': 'O', 'Ơ': 'O', 'Ư': 'U'};

void main() {
  late List<LetterItem> vi;
  late Map<String, LetterItem> en;

  setUpAll(() async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    vi = bundle.lettersVi;
    en = {for (final l in bundle.lettersEn) l.char: l};
  });

  LetterItem v(String c) => vi.firstWhere((l) => l.char == c);

  String render(LetterItem l) => _toJson(l);

  test('29 letters in the agreed order', () {
    expect(vi.map((l) => l.char).join(' '), _order);
  });

  test('every letter has the agreed spoken name and no example', () {
    for (final l in vi) {
      expect(l.spoken, _spoken[l.char], reason: l.char);
      expect(l.exampleWord, isEmpty, reason: l.char);
    }
  });

  test('plain letters have exactly the English strokes', () {
    for (final l in vi.where((l) => !_base.containsKey(l.char))) {
      expect(render(l), render(en[l.char]!), reason: l.char);
    }
  });

  test('every stroke stays inside the box', () {
    for (final l in vi) {
      expect(l.strokes, isNotEmpty, reason: l.char);
      for (final s in l.strokes) {
        for (final p in s.sample()) {
          expect(p.x, inInclusiveRange(-0.001, 1.001), reason: l.char);
          expect(p.y, inInclusiveRange(-0.001, 1.001), reason: l.char);
        }
      }
    }
  });

  test('Ă Â Ê Ô squash the base into y 0.3-0.9 and add a mark above it', () {
    for (final c in ['Ă', 'Â', 'Ê', 'Ô']) {
      final base = en[_base[c]!]!;
      final l = v(c);
      expect(l.strokes, hasLength(base.strokes.length + 1), reason: c);
      for (final (i, s) in base.strokes.indexed) {
        final squashed = _squash(s);
        expect(_toJsonStroke(l.strokes[i]), _toJsonStroke(squashed), reason: c);
        for (final p in l.strokes[i].sample()) {
          expect(p.y, inInclusiveRange(0.3 - 1e-9, 0.9 + 1e-9), reason: c);
        }
      }
      for (final p in l.strokes.last.sample()) {
        expect(p.y, lessThanOrEqualTo(0.25), reason: '$c mark is above the letter');
      }
    }
  });

  test('Ơ Ư keep the base and add a horn; Đ keeps D and adds a bar last', () {
    for (final c in ['Ơ', 'Ư', 'Đ']) {
      final base = en[_base[c]!]!;
      final l = v(c);
      expect(l.strokes, hasLength(base.strokes.length + 1), reason: c);
      for (final (i, s) in base.strokes.indexed) {
        expect(_toJsonStroke(l.strokes[i]), _toJsonStroke(s), reason: c);
      }
    }
    for (final c in ['Ơ', 'Ư']) {
      for (final p in v(c).strokes.last.sample()) {
        expect(p.y, lessThanOrEqualTo(0.25), reason: c);
      }
    }
    final bar = v('Đ').strokes.last.sample();
    expect(bar.every((p) => (p.y - 0.5).abs() < 1e-9), isTrue);
  });

  test('the mark shapes match the spec', () {
    expect(_toJsonStroke(v('Ă').strokes.last), '[arc 0.5 0.1 0.15 0.1 180.0 -180.0]');
    for (final c in ['Â', 'Ê', 'Ô']) {
      expect(_toJsonStroke(v(c).strokes.last), '[line 0.35,0.22 0.5,0.08 0.65,0.22]', reason: c);
    }
    expect(_toJsonStroke(v('Ơ').strokes.last), '[line 0.74,0.24 0.94,0.06]');
    expect(_toJsonStroke(v('Ư').strokes.last), '[line 0.8,0.2 0.96,0.04]');
    expect(_toJsonStroke(v('Đ').strokes.last), '[line 0.12,0.5 0.42,0.5]');
  });
}

// Canonical text form of strokes, rounded so float noise does not matter.
String _n(double x) => (x * 1e6).round() == 0 ? '0.0' : double.parse(x.toStringAsFixed(6)).toString();

String _toJsonStroke(Stroke s) => '[${[
  for (final g in s.segments)
    switch (g) {
      LineSegment() => 'line ${g.points.map((p) => '${_n(p.x)},${_n(p.y)}').join(' ')}',
      ArcSegment() => 'arc ${_n(g.cx)} ${_n(g.cy)} ${_n(g.rx)} ${_n(g.ry)} ${_n(g.startDeg)} ${_n(g.sweepDeg)}',
    },
].join('; ')}]';

String _toJson(LetterItem l) => l.strokes.map(_toJsonStroke).join('|');

double _sy(double y) => 0.3 + (y - 0.1) * 0.75;

Stroke _squash(Stroke s) => Stroke([
      for (final g in s.segments)
        switch (g) {
          LineSegment() => LineSegment([for (final p in g.points) TracePoint(p.x, _sy(p.y))]),
          ArcSegment() => ArcSegment(g.cx, _sy(g.cy), g.rx, g.ry * 0.75, g.startDeg, g.sweepDeg),
        },
    ]);
