import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:xoai_castle/core/voice/utterance.dart';

/// Pure helpers for the local voice provider of tool/gen_voice.dart:
/// Vietnamese through a running VieNeu-TTS Gradio server, English through
/// Kokoro-82M. Free of I/O so they can be unit-tested.

/// A local TTS voice: which engine reads it, the voice name, and the settings
/// that change the audio (all of them go into the part cache key).
class LocalVoice {
  const LocalVoice(this.engine, this.name, this.settings);

  final String engine;
  final String name;
  final Map<String, num> settings;

  /// `vieneu:Trúc Ly`: recorded in content/audio/index.json.
  String get id => '$engine:$name';
}

const vieneuEngine = 'vieneu';
const kokoroEngine = 'kokoro';

/// Kokoro reading speed for English: slow, for a 5-year-old (`--en-speed`).
const defaultEnSpeed = 0.8;

/// The local voices; [enSpeed] is the Kokoro speed (part of every English cache key).
Map<String, LocalVoice> localVoicesFor({double enSpeed = defaultEnSpeed}) => {
  'vi': const LocalVoice(vieneuEngine, 'Trúc Ly', {'temperature': 0.7}),
  'en': LocalVoice(kokoroEngine, 'af_heart', {'speed': enSpeed}),
};

/// The local voices at the default speeds.
final localVoices = localVoicesFor();

LocalVoice localVoiceFor(String lang, {double enSpeed = defaultEnSpeed}) {
  final v = localVoicesFor(enSpeed: enSpeed)[lang];
  if (v == null) {
    throw ArgumentError.value(lang, 'lang', 'no local voice configured');
  }
  return v;
}

/// Bumped when the text sent to the engines changes (e.g. [closeSentence]),
/// so cached WAVs made the old way are not reused.
const localTextRecipe = 'close1';

/// What the engine is asked to read: a line that does not end in `.`, `!`, `?`
/// (or `…`) gets a full stop, so a bare word is read as a whole utterance
/// instead of sounding cut off.
String closeSentence(String text) {
  final t = text.trimRight();
  return RegExp(r'[.!?…]$').hasMatch(t) ? t : '$t.';
}

/// Cache key of one locally synthesised part: provider, language, text, voice
/// and its settings. Never equal to a Vbee key, so the caches cannot mix.
String localPartCacheKey(String lang, String text, {LocalVoice? voice, double enSpeed = defaultEnSpeed}) {
  final v = voice ?? localVoiceFor(lang, enSpeed: enSpeed);
  final settings = (v.settings.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      .map((e) => '${e.key}=${e.value}')
      .join(',');
  return sha1.convert(utf8.encode('local|$lang|$text|${v.id}|$settings|$localTextRecipe')).toString();
}

// ---------------------------------------------------------------------------
// Jobs for the Python helpers (tool/tts/*_batch.py).
// ---------------------------------------------------------------------------

/// One line for a helper: [text] is what is read (already closed), [out] the WAV to write.
class LocalJobItem {
  const LocalJobItem(this.key, this.text, this.out);

  /// The part key (`lang|text`).
  final String key;
  final String text;
  final String out;
}

class LocalJobPlan {
  const LocalJobPlan(this.jobs, this.unsupported);

  /// Items per engine ([vieneuEngine], [kokoroEngine]), in the order given.
  final Map<String, List<LocalJobItem>> jobs;

  /// Keys of parts in a language no local voice reads.
  final List<String> unsupported;
}

/// Splits [parts] into one job per engine; each WAV goes to `<cacheDir>/<key>.wav`.
LocalJobPlan planLocalJobs(Iterable<UtterancePart> parts, String cacheDir, {double enSpeed = defaultEnSpeed}) {
  final voices = localVoicesFor(enSpeed: enSpeed);
  final jobs = <String, List<LocalJobItem>>{};
  final unsupported = <String>[];
  for (final p in parts) {
    final voice = voices[p.lang];
    if (voice == null) {
      unsupported.add(p.key);
      continue;
    }
    jobs.putIfAbsent(voice.engine, () => []).add(
      LocalJobItem(p.key, closeSentence(p.text), '$cacheDir/${localPartCacheKey(p.lang, p.text, voice: voice)}.wav'),
    );
  }
  return LocalJobPlan(jobs, unsupported);
}

/// Parallel Gradio clients the VieNeu helper runs.
const vieneuWorkers = 4;
const defaultVieneuUrl = 'http://127.0.0.1:7860';
const defaultKokoroPython = '/Users/locnguyen/orca/projects/claude-tiktok/.venv-kokoro/bin/python';

String vieneuUrl(Map<String, String> env) {
  final v = env['VIENEU_URL']?.trim() ?? '';
  return v.isEmpty ? defaultVieneuUrl : v;
}

String kokoroPython(Map<String, String> env) {
  final v = env['KOKORO_PYTHON']?.trim() ?? '';
  return v.isEmpty ? defaultKokoroPython : v;
}

/// The JSON job file the [engine]'s helper reads.
Map<String, Object> jobJson(
  String engine,
  List<LocalJobItem> items,
  Map<String, String> env, {
  double enSpeed = defaultEnSpeed,
}) {
  final list = [
    for (final i in items) {'text': i.text, 'out': i.out},
  ];
  return switch (engine) {
    vieneuEngine => {
      'url': vieneuUrl(env),
      'voice': localVoices['vi']!.name,
      'temperature': localVoices['vi']!.settings['temperature']!,
      'workers': vieneuWorkers,
      'items': list,
    },
    kokoroEngine => {
      'voice': localVoices['en']!.name,
      'speed': enSpeed,
      'items': list,
    },
    _ => throw ArgumentError.value(engine, 'engine'),
  };
}

class HelperCommand {
  const HelperCommand(this.executable, this.arguments, [this.environment = const {}]);

  final String executable;
  final List<String> arguments;

  /// Added to the inherited environment.
  final Map<String, String> environment;
}

/// How to run the [engine]'s helper on [jobPath].
HelperCommand helperCommand(String engine, String jobPath, Map<String, String> env) => switch (engine) {
  vieneuEngine => HelperCommand('uv', [
    'run',
    '--quiet',
    '--with',
    'gradio_client',
    'python',
    '-I',
    'tool/tts/vieneu_batch.py',
    jobPath,
  ]),
  // The model is already in the Hugging Face cache: never reach the network for it.
  kokoroEngine => HelperCommand(kokoroPython(env), [
    '-I',
    'tool/tts/kokoro_batch.py',
    jobPath,
  ], {if (!env.containsKey('HF_HUB_OFFLINE')) 'HF_HUB_OFFLINE': '1'}),
  _ => throw ArgumentError.value(engine, 'engine'),
};

/// Exit code of a helper that cannot reach its engine (server down, Kokoro missing).
const helperUnavailableExit = 3;

final _failLine = RegExp(r'^FAIL (\d+) ?(.*)$');

/// `FAIL <i> <message>` lines of a helper's stderr, by item index.
Map<int, String> parseHelperFailures(String stderr) => {
  for (final line in const LineSplitter().convert(stderr))
    if (_failLine.firstMatch(line.trim()) case final m?) int.parse(m[1]!): m[2]!,
};

/// The last meaningful stderr line (Python warnings come first), for an error message.
String lastLine(String stderr) {
  final lines = const LineSplitter().convert(stderr).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  return lines.isEmpty ? '' : lines.last;
}

// ---------------------------------------------------------------------------
// Post-processing: trim, level, pad, encode.
// ---------------------------------------------------------------------------

/// Quieter than this at either end is silence to cut.
const trimThreshold = '-45dB';

/// Silence (seconds) added at both ends after trimming.
const edgePad = 0.15;

/// Mean loudness every clip is brought to (the Vbee clips sat near -19 dB).
const targetMeanDb = -19.0;

/// Peaks never go above this after levelling.
const peakCeilingDb = -1.0;

/// Recorded in index.json; change it when the chain below changes.
const localPostRecipe = 'trim$trimThreshold,level${targetMeanDb}dB,pad${edgePad}s';

/// Cuts leading and trailing silence (keeping 30 ms before the first sound).
const trimFilter =
    'silenceremove=start_periods=1:start_threshold=$trimThreshold:start_silence=0.03,'
    'areverse,'
    'silenceremove=start_periods=1:start_threshold=$trimThreshold:start_silence=0.03,'
    'areverse';

/// ffmpeg arguments that measure the trimmed audio (`volumedetect` on stderr).
List<String> volumeProbeArgs(String input) => [
  '-hide_banner',
  '-nostats',
  '-i',
  input,
  '-af',
  '$trimFilter,volumedetect',
  '-f',
  'null',
  '-',
];

class VolumeStats {
  const VolumeStats(this.meanDb, this.maxDb);
  final double meanDb;
  final double maxDb;
}

final _meanVolume = RegExp(r'mean_volume:\s*(-?[\d.]+|-inf) dB');
final _maxVolume = RegExp(r'max_volume:\s*(-?[\d.]+|-inf) dB');

/// `mean_volume`/`max_volume` from ffmpeg's volumedetect; null when absent or silent.
VolumeStats? parseVolumeDetect(String stderr) {
  final mean = double.tryParse(_meanVolume.firstMatch(stderr)?[1] ?? '');
  final max = double.tryParse(_maxVolume.firstMatch(stderr)?[1] ?? '');
  if (mean == null || max == null || mean.isInfinite || max.isInfinite) return null;
  return VolumeStats(mean, max);
}

/// Gain (dB) that brings the mean to [targetMeanDb] without pushing the peak
/// over [peakCeilingDb]; never more than ±24 dB.
double levelGainDb(VolumeStats s) =>
    min(targetMeanDb - s.meanDb, peakCeilingDb - s.maxDb).clamp(-24.0, 24.0);

/// ffmpeg arguments that trim, level by [gainDb], pad [edgePad] s at both ends and
/// encode Opus mono 32 kbps (forced `-f ogg`, so `<name>.ogg.part` works).
List<String> localEncodeArgs(String input, String output, double gainDb) => [
  '-y',
  '-loglevel',
  'error',
  '-i',
  input,
  '-af',
  '$trimFilter,volume=${gainDb.toStringAsFixed(2)}dB,'
      'adelay=${(edgePad * 1000).round()}:all=1,apad=pad_dur=$edgePad',
  '-ac',
  '1',
  '-ar',
  '48000',
  '-c:a',
  'libopus',
  '-b:a',
  '32k',
  '-application',
  'voip',
  '-f',
  'ogg',
  output,
];
