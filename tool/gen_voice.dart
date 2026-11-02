import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterance.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

import 'src/voice_gen.dart';

/// Pre-generates the Vbee voices (Vietnamese: HN - Ngọc Huyền, English: Clementine)
/// for every utterance into content/audio/*.ogg + content/audio/index.json.
/// Resumable: skips clips that already exist. Each single-language part is
/// synthesised on its own (cached in build/voice-parts/) and the parts of an
/// utterance are joined with a short silence. Vbee credentials come from
/// ~/.config/xoai/vbee.env (VBEE_APP_ID, VBEE_TOKEN) or the same environment
/// variables, and are never written or printed.
///
///   dart run tool/gen_voice.dart [--limit N] [--only TEXT] [--prune] [--dry-run]
///
/// --only restricts generation to utterances whose key contains TEXT.
const _api = 'https://api.vbee.vn/v1/tts';
// The API requires a webhook in async mode; .invalid is a reserved TLD, so the
// callback can never reach a real server (we poll instead).
const _webhook = 'https://xoai-callback.invalid/vbee';
const _concurrency = 3;
const _gapSeconds = 0.25;
const _pollEvery = Duration(seconds: 2);
const _pollTimeout = Duration(seconds: 120);
const _connectTimeout = Duration(seconds: 15);
const _requestTimeout = Duration(seconds: 60);

/// Secrets to mask in every stderr message (set once the credentials are read).
var _secrets = <String>[];
void _err(String message) => stderr.writeln(redactSecrets(message, _secrets));

Future<void> main(List<String> args) async {
  final GenArgs opts;
  try {
    opts = parseGenArgs(args);
  } on FormatException catch (e) {
    _err(
      '${e.message}\nDùng: dart run tool/gen_voice.dart [--limit N] [--only TEXT] [--prune] [--dry-run]',
    );
    exit(1);
  }
  final limit = opts.limit;
  final prune = opts.prune;
  final dryRun = opts.dryRun;
  final only = opts.only;

  final content = await ContentRepository(FileContentSource('content')).load();
  final d = content.profileDefaults;
  final planned = enumerateUtterances(
    content,
    Names(en: d.nameEn, vi: d.nameVi),
  );

  final dir = Directory('content/audio')..createSync(recursive: true);
  final indexFile = File('${dir.path}/index.json');
  var clips = <String, String>{};
  if (indexFile.existsSync()) {
    final index =
        jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
    if (indexIsStale(index)) {
      stdout.writeln(
        'Index tạo bằng giọng/cấu hình khác: coi mọi clip cũ là hết hạn (dùng --prune để xóa file cũ).',
      );
    } else {
      clips = (index['clips'] as Map<String, dynamic>).cast<String, String>();
      // Forget entries whose file vanished, so the index never points at nothing.
      clips.removeWhere((_, f) => !File('${dir.path}/$f').existsSync());
    }
  }

  void saveIndex() {
    final sorted = Map.fromEntries(
      clips.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final tmp = File('${indexFile.path}.tmp')
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({...indexMeta(), 'clips': sorted}),
      );
    tmp.renameSync(indexFile.path);
  }

  final todo = [
    for (final p in planned)
      if ((only == null || p.utterance.key.contains(only)) &&
          !(clips.containsKey(p.utterance.key) &&
              File('${dir.path}/${clips[p.utterance.key]}').existsSync()))
        p,
  ];
  stdout.writeln('${planned.length} utterances, ${todo.length} to generate.');
  if (dryRun) {
    final byKind = <UtteranceKind, int>{};
    for (final p in planned) {
      byKind[p.kind] = (byKind[p.kind] ?? 0) + 1;
    }
    stdout.writeln(
      'By kind (all): ${byKind.entries.map((e) => '${e.key.name}=${e.value}').join(', ')}',
    );
    final parts = <String, UtterancePart>{};
    for (final p in todo) {
      for (final part in p.utterance.parts) {
        parts[partCacheKey(
              part.lang,
              part.text,
              voiceFor(part.lang),
              voiceSpeed,
            )] =
            part;
      }
    }
    final uncached = parts.entries
        .where((e) => !_partFile(e.key).existsSync())
        .toList();
    final chars = uncached.fold<int>(
      0,
      (n, e) => n + e.value.text.runes.length,
    );
    stdout.writeln(
      'Unique parts for these: ${parts.length} (${uncached.length} not cached, ~$chars characters to synthesise).',
    );
    for (final p in todo) {
      stdout.writeln('  [${p.kind.name}] ${p.utterance.key}');
    }
    return;
  }

  await _preflightFfmpeg();
  final creds = _readCredentials();
  final client = HttpClient()..connectionTimeout = _connectTimeout;
  final breaker = VoiceCircuitBreaker();
  final vbee = _Vbee(client, creds.appId, creds.token, breaker);
  final queue = (limit == null ? todo : todo.take(limit)).toList();
  var next = 0;
  var done = 0;
  var stopped = false;
  String? stopReason;
  final failures = <String>[];

  Future<void> worker() async {
    while (!stopped && next < queue.length) {
      final p = queue[next++];
      try {
        final parts = [
          for (final part in p.utterance.parts) await vbee.part(part),
        ];
        final file =
            '${sha1.convert(utf8.encode(p.utterance.key)).toString().substring(0, 16)}.ogg';
        await _toOgg(parts, File('${dir.path}/$file'));
        clips[p.utterance.key] = file;
        saveIndex();
        done++;
        stdout.writeln(
          '✓ ${queue.length - done} left  [${p.kind.name}] ${p.utterance.spokenText}',
        );
      } on _StopRun catch (e) {
        stopped = true;
        stopReason ??= e.message;
      } on Object catch (e) {
        failures.add(p.utterance.key);
        _err('✗ [${p.kind.name}] ${p.utterance.spokenText}: $e');
      }
    }
  }

  try {
    await Future.wait([for (var i = 0; i < _concurrency; i++) worker()]);
  } finally {
    client.close();
    saveIndex();
  }
  final remaining = todo.length - done;
  if (breaker.tally.isNotEmpty) {
    _err(
      'Lỗi theo giọng: ${breaker.tally.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
    );
  }
  if (stopped) {
    _err('⏸ Dừng: $stopReason');
    _err(
      'Đã tạo $done câu, còn $remaining câu. Khắc phục rồi chạy lại để tiếp tục.',
    );
    exitCode = 2;
  } else if (failures.isNotEmpty) {
    _err('Đã tạo $done câu, ${failures.length} câu lỗi (chạy lại để thử lại).');
    exitCode = 1;
  } else if (limit != null) {
    stdout.writeln('Đã tạo $done câu, còn $remaining câu.');
  }

  if (prune) {
    final keep = {for (final p in planned) p.utterance.key};
    clips.removeWhere((k, _) => !keep.contains(k));
    saveIndex(); // index first, so a crash never leaves it pointing at deleted files
    final files = clips.values.toSet();
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.part') || (name.endsWith('.ogg') && !files.contains(name))) f.deleteSync();
    }
  }
}

class _Credentials {
  _Credentials(this.appId, this.token);
  final String appId;
  final String token;
}

_Credentials _readCredentials() {
  final values = <String, String>{};
  final file = File('${Platform.environment['HOME']}/.config/xoai/vbee.env');
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final e = parseEnvLine(line);
      if (e != null) values[e.key] = e.value;
    }
  }
  for (final k in ['VBEE_APP_ID', 'VBEE_TOKEN']) {
    final env = Platform.environment[k];
    if (env != null && env.trim().isNotEmpty) values[k] = env.trim();
  }
  final appId = values['VBEE_APP_ID'] ?? '';
  final token = values['VBEE_TOKEN'] ?? '';
  if (appId.isEmpty || token.isEmpty) {
    _err(
      'Thiếu khóa Vbee: tạo ~/.config/xoai/vbee.env (VBEE_APP_ID=…, VBEE_TOKEN=…) hoặc đặt biến môi trường cùng tên.',
    );
    exit(1);
  }
  _secrets = [token, appId];
  return _Credentials(appId, token);
}

/// Nothing more can succeed (auth/credit problem, or a voice keeps failing).
class _StopRun implements Exception {
  _StopRun(this.message);
  final String message;
  @override
  String toString() => message;
}

class _VbeeFailure implements Exception {
  _VbeeFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One part failed; the message already names its lang, voice and text.
class _PartFailure implements Exception {
  _PartFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

File _partFile(String cacheKey) => File('build/voice-parts/$cacheKey.mp3');

class _Vbee {
  _Vbee(this._client, this._appId, this._token, this._breaker);

  final VoiceCircuitBreaker _breaker;
  final HttpClient _client;
  final String _appId;
  final String _token;
  final _inFlight = <String, Future<File>>{};
  final _rng = Random();

  /// The MP3 of one part: from build/voice-parts/ if cached, else synthesised.
  /// Concurrent requests for the same part share one synthesis.
  Future<File> part(UtterancePart p) {
    final voice = voiceFor(p.lang);
    final key = partCacheKey(p.lang, p.text, voice, voiceSpeed);
    final file = _partFile(key);
    if (file.existsSync()) return Future.value(file);
    return _inFlight[key] ??= _synthesiseTracked(p, voice, file).whenComplete(
      () {
        // Block body on purpose: returning the removed future from whenComplete
        // would make it wait on itself forever.
        _inFlight.remove(key);
      },
    );
  }

  /// Synthesises one part, feeding the circuit breaker and naming the part in errors.
  Future<File> _synthesiseTracked(
    UtterancePart p,
    String voice,
    File out,
  ) async {
    try {
      final f = await _synthesise(p.text, voice, out);
      _breaker.recordSuccess(voice);
      return f;
    } on _StopRun catch (e) {
      throw _StopRun(formatPartFailure(p.lang, voice, p.text, e.message));
    } on Object catch (e) {
      final msg = formatPartFailure(p.lang, voice, p.text, '$e');
      if (_breaker.recordFailure(voice)) {
        throw _StopRun(
          'giọng $voice bị Vbee từ chối liên tục — có thể gói không hỗ trợ (lần cuối: $msg)',
        );
      }
      throw _PartFailure(msg);
    }
  }

  Future<File> _synthesise(String text, String voice, File out) async {
    final created = await _request('POST', Uri.parse(_api), {
      'text': text,
      'voiceCode': voice,
      'mode': 'async',
      'outputFormat': 'mp3',
      'bitrate': 128,
      'speed': voiceSpeed,
      'webhookUrl': _webhook,
    });
    final id = created['requestId'];
    if (id is! String) throw _VbeeFailure('Vbee: no requestId in response');

    final deadline = DateTime.now().add(_pollTimeout);
    while (true) {
      await Future<void>.delayed(_pollEvery);
      final res = await _request('GET', Uri.parse('$_api/requests/$id'));
      final status = res['status'];
      if (status == 'COMPLETED') {
        final link = res['audioLink'] ?? (res['result'] as Map?)?['audioLink'];
        if (link is! String) {
          throw _VbeeFailure('Vbee: COMPLETED without audioLink');
        }
        return _download(link, out);
      }
      if (status != 'PROCESSING') {
        throw _VbeeFailure(
          'Vbee: request $id ended with status $status ${_short(jsonEncode(res))}',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw _VbeeFailure(
          'Vbee: request $id timed out after ${_pollTimeout.inSeconds}s',
        );
      }
    }
  }

  /// Authenticated JSON call with retry/backoff on HTTP 429.
  Future<Map<String, dynamic>> _request(
    String method,
    Uri url, [
    Object? body,
  ]) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      late final HttpClientResponse res;
      late final String text;
      await (() async {
        final req = await _client.openUrl(method, url);
        req.headers
          ..set('Authorization', 'Bearer $_token')
          ..set('App-Id', _appId)
          ..contentType = ContentType.json;
        if (body != null) req.add(utf8.encode(jsonEncode(body)));
        res = await req.close();
        text = await res.transform(utf8.decoder).join();
      })().timeout(_requestTimeout);
      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        // not JSON: handled below
      }
      final error = json?['error'];
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          error == null &&
          json != null) {
        return json;
      }

      final code = error is Map ? error['code']?.toString() : null;
      final message = error is Map ? error['message']?.toString() : null;
      switch (classifyVbeeError(res.statusCode, code, message)) {
        case VbeeErrorAction.retry:
          final wait = Duration(
            milliseconds:
                min(30000, 2000 * (1 << attempt)) + _rng.nextInt(1000),
          );
          await Future<void>.delayed(wait);
        case VbeeErrorAction.stopRun:
          final auth = res.statusCode == 401 || res.statusCode == 403;
          throw _StopRun(
            '${auth ? 'Vbee từ chối khóa (kiểm tra VBEE_APP_ID/VBEE_TOKEN)' : 'Hết credit/gói Vbee'}: '
            'HTTP ${res.statusCode} ${code ?? ''} ${message ?? _short(text)}',
          );
        case VbeeErrorAction.fail:
          throw _VbeeFailure(
            'Vbee HTTP ${res.statusCode} ${code ?? ''}: ${message ?? _short(text)}',
          );
      }
    }
    throw _VbeeFailure('Vbee: too many 429 retries');
  }

  /// The audioLink is a signed URL that redirects to S3: no auth headers, follow redirects.
  Future<File> _download(String link, File out) =>
      _downloadOnce(link, out).timeout(_requestTimeout);

  Future<File> _downloadOnce(String link, File out) async {
    out.parent.createSync(recursive: true);
    final req = await _client.getUrl(Uri.parse(link));
    req.followRedirects = true;
    final res = await req.close();
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw _VbeeFailure('Vbee: audio download HTTP ${res.statusCode}');
    }
    final bytes = <int>[];
    await for (final chunk in res) {
      bytes.addAll(chunk);
    }
    if (bytes.isEmpty) throw _VbeeFailure('Vbee: empty audio download');
    final tmp = File('${out.path}.tmp')..writeAsBytesSync(bytes);
    tmp.renameSync(out.path);
    return out;
  }
}

String _short(String s) {
  final flat = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length > 300 ? flat.substring(0, 300) : flat;
}

/// Fails fast (before spending credits) when ffmpeg or libopus is missing.
Future<void> _preflightFfmpeg() async {
  try {
    final r = await Process.run('ffmpeg', ['-hide_banner', '-encoders']);
    if (r.exitCode == 0 && '${r.stdout}'.contains('libopus')) return;
    _err('ffmpeg có nhưng thiếu bộ mã hóa libopus.');
  } on ProcessException {
    _err(
      'Không tìm thấy ffmpeg (cần ffmpeg có libopus, ví dụ: brew install ffmpeg).',
    );
  }
  exit(1);
}

/// Joins the part MP3s with a short silence between them and encodes Opus mono
/// 32 kbps to `<name>.ogg.part` (forced `-f ogg`), then renames, so a crash never leaves
/// a half-written `.ogg` that could get bundled. The part MP3s stay cached in build/voice-parts/, so an
/// ffmpeg failure never wastes credits.
Future<void> _toOgg(List<File> parts, File out) async {
  final tmpOgg = File('${out.path}.part');
  final inputs = <String>[];
  var n = 0; // number of ffmpeg inputs so far
  for (var i = 0; i < parts.length; i++) {
    if (i > 0) {
      inputs.addAll([
        '-f',
        'lavfi',
        '-t',
        '$_gapSeconds',
        '-i',
        'anullsrc=r=48000:cl=mono',
      ]);
      n++;
    }
    inputs.addAll(['-i', parts[i].path]);
    n++;
  }
  final filter = [
    for (var i = 0; i < n; i++)
      '[$i:a]aformat=sample_rates=48000:channel_layouts=mono[n$i]',
    '${[for (var i = 0; i < n; i++) '[n$i]'].join()}concat=n=$n:v=0:a=1[out]',
  ].join(';');
  try {
    final r = await Process.run('ffmpeg', [
      '-y',
      '-loglevel',
      'error',
      ...inputs,
      '-filter_complex',
      filter,
      '-map',
      '[out]',
      '-ac',
      '1',
      '-c:a',
      'libopus',
      '-b:a',
      '32k',
      '-application',
      'voip',
      '-f',
      'ogg',
      tmpOgg.path,
    ]);
    if (r.exitCode != 0) {
      throw ProcessException('ffmpeg', [], '${r.stderr}', r.exitCode);
    }
    tmpOgg.renameSync(out.path);
  } on Object {
    if (tmpOgg.existsSync()) tmpOgg.deleteSync();
    rethrow;
  }
}
