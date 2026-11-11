import '../../../core/content/models.dart';

/// Mastery key prefix and session game of the tone-mark tracing game.
const toneTracePrefix = 'trace_tone';

/// The vowels a traced mark is put on, in turn: the first item of a round goes on
/// a, the second on e, … the sixth on a again.
const toneBases = ['a', 'e', 'o', 'u', 'i'];

/// Each tone on each of [toneBases], as precomposed (NFC) lower-case letters.
const _combined = {
  'sac': ['á', 'é', 'ó', 'ú', 'í'],
  'huyen': ['à', 'è', 'ò', 'ù', 'ì'],
  'hoi': ['ả', 'ẻ', 'ỏ', 'ủ', 'ỉ'],
  'nga': ['ã', 'ẽ', 'õ', 'ũ', 'ĩ'],
  'nang': ['ạ', 'ẹ', 'ọ', 'ụ', 'ị'],
};

/// What each tile of the row of marks shows. Hỏi and nặng have no spacing form
/// big enough to read on a small tile, so they sit on an a.
const toneTileGlyphs = {'sac': '´', 'huyen': '`', 'hoi': 'ả', 'nga': '~', 'nang': 'ạ'};

/// Tone [toneId] on [base] (one of [toneBases]), lower case, e.g. `á` for sac on a.
String toneCombined(String toneId, String base) {
  final row = _combined[toneId];
  final i = toneBases.indexOf(base);
  if (row == null || i < 0) throw ArgumentError('no letter for tone "$toneId" on "$base"');
  return row[i];
}

/// A tone mark as a tracing item. Its char is the tone id, so progress is keyed
/// `trace_tone:<id>`; [base] is the vowel the mark lands on once traced.
class ToneTraceItem extends LetterItem {
  ToneTraceItem(this.tone, {this.base = 'a'}) : super(char: tone.id, strokes: tone.strokes);

  final ToneItem tone;
  final String base;

  String get baseUpper => base.toUpperCase();
  String get combined => toneCombined(tone.id, base);
  String get combinedUpper => combined.toUpperCase();
}

/// One item per tone, every one on a until a round places them.
List<LetterItem> buildToneItems(List<ToneItem> tones) => [for (final t in tones) ToneTraceItem(t)];

/// [round] with item i put on toneBases[i % 5]: A, E, O, U, I in order of appearance.
List<LetterItem> withToneBases(List<LetterItem> round) => [
      for (final (i, l) in round.indexed) ToneTraceItem((l as ToneTraceItem).tone, base: toneBases[i % toneBases.length]),
    ];

/// The vars of the tone phrases: `{tone}` (sắc), `{base}` (a) and `{combined}` (á).
Map<String, String> toneVars(ToneTraceItem item) => {'tone': item.tone.name, 'base': item.base, 'combined': item.combined};
