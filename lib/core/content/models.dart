import 'dart:convert';

import 'strokes.dart';

class LetterItem {
  const LetterItem({
    required this.char,
    this.exampleWord = '',
    this.exampleEmoji,
    this.exampleImage,
    this.spoken,
    this.strokes = const [],
  });

  factory LetterItem.fromJson(Map<String, dynamic> json) {
    // Vietnamese letters carry a spoken name instead of an example word.
    final example = json['example'] as Map<String, dynamic>?;
    return LetterItem(
      char: json['char'] as String,
      exampleWord: example?['word'] as String? ?? '',
      exampleEmoji: example?['emoji'] as String?,
      exampleImage: example?['image'] as String?,
      spoken: json['spoken'] as String?,
      strokes: [for (final s in (json['strokes'] as List? ?? const [])) Stroke.fromJson(s as List)],
    );
  }

  final String char;
  final String exampleWord;
  final String? exampleEmoji;
  final String? exampleImage;

  /// How the letter is said aloud (letters_vi only), e.g. "bờ" for B.
  final String? spoken;
  final List<Stroke> strokes;

  String get lower => char.toLowerCase();
}

class PhrasePart {
  const PhrasePart(this.lang, this.text);

  final String lang;
  final String text;
}

class Phrase {
  const Phrase({required this.id, required String lang, required String text, required this.group, this.priority = false})
      : _lang = lang,
        _text = text,
        _parts = null;

  const Phrase.multi({required this.id, required List<PhrasePart> parts, required this.group, this.priority = false})
      : _lang = null,
        _text = null,
        _parts = parts;

  factory Phrase.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final group = json['group'] as String;
    final priority = json['priority'] as bool? ?? false;
    final parts = json['parts'] as List?;
    if (parts != null) {
      return Phrase.multi(id: id, group: group, priority: priority, parts: [
        for (final p in parts) PhrasePart((p as Map<String, dynamic>)['lang'] as String, p['text'] as String),
      ]);
    }
    return Phrase(id: id, lang: json['lang'] as String, text: json['text'] as String, group: group, priority: priority);
  }

  final String id;
  final String group;
  final bool priority;
  final String? _lang;
  final String? _text;
  final List<PhrasePart>? _parts;

  List<PhrasePart> get allParts => _parts ?? [PhrasePart(_lang!, _text!)];
}

class CastleLevel {
  const CastleLevel({required this.level, required this.snowflakes, this.friend});

  factory CastleLevel.fromJson(Map<String, dynamic> json) => CastleLevel(
        level: json['level'] as int,
        snowflakes: json['snowflakes'] as int,
        friend: json['friend'] as String?,
      );

  final int level;
  final int snowflakes;
  final String? friend;
}

class CharacterDef {
  const CharacterDef({required this.id, required this.name, required this.emoji, this.image});

  factory CharacterDef.fromJson(String id, Map<String, dynamic> json) => CharacterDef(
        id: id,
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        image: json['image'] as String?,
      );

  final String id;
  final String name;
  final String emoji;
  final String? image;
}

class ProfileDefaults {
  const ProfileDefaults({required this.nameEn, required this.nameVi, required this.dailyLimitMin});

  factory ProfileDefaults.fromJson(Map<String, dynamic> json) => ProfileDefaults(
        nameEn: json['name_en'] as String,
        nameVi: json['name_vi'] as String,
        dailyLimitMin: json['daily_limit_min'] as int,
      );

  final String nameEn;
  final String nameVi;
  final int dailyLimitMin;
}

class VocabItem {
  const VocabItem({required this.id, required this.word, required this.vi, required this.emoji, required this.topic, this.image});

  factory VocabItem.fromJson(Map<String, dynamic> json, String topic) => VocabItem(
        id: json['id'] as String,
        word: json['word'] as String,
        vi: json['vi'] as String,
        emoji: json['emoji'] as String,
        image: json['image'] as String?,
        topic: topic,
      );

  final String id;
  final String word;
  final String vi;
  final String emoji;
  final String? image;
  final String topic;
}

class ContentBundle {
  const ContentBundle({
    required this.lettersEn,
    required this.lettersVi,
    required this.phrases,
    required this.castle,
    required this.characters,
    required this.profileDefaults,
    required this.vocab,
  });

  /// Builds a bundle from already-validated files (paths relative to content/).
  factory ContentBundle.fromFiles(Map<String, String> files) {
    Map<String, dynamic> read(String path) => jsonDecode(files[path]!) as Map<String, dynamic>;
    final characters = read('characters.json')['items'] as Map<String, dynamic>;
    final manifest = read('manifest.json');
    final vocab = [
      for (final name in (manifest['packs'] as Map<String, dynamic>).keys)
        if (name.startsWith('vocab_'))
          for (final j in read('packs/$name.json')['items'] as List)
            VocabItem.fromJson(j as Map<String, dynamic>, name.substring('vocab_'.length)),
    ];
    return ContentBundle(
      lettersEn: [
        for (final j in read('packs/letters_en.json')['items'] as List) LetterItem.fromJson(j as Map<String, dynamic>),
      ],
      lettersVi: [
        for (final j in read('packs/letters_vi.json')['items'] as List) LetterItem.fromJson(j as Map<String, dynamic>),
      ],
      phrases: {
        for (final j in read('phrases.json')['items'] as List)
          (j as Map<String, dynamic>)['id'] as String: Phrase.fromJson(j),
      },
      castle: [
        for (final j in read('castle.json')['items'] as List) CastleLevel.fromJson(j as Map<String, dynamic>),
      ],
      characters: {
        for (final e in characters.entries) e.key: CharacterDef.fromJson(e.key, e.value as Map<String, dynamic>),
      },
      profileDefaults: ProfileDefaults.fromJson(read('profile_defaults.json')),
      vocab: vocab,
    );
  }

  final List<LetterItem> lettersEn;
  final List<LetterItem> lettersVi;
  final Map<String, Phrase> phrases;
  final List<CastleLevel> castle;
  final Map<String, CharacterDef> characters;
  final ProfileDefaults profileDefaults;
  final List<VocabItem> vocab;
}
