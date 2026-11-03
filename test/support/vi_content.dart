import 'package:xoai_castle/core/content/models.dart';

/// [content] plus the Vietnamese letter-game phrases (the real ones ship with the content
/// pack; tests of the screens only need them to be sayable).
ContentBundle withViLetterPhrases(ContentBundle content) {
  const texts = {
    'vi_balloon_prompt': '{name_vi} tìm chữ {spoken} nào!',
    'vi_balloon_correct': 'Đúng rồi! Chữ {spoken}!',
    'vi_balloon_wrong_this': 'Chưa đúng rồi, đây là chữ {tapped}.',
    'vi_balloon_wrong_find': 'Tìm chữ {spoken} nha!',
    'vi_trace_prompt': 'Mình cùng viết chữ {spoken} nào!',
    'vi_trace_done': 'Giỏi quá! Chữ {spoken}!',
  };
  return ContentBundle(
    lettersEn: content.lettersEn,
    lettersVi: content.lettersVi,
    phrases: {
      ...content.phrases,
      for (final e in texts.entries) e.key: Phrase(id: e.key, lang: 'vi', text: e.value, group: 'vi_letters'),
    },
    castle: content.castle,
    characters: content.characters,
    profileDefaults: content.profileDefaults,
    vocab: content.vocab,
  );
}
