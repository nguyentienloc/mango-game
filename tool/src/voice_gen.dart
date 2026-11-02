import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Pure helpers for tool/gen_voice.dart (Vbee TTS), kept free of I/O so they
/// can be unit-tested.

const provider = 'vbee';
const voiceSpeed = 0.9;
const _voices = {
  'vi': 'hn_female_ngochuyen_full_48k-fhg', // HN - Ngọc Huyền
  'en': 'en-GB-Standard-N', // Clementine
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
/// 429 = too many concurrent requests (retry); 401/403 or a credit/package
/// problem = nothing will work (stop the run); anything else fails that part.
VbeeErrorAction classifyVbeeError(
  int httpStatus,
  String? code,
  String? message,
) {
  if (httpStatus == 429) return VbeeErrorAction.retry;
  if (httpStatus == 401 || httpStatus == 403) return VbeeErrorAction.stopRun;
  if (code == 'BAD_REQUEST' &&
      RegExp('credit|package', caseSensitive: false).hasMatch(message ?? '')) {
    return VbeeErrorAction.stopRun;
  }
  return VbeeErrorAction.fail;
}

/// `[en en-GB-Standard-N "Lion!"] message`: which part failed, on which voice.
String formatPartFailure(
  String lang,
  String voice,
  String text,
  String message,
) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final short = flat.runes.length > 40
      ? '${String.fromCharCodes(flat.runes.take(40))}…'
      : flat;
  return '[$lang $voice "$short"] $message';
}

/// Counts failures per voice; trips when one voice fails [threshold] times in
/// a row (a success of that voice resets its streak).
class VoiceCircuitBreaker {
  VoiceCircuitBreaker({this.threshold = 5});

  final int threshold;
  final _streak = <String, int>{};
  final _total = <String, int>{};

  /// Records a failure; true when this voice has now failed [threshold] times in a row.
  bool recordFailure(String voice) {
    _total[voice] = (_total[voice] ?? 0) + 1;
    final n = _streak[voice] = (_streak[voice] ?? 0) + 1;
    return n >= threshold;
  }

  void recordSuccess(String voice) => _streak[voice] = 0;

  /// Total failures per voice code.
  Map<String, int> get tally => Map.unmodifiable(_total);
}

/// Replaces every non-empty secret in [text] with `***`.
String redactSecrets(String text, Iterable<String> secrets) {
  var out = text;
  for (final s in secrets) {
    if (s.isNotEmpty) out = out.replaceAll(s, '***');
  }
  return out;
}

/// One `KEY=value` line of vbee.env; accepts `export KEY=value`, spaces around
/// `=` and single/double quotes. Comments and junk give null.
MapEntry<String, String>? parseEnvLine(String line) {
  var t = line.trim();
  if (t.isEmpty || t.startsWith('#')) return null;
  if (t.startsWith(RegExp(r'export\s'))) t = t.substring(6).trim();
  final eq = t.indexOf('=');
  if (eq < 1) return null;
  final key = t.substring(0, eq).trim();
  var v = t.substring(eq + 1).trim();
  if (v.length >= 2 &&
      ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'")))) {
    v = v.substring(1, v.length - 1);
  }
  return MapEntry(key, v);
}

class GenArgs {
  const GenArgs({
    this.limit,
    this.only,
    this.prune = false,
    this.dryRun = false,
  });

  final int? limit;
  final String? only;
  final bool prune;
  final bool dryRun;
}

/// Parses the generator's command line; throws [FormatException] on bad input.
GenArgs parseGenArgs(List<String> args) {
  int? limit;
  String? only;
  var prune = false;
  var dryRun = false;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    switch (a) {
      case '--prune':
        prune = true;
      case '--dry-run':
        dryRun = true;
      case '--limit':
        final v = i + 1 < args.length ? int.tryParse(args[++i]) : null;
        if (v == null || v < 0) {
          throw const FormatException('--limit cần một số nguyên >= 0');
        }
        limit = v;
      case '--only':
        final v = i + 1 < args.length ? args[++i] : '';
        if (v.isEmpty || v.startsWith('--')) {
          throw const FormatException('--only cần một đoạn văn bản');
        }
        only = v;
      default:
        throw FormatException('Tùy chọn không hợp lệ: $a');
    }
  }
  return GenArgs(limit: limit, only: only, prune: prune, dryRun: dryRun);
}
