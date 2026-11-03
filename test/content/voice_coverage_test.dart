import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterance.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

/// Every fixed, vocabulary and trace utterance must have a generated clip before release.
/// Clips bake in the default names from profile_defaults.json; if names ever become
/// editable, regenerate the clips.
/// Letter-game clips are optional while that game is hidden: only reported.
void main() {
  test('every part of every fixed, vocabulary and trace utterance has a generated clip', () async {
    final content = await ContentRepository(FileContentSource('content')).load();
    final defaults = content.profileDefaults;
    final planned = enumerateUtterances(content, Names(en: defaults.nameEn, vi: defaults.nameVi));
    final clips = (jsonDecode(File('content/audio/index.json').readAsStringSync())['clips'] as Map).cast<String, String>();

    bool hasPart(UtterancePart part) {
      final file = clips[part.key];
      return file != null && File('content/audio/$file').existsSync();
    }

    bool has(PlannedUtterance p) => p.utterance.parts.every(hasPart);

    final missing = {
      for (final p in planned)
        if (p.kind != UtteranceKind.letters)
          for (final part in p.utterance.parts)
            if (!hasPart(part)) part.key,
    };
    final missingLetters = planned.where((p) => p.kind == UtteranceKind.letters && !has(p)).length;
    if (missingLetters > 0) {
      // ignore: avoid_print
      print('Note: $missingLetters letter-game utterances have no clip (TTS fallback).');
    }
    expect(missing, isEmpty, reason: 'Run: dart run tool/gen_voice.dart');
  });

  test('numbers 0..999 are a required kind: each has a clip for its number part', () async {
    final content = await ContentRepository(FileContentSource('content')).load();
    final defaults = content.profileDefaults;
    final planned = enumerateUtterances(content, Names(en: defaults.nameEn, vi: defaults.nameVi));
    final numbers = planned.where((p) => p.kind == UtteranceKind.numbers).toList();
    expect(numbers, hasLength(1000));
    final clips = (jsonDecode(File('content/audio/index.json').readAsStringSync())['clips'] as Map).cast<String, String>();
    final missing = [
      for (final p in numbers)
        for (final part in p.utterance.parts)
          if (clips[part.key] == null || !File('content/audio/${clips[part.key]}').existsSync()) part.key,
    ];
    expect(missing.toSet(), isEmpty, reason: 'Run: dart run tool/gen_voice.dart --allow-api');
  });
}
