import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xoai_castle/core/voice/utterance.dart';

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

/// File name of a part's clip in content/audio/: sha1 of `lang|text`, 16 hex chars.
String partFileName(String partKey) =>
    '${sha1.convert(utf8.encode(partKey)).toString().substring(0, 16)}.ogg';

/// Every distinct part (by `lang|text`) of [utterances], in first-seen order.
Map<String, UtterancePart> distinctParts(Iterable<Utterance> utterances) {
  final parts = <String, UtterancePart>{};
  for (final u in utterances) {
    for (final p in u.parts) {
      parts.putIfAbsent(p.key, () => p);
    }
  }
  return parts;
}

/// Generator settings recorded in content/audio/index.json (next to `clips`).
Map<String, Object> indexMeta() => {
  'provider': provider,
  'voices': {for (final e in _voices.entries) e.key: e.value},
  'speed': voiceSpeed,
  'granularity': 'part',
};

/// True when the index was made with another provider/voices/speed, or holds
/// per-utterance clips (no `granularity: part`), so all of its clips must be
/// regenerated.
bool indexIsStale(Map<String, dynamic> index) {
  final cur = indexMeta();
  if (index['provider'] != cur['provider'] ||
      index['speed'] != cur['speed'] ||
      index['granularity'] != cur['granularity']) {
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
    this.allowApi = false,
    this.batch = false,
  });

  final int? limit;
  final String? only;
  final bool prune;
  final bool dryRun;

  /// Without it, parts missing from the local cache are only reported (no Vbee call).
  final bool allowApi;

  /// Batch every uncached part per language, whatever its length (by default only
  /// parts of at most [maxBatchTextLength] characters are batched).
  final bool batch;
}

/// Parses the generator's command line; throws [FormatException] on bad input.
GenArgs parseGenArgs(List<String> args) {
  int? limit;
  String? only;
  var prune = false;
  var dryRun = false;
  var allowApi = false;
  var batch = false;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    switch (a) {
      case '--prune':
        prune = true;
      case '--dry-run':
        dryRun = true;
      case '--allow-api':
        allowApi = true;
      case '--batch':
        batch = true;
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
  return GenArgs(
    limit: limit,
    only: only,
    prune: prune,
    dryRun: dryRun,
    allowApi: allowApi,
    batch: batch,
  );
}

// ---------------------------------------------------------------------------
// Batch synthesis: many short parts in one Vbee request, split on silence.
// ---------------------------------------------------------------------------

/// Parts with at most this many characters are batched automatically.
const maxBatchTextLength = 12;

/// Most parts in one request.
const maxBatchSize = 50;

/// Silences (seconds) Vbee inserts between lines, so items can be split apart.
const batchPause = <String, double>{
  'majorBreak': 1.2,
  'mediumBreak': 1.2,
  'paragraphBreak': 1.2,
  'sentenceBreak': 1.0,
};

/// ffmpeg silencedetect settings: quiet below [silenceNoise], for at least [silenceMinDuration] s.
const silenceNoise = '-40dB';
const silenceMinDuration = 0.6;

/// Padding kept around each cut item.
const cutPadding = 0.08;

class BatchPlan {
  const BatchPlan(this.batches, this.single);

  /// Groups of 2..[maxBatchSize] parts of one language, in the order given.
  final List<List<UtterancePart>> batches;

  /// Keys of parts that are synthesised on their own.
  final List<String> single;
}

/// Groups [parts] (uncached ones) into batches. Short parts of the same language
/// share a batch; long ones (unless [forceAll]) and lone leftovers stay single.
BatchPlan planBatches(Iterable<UtterancePart> parts, {bool forceAll = false}) {
  final byLang = <String, List<UtterancePart>>{};
  final single = <String>[];
  for (final p in parts) {
    if (forceAll || p.text.runes.length <= maxBatchTextLength) {
      byLang.putIfAbsent(p.lang, () => []).add(p);
    } else {
      single.add(p.key);
    }
  }
  final batches = <List<UtterancePart>>[];
  for (final list in byLang.values) {
    for (var i = 0; i < list.length; i += maxBatchSize) {
      final chunk = list.sublist(i, i + maxBatchSize > list.length ? list.length : i + maxBatchSize);
      if (chunk.length < 2) {
        single.addAll(chunk.map((p) => p.key));
      } else {
        batches.add(chunk);
      }
    }
  }
  return BatchPlan(batches, single);
}

/// One part per line, each ended by a full stop (unless it already ends in
/// punctuation) so the voice reads every line as its own sentence.
String batchText(List<UtterancePart> parts) => parts.map((p) => _closed(p.text)).join('\n');

String _closed(String t) => RegExp(r'[.!?…,;:]$').hasMatch(t) ? t : '$t.';

/// Cache key of a batch MP3 (so a re-run never pays twice for the same batch).
String batchCacheKey(String lang, List<String> texts, String voice, double speed) =>
    sha1.convert(utf8.encode('batch2|$lang|${texts.join('\n')}|$voice|$speed|${batchPause.values.join(',')}')).toString();

/// A silent stretch; [end] is null when the file ends while still silent.
class Silence {
  const Silence(this.start, this.end);
  final double start;
  final double? end;
}

/// A stretch of speech between silences, in seconds.
class Segment {
  const Segment(this.start, this.end);
  final double start;
  final double end;
}

final _silenceStart = RegExp(r'silence_start:\s*(-?[\d.]+)');
final _silenceEnd = RegExp(r'silence_end:\s*(-?[\d.]+)');
final _duration = RegExp(r'Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)');

/// Silences found by `ffmpeg -af silencedetect` in its stderr.
List<Silence> parseSilences(String stderr) {
  final out = <Silence>[];
  double? open;
  for (final line in stderr.split('\n')) {
    final s = _silenceStart.firstMatch(line);
    if (s != null) {
      if (open != null) out.add(Silence(open, null));
      open = double.tryParse(s[1]!);
      continue;
    }
    final e = _silenceEnd.firstMatch(line);
    if (e != null && open != null) {
      out.add(Silence(open, double.tryParse(e[1]!)));
      open = null;
    }
  }
  if (open != null) out.add(Silence(open, null));
  return out;
}

/// Total length in seconds from ffmpeg's `Duration: hh:mm:ss.xx` line.
double? parseDuration(String stderr) {
  final m = _duration.firstMatch(stderr);
  if (m == null) return null;
  return int.parse(m[1]!) * 3600 + int.parse(m[2]!) * 60 + double.parse(m[3]!);
}

/// Speech shorter than this is encoder noise at an edge, not an item.
const minSpeech = 0.1;

/// The speech between [silences] in a file of [total] seconds.
List<Segment> speechSegments(List<Silence> silences, double total) {
  final out = <Segment>[];
  void add(double a, double b) {
    if (b - a >= minSpeech) out.add(Segment(a, b));
  }

  var at = 0.0;
  for (final s in silences) {
    add(at, s.start);
    at = s.end ?? total;
  }
  add(at, total);
  return out;
}

/// Only a perfect count match is trusted; the mapping is never guessed.
bool canSplit(int items, List<Segment> segments) => items > 0 && segments.length == items;

/// The cut for [s]: padded by [cutPadding] on both sides, clamped to the file.
Segment cutWindow(Segment s, double total) =>
    Segment((s.start - cutPadding).clamp(0.0, total), (s.end + cutPadding).clamp(0.0, total));
