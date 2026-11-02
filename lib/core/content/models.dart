import 'dart:convert';

class LetterItem {
  const LetterItem({required this.char, required this.exampleWord, this.exampleEmoji, this.exampleImage});

  factory LetterItem.fromJson(Map<String, dynamic> json) {
    final example = json['example'] as Map<String, dynamic>;
    return LetterItem(
      char: json['char'] as String,
      exampleWord: example['word'] as String,
      exampleEmoji: example['emoji'] as String?,
      exampleImage: example['image'] as String?,
    );
  }

  final String char;
  final String exampleWord;
  final String? exampleEmoji;
  final String? exampleImage;

  String get lower => char.toLowerCase();
}

class Phrase {
  const Phrase({required this.id, required this.lang, required this.text, required this.group, this.priority = false});

  factory Phrase.fromJson(Map<String, dynamic> json) => Phrase(
        id: json['id'] as String,
        lang: json['lang'] as String,
        text: json['text'] as String,
        group: json['group'] as String,
        priority: json['priority'] as bool? ?? false,
      );

  final String id;
  final String lang;
  final String text;
  final String group;
  final bool priority;
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
  final Map<String, Phrase> phrases;
  final List<CastleLevel> castle;
  final Map<String, CharacterDef> characters;
  final ProfileDefaults profileDefaults;
  final List<VocabItem> vocab;
}
