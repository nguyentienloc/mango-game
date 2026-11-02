import 'dart:convert';

import '../content/content_repository.dart';
import 'utterance.dart';

/// Pre-generated audio clips (content/audio/index.json), keyed by UtterancePart.key (`lang|text`).
class ClipLibrary {
  const ClipLibrary(this._clips);

  static const empty = ClipLibrary({});

  final Map<String, String> _clips;

  int get length => _clips.length;

  static ClipLibrary parse(String indexJson) {
    final json = jsonDecode(indexJson) as Map<String, dynamic>;
    return ClipLibrary(Map<String, String>.from(json['clips'] as Map));
  }

  /// An unreadable or missing index means no clips: everything falls back to TTS.
  static Future<ClipLibrary> load(ContentSource source) async {
    try {
      return parse(await source.readText('audio/index.json'));
    } on Object {
      return empty;
    }
  }

  String? assetFor(UtterancePart part) {
    final file = _clips[part.key];
    return file == null ? null : 'content/audio/$file';
  }
}
