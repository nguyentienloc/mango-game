import 'package:flutter/material.dart';

import '../../../core/content/models.dart';

/// The white card some talk questions show under Elsa: a vocabulary picture
/// ("What's this?") or a row of emojis ("How many stars?").
class TalkPicture extends StatelessWidget {
  const TalkPicture({super.key, this.image, this.emoji});

  static const size = 230.0;

  /// The card for [item], or null when the question has no picture. [vocab]
  /// gives the picture of the word its `image` names.
  static TalkPicture? forItem(ConversationItem item, List<VocabItem> vocab) {
    final key = ValueKey('talk-picture:${item.id}');
    final row = item.emojiRow;
    if (row != null) return TalkPicture(key: key, emoji: row);
    final id = item.image;
    if (id == null) return null;
    final word = vocab.where((w) => w.id == id).firstOrNull;
    if (word == null) return null;
    return TalkPicture(key: key, image: word.image, emoji: word.emoji);
  }

  /// Asset path relative to content/.
  final String? image;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final fallback = Padding(
      padding: const EdgeInsets.all(16),
      child: FittedBox(child: Text(emoji ?? '❓', style: const TextStyle(fontSize: 96))),
    );
    final image = this.image;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: image == null
          ? fallback
          // A missing or broken file falls back to the emoji instead of a red error box.
          : Image.asset('content/$image', width: 180, height: 180, errorBuilder: (_, _, _) => fallback),
    );
  }
}
