import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Pure helpers for tool/gen_voice.dart (Vbee TTS), kept free of I/O so they
/// can be unit-tested.

const provider = 'vbee';
const voiceSpeed = 0.9;
const _voices = {
  'vi': 'hn_female_ngochuyen_full_48k-fhg', // HN - Ngọc Huyền
  'en': 'en-US-Neural2-G-Premium', // Sophia
};

String voiceFor(String lang) {
  final v = _voices[lang];
  if (v == null) {
    throw ArgumentError.value(lang, 'lang', 'no Vbee voice configured');
  }
  return v;
}

/// Cache key of one synthesised part (a single-language piece of an utterance).
String partCacheKey(String lang, String text, String voice, double speed) =>
    sha1.convert(utf8.encode('$lang|$text|$voice|$speed')).toString();

/// Generator settings recorded in content/audio/index.json (next to `clips`).
Map<String, Object> indexMeta() => {
  'provider': provider,
  'voices': {for (final e in _voices.entries) e.key: e.value},
  'speed': voiceSpeed,
};

/// True when the index was made with another provider/voices/speed, so all of
/// its clips must be regenerated.
bool indexIsStale(Map<String, dynamic> index) {
  final cur = indexMeta();
  if (index['provider'] != cur['provider'] || index['speed'] != cur['speed']) {
    return true;
  }
  final voices = index['voices'];
  final curVoices = cur['voices']! as Map<String, String>;
  if (voices is! Map || voices.length != curVoices.length) return true;
  return curVoices.entries.any((e) => voices[e.key] != e.value);
}

enum VbeeErrorAction { retry, stopRun, fail }

/// Maps a Vbee error response to what the generator should do next.
VbeeErrorAction classifyVbeeError(
  int httpStatus,
  String? code,
  String? message,
) {
  if (httpStatus == 429) return VbeeErrorAction.retry;
  if (code == 'BAD_REQUEST' &&
      RegExp('credit|package', caseSensitive: false).hasMatch(message ?? '')) {
    return VbeeErrorAction.stopRun;
  }
  return VbeeErrorAction.fail;
}
