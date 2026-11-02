import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

/// Pre-generates the Leda voice for every utterance (Gemini TTS) into
/// content/audio/*.ogg + content/audio/index.json. Resumable: skips clips that
/// already exist. The API key is read from ~/.config/xoai/gemini_api_key or
/// $GEMINI_API_KEY and is never written or printed.
///
///   dart run tool/gen_voice.dart [--limit N] [--prune] [--dry-run]
const _model = 'gemini-3.8-flash-tts';
const _voice = 'Leda';
const _style = 'a warm, cheerful young woman speaking slowly and clearly to a 5-year-old girl';
const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/interactions';

Future<void> main(List<String> args) async {
  final limitIdx = args.indexOf('--limit');
  final limit = limitIdx >= 0 ? int.parse(args[limitIdx + 1]) : null;
  final prune = args.contains('--prune');
  final dryRun = args.contains('--dry-run');

  final content = await ContentRepository(FileContentSource('content')).load();
  final d = content.profileDefaults;
  final planned = enumerateUtterances(content, Names(en: d.nameEn, vi: d.nameVi));

  final dir = Directory('content/audio')..createSync(recursive: true);
  final indexFile = File('${dir.path}/index.json');
  final clips = indexFile.existsSync()
      ? ((jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>)['clips'] as Map<String, dynamic>)
          .cast<String, String>()
      : <String, String>{};

  void saveIndex() {
    final sorted = Map.fromEntries(clips.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    indexFile.writeAsStringSync(const JsonEncoder.withIndent('  ')
        .convert({'voice': _voice, 'model': _model, 'style': _style, 'clips': sorted}));
  }

  final todo = [
    for (final p in planned)
      if (!(clips.containsKey(p.utterance.key) && File('${dir.path}/${clips[p.utterance.key]}').existsSync())) p,
  ];
  stdout.writeln('${planned.length} utterances, ${todo.length} to generate.');
  if (dryRun) {
    final byKind = <UtteranceKind, int>{};
    for (final p in planned) {
      byKind[p.kind] = (byKind[p.kind] ?? 0) + 1;
    }
    stdout.writeln('By kind (all): ${byKind.entries.map((e) => '${e.key.name}=${e.value}').join(', ')}');
    for (final p in todo) {
      stdout.writeln('  [${p.kind.name}] ${p.utterance.key}');
    }
    return;
  }

  final key = _readKey();
  final client = HttpClient();
  var done = 0;
  try {
    for (final p in todo) {
      if (limit != null && done >= limit) break;
      final file = '${sha1.convert(utf8.encode(p.utterance.key)).toString().substring(0, 16)}.ogg';
      final wav = await _tts(client, key, p.utterance.spokenText);
      await _toOgg(wav, File('${dir.path}/$file'));
      clips[p.utterance.key] = file;
      saveIndex();
      done++;
      stdout.writeln('✓ ${todo.length - done} left  [${p.kind.name}] ${p.utterance.spokenText}');
    }
  } on _DailyQuotaExceeded catch (e) {
    stderr.writeln('⏸ Hết lượt trong ngày ($e). Chạy lại sau; đã tạo $done câu.');
    exitCode = 2;
  } finally {
    client.close();
    saveIndex();
  }

  if (prune) {
    final keep = {for (final p in planned) p.utterance.key};
    clips.removeWhere((k, _) => !keep.contains(k));
    final files = clips.values.toSet();
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.ogg') && !files.contains(name)) f.deleteSync();
    }
    saveIndex();
  }
}

String _readKey() {
  final env = Platform.environment['GEMINI_API_KEY'];
  if (env != null && env.trim().isNotEmpty) return env.trim();
  final file = File('${Platform.environment['HOME']}/.config/xoai/gemini_api_key');
  if (!file.existsSync()) {
    stderr.writeln('Thiếu key: tạo ~/.config/xoai/gemini_api_key hoặc đặt GEMINI_API_KEY');
    exit(1);
  }
  return file.readAsStringSync().trim();
}

class _DailyQuotaExceeded implements Exception {
  _DailyQuotaExceeded(this.message);
  final String message;
  @override
  String toString() => message;
}

/// True when a 429 body says the daily quota (not the per-minute one) is spent.
/// Per-minute bodies look like "... (limit: 3 requests per minute on Free Tier).
/// Please retry in 43s ...", so only an explicit daily marker counts.
bool _isDailyQuota(String body) {
  final b = body.toLowerCase();
  return b.contains('per day') || b.contains('perday') || b.contains('daily');
}

/// Parses "Please retry in 43s" / "retry in 4m55s" / "retry in 1h2m3s" into seconds.
int? _retryDelaySeconds(String body) {
  final m = RegExp(r'retry in (?:(\d+)h)?(?:(\d+)m)?(?:(\d+(?:\.\d+)?)s)?').firstMatch(body);
  if (m == null || (m[1] == null && m[2] == null && m[3] == null)) return null;
  final secs = (int.parse(m[1] ?? '0') * 3600) + (int.parse(m[2] ?? '0') * 60) + (double.parse(m[3] ?? '0')).ceil();
  return secs + 3;
}

/// Calls Gemini TTS and returns WAV bytes. Waits and retries on per-minute
/// rate limits; throws _DailyQuotaExceeded when the daily quota is used up.
Future<List<int>> _tts(HttpClient client, String key, String text) async {
  final body = jsonEncode({
    'model': _model,
    'input': [
      {
        'type': 'user_input',
        'content': [
          {
            'type': 'text',
            'text': text,
            'annotations': [
              {'type': 'speech_metadata', 'style': _style},
            ],
          },
        ],
      },
    ],
    'response_format': {'type': 'audio'},
    'generation_config': {
      'speech_config': [
        {'voice': _voice},
      ],
    },
  });
  for (var attempt = 0; attempt < 10; attempt++) {
    final req = await client.postUrl(Uri.parse(_endpoint));
    req.headers
      ..set('x-goog-api-key', key)
      ..contentType = ContentType.json;
    req.add(utf8.encode(body));
    final res = await req.close();
    final resBody = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      final json = jsonDecode(resBody) as Map<String, dynamic>;
      final audios = [
        for (final step in json['steps'] as List)
          if ((step as Map)['type'] == 'model_output')
            for (final c in step['content'] as List)
              if ((c as Map)['type'] == 'audio') c,
      ];
      if (audios.isEmpty) throw const HttpException('Gemini TTS: response has no audio');
      return base64Decode(audios.last['data'] as String);
    }
    if (res.statusCode == 429) {
      final wait = _retryDelaySeconds(resBody);
      if (wait == null || _isDailyQuota(resBody)) {
        throw _DailyQuotaExceeded('HTTP 429: ${resBody.length > 400 ? resBody.substring(0, 400) : resBody}');
      }
      stdout.writeln('… giới hạn theo phút, đợi ${wait}s');
      await Future<void>.delayed(Duration(seconds: wait));
      continue;
    }
    throw HttpException('Gemini TTS HTTP ${res.statusCode}: ${resBody.length > 300 ? resBody.substring(0, 300) : resBody}');
  }
  throw const HttpException('Gemini TTS: too many retries');
}

Future<void> _toOgg(List<int> wav, File out) async {
  final tmp = File('${Directory.systemTemp.path}/xoai-${DateTime.now().microsecondsSinceEpoch}.wav')
    ..writeAsBytesSync(wav);
  try {
    final r = await Process.run('ffmpeg', [
      '-y', '-loglevel', 'error', '-i', tmp.path,
      '-ac', '1', '-c:a', 'libopus', '-b:a', '32k', '-application', 'voip', out.path,
    ]);
    if (r.exitCode != 0) throw ProcessException('ffmpeg', [], '${r.stderr}', r.exitCode);
  } finally {
    tmp.deleteSync();
  }
}
