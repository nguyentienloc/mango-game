import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterance.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

/// Every fixed, vocabulary, trace and balloon utterance must have a generated clip before release.
/// Clips bake in the default names from profile_defaults.json; if names ever become
/// editable, regenerate the clips.
void main() {
  test('every part of every fixed, vocabulary, trace, balloon and Vietnamese-letter utterance has a generated clip', () async {
    final content = await ContentRepository(FileContentSource('content')).load();
    final defaults = content.profileDefaults;
    final planned = enumerateUtterances(content, Names(en: defaults.nameEn, vi: defaults.nameVi));
    final clips = (jsonDecode(File('content/audio/index.json').readAsStringSync())['clips'] as Map).cast<String, String>();

    bool hasPart(UtterancePart part) {
      final file = clips[part.key];
      return file != null && File('content/audio/$file').existsSync();
    }

    final missing = {
      for (final p in planned)
        for (final part in p.utterance.parts)
          if (!hasPart(part)) part.key,
    };
    expect(planned.where((p) => p.kind == UtteranceKind.balloon), isNotEmpty);
    // 8 questions + 8 model answers, all spoken by the talk game; talk is a required kind.
    expect(planned.where((p) => p.kind == UtteranceKind.talk), hasLength(content.conversation.length * 2));
    expect(content.conversation, hasLength(8));
    expect(planned.where((p) => p.kind == UtteranceKind.viLetters), hasLength(29 * 6));
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
