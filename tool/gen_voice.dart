import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/tts_quota.dart';
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
    final tmp = File('${indexFile.path}.tmp')
      ..writeAsStringSync(const JsonEncoder.withIndent('  ')
          .convert({'voice': _voice, 'model': _model, 'style': _style, 'clips': sorted}));
    tmp.renameSync(indexFile.path);
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

  await _preflightFfmpeg();
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
    saveIndex(); // index first, so a crash never leaves it pointing at deleted files
    final files = clips.values.toSet();
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.ogg') && !files.contains(name)) f.deleteSync();
    }
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
      final wait = quotaWaitSeconds(resBody);
      if (wait == null) {
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

/// Fails fast (before spending API quota) when ffmpeg or libopus is missing.
Future<void> _preflightFfmpeg() async {
  try {
    final r = await Process.run('ffmpeg', ['-hide_banner', '-encoders']);
    if (r.exitCode == 0 && '${r.stdout}'.contains('libopus')) return;
    stderr.writeln('ffmpeg có nhưng thiếu bộ mã hóa libopus.');
  } on ProcessException {
    stderr.writeln('Không tìm thấy ffmpeg (cần ffmpeg có libopus, ví dụ: brew install ffmpeg).');
  }
  exit(1);
}

/// Encodes to `<name>.tmp.ogg` and renames, so an interrupted run never leaves a
/// half-written clip. If ffmpeg fails the WAV is kept (path printed), since the
/// API call it came from already used quota.
Future<void> _toOgg(List<int> wav, File out) async {
  final tmpWav = File('${Directory.systemTemp.path}/xoai-${DateTime.now().microsecondsSinceEpoch}.wav')
    ..writeAsBytesSync(wav);
  final tmpOgg = File('${out.path}.tmp.ogg');
  try {
    final r = await Process.run('ffmpeg', [
      '-y', '-loglevel', 'error', '-i', tmpWav.path,
      '-ac', '1', '-c:a', 'libopus', '-b:a', '32k', '-application', 'voip', tmpOgg.path,
    ]);
    if (r.exitCode != 0) throw ProcessException('ffmpeg', [], '${r.stderr}', r.exitCode);
    tmpOgg.renameSync(out.path);
    tmpWav.deleteSync();
  } on Object {
    if (tmpOgg.existsSync()) tmpOgg.deleteSync();
    stderr.writeln('ffmpeg lỗi; giữ lại WAV tại ${tmpWav.path}');
    rethrow;
  }
}
