import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterance.dart';
import 'package:xoai_castle/core/voice/utterances.dart';

import 'src/voice_gen.dart';

/// Builds one Opus clip per distinct utterance PART (`lang|text`) into
/// content/audio/`sha1(partKey)`.ogg + content/audio/index.json. The clips come
/// from the local MP3 part cache (build/voice-parts/); a part missing from the
/// cache is only synthesised through Vbee with --allow-api, otherwise it is
/// reported and the run exits with code 2. Vbee credentials come from
/// ~/.config/xoai/vbee.env (VBEE_APP_ID, VBEE_TOKEN) or the same environment
/// variables, and are never written or printed.
///
///   dart run tool/gen_voice.dart [--limit N] [--only TEXT] [--prune] [--dry-run] [--allow-api] [--batch]
///
/// With --allow-api, uncached parts of at most 12 characters are synthesised in
/// batches (up to 50 per Vbee request, one per line, with long pauses between)
/// and cut apart on silence with ffmpeg; --batch batches longer parts too. A batch
/// whose silence-segment count differs from its item count is never guessed at:
/// its parts fall back to one request each.
///
/// --only restricts the run to parts whose key (`lang|text`) contains TEXT.
const _api = 'https://api.vbee.vn/v1/tts';
// The API requires a webhook in async mode; .invalid is a reserved TLD, so the
// callback can never reach a real server (we poll instead).
const _webhook = 'https://xoai-callback.invalid/vbee';
const _concurrency = 3;
const _pollEvery = Duration(seconds: 2);
const _pollTimeout = Duration(seconds: 120);
const _connectTimeout = Duration(seconds: 15);
const _requestTimeout = Duration(seconds: 60);

/// Secrets to mask in every stderr message (set once the credentials are read).
var _secrets = <String>[];
void _err(String message) => stderr.writeln(
  redactSecrets(message, _secrets).replaceAll(RegExp(r'\?X-Amz-[^\s,)]*'), '?…'),
);

Future<void> main(List<String> args) async {
  final GenArgs opts;
  try {
    opts = parseGenArgs(args);
  } on FormatException catch (e) {
    _err(
      '${e.message}\nDùng: dart run tool/gen_voice.dart [--limit N] [--only TEXT] [--prune] [--dry-run] [--allow-api] [--batch]',
    );
    exit(1);
  }
  final limit = opts.limit;
  final prune = opts.prune;
  final dryRun = opts.dryRun;
  final only = opts.only;
  final allowApi = opts.allowApi;

  final content = await ContentRepository(FileContentSource('content')).load();
  final d = content.profileDefaults;
  final planned = enumerateUtterances(
    content,
    Names(en: d.nameEn, vi: d.nameVi),
  );
  final allParts = distinctParts([for (final p in planned) p.utterance]);

  final dir = Directory('content/audio')..createSync(recursive: true);
  final indexFile = File('${dir.path}/index.json');
  var clips = <String, String>{};
  if (indexFile.existsSync()) {
    final index =
        jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
    if (indexIsStale(index)) {
      stdout.writeln(
        'Index tạo bằng giọng/cấu hình khác (hoặc clip theo câu): coi mọi clip cũ là hết hạn (dùng --prune để xóa file cũ).',
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

  File mp3Of(UtterancePart p) => _partFile(
    partCacheKey(p.lang, p.text, voiceFor(p.lang), voiceSpeed),
  );

  final todo = [
    for (final e in allParts.entries)
      if ((only == null || e.key.contains(only)) &&
          !(clips.containsKey(e.key) &&
              File('${dir.path}/${clips[e.key]}').existsSync()))
        e.value,
  ];
  final uncached = todo.where((p) => !mp3Of(p).existsSync()).toList();
  final plannedUtterances = planned.length;
  stdout.writeln(
    '$plannedUtterances utterances, ${allParts.length} distinct parts, '
    '${todo.length} to encode (${uncached.length} not in the MP3 cache).',
  );
  if (dryRun) {
    final byKind = <UtteranceKind, int>{};
    for (final p in planned) {
      byKind[p.kind] = (byKind[p.kind] ?? 0) + 1;
    }
    stdout.writeln(
      'By kind (all): ${byKind.entries.map((e) => '${e.key.name}=${e.value}').join(', ')}',
    );
    final chars = uncached.fold<int>(0, (n, p) => n + p.text.runes.length);
    stdout.writeln(
      'Not cached: ${uncached.length} parts (~$chars characters to synthesise with --allow-api).',
    );
    for (final p in todo) {
      stdout.writeln('  ${p.key}${mp3Of(p).existsSync() ? '' : '  (no MP3)'}');
    }
    return;
  }

  final queue = (limit == null ? todo : todo.take(limit)).toList();
  final needsApi = allowApi && queue.any((p) => !mp3Of(p).existsSync());
  if (queue.isNotEmpty) await _preflightFfmpeg();
  _Vbee? vbee;
  HttpClient? client;
  final breaker = VoiceCircuitBreaker();
  if (needsApi) {
    final creds = _readCredentials();
    client = HttpClient()..connectionTimeout = _connectTimeout;
    vbee = _Vbee(client, creds.appId, creds.token, breaker);
  }
  final batchStats = _BatchStats();
  if (vbee != null) {
    final uncachedQueue = [for (final p in queue) if (!mp3Of(p).existsSync()) p];
    final plan = planBatches(uncachedQueue, forceAll: opts.batch);
    if (plan.batches.isNotEmpty) {
      stdout.writeln(
        '${plan.batches.length} batch requests for ${plan.batches.fold<int>(0, (n, b) => n + b.length)} parts, '
        '${plan.single.length} single.',
      );
      try {
        await _runBatches(vbee, plan.batches, batchStats);
      } on _StopRun catch (e) {
        _err('⏸ Dừng: ${e.message}');
        client?.close();
        exitCode = 2;
        return;
      }
      stdout.writeln(
        'BATCH requests=${batchStats.requests} clean=${batchStats.clean} '
        'fallback=${batchStats.fallback} cached=${batchStats.cached} parts_cut=${batchStats.partsCut}',
      );
    }
  }
  var next = 0;
  var done = 0;
  var stopped = false;
  String? stopReason;
  final failures = <String>[];
  final missing = <String>[];

  Future<void> worker() async {
    while (!stopped && next < queue.length) {
      final p = queue[next++];
      try {
        final cached = mp3Of(p);
        final File mp3;
        if (cached.existsSync()) {
          mp3 = cached;
        } else if (vbee != null) {
          mp3 = await vbee.part(p);
        } else {
          missing.add(p.key);
          continue;
        }
        final file = partFileName(p.key);
        await _toOgg(mp3, File('${dir.path}/$file'));
        clips[p.key] = file;
        saveIndex();
        done++;
        stdout.writeln('✓ ${queue.length - done} left  ${p.key}');
      } on _StopRun catch (e) {
        stopped = true;
        stopReason ??= e.message;
      } on Object catch (e) {
        failures.add(p.key);
        _err('✗ ${p.key}: $e');
      }
    }
  }

  try {
    await Future.wait([for (var i = 0; i < _concurrency; i++) worker()]);
  } finally {
    client?.close();
    saveIndex();
  }
  final remaining = todo.length - done;
  if (breaker.tally.isNotEmpty) {
    _err(
      'Lỗi theo giọng: ${breaker.tally.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
    );
  }
  if (missing.isNotEmpty) {
    for (final k in missing) {
      _err('Thiếu MP3 trong build/voice-parts/: $k');
    }
    _err(
      '${missing.length} đoạn chưa có trong cache. Chạy lại với --allow-api để tạo bằng Vbee.',
    );
    exitCode = 2;
  }
  if (stopped) {
    _err('⏸ Dừng: $stopReason');
    _err(
      'Đã tạo $done đoạn, còn $remaining đoạn. Khắc phục rồi chạy lại để tiếp tục.',
    );
    exitCode = 2;
  } else if (failures.isNotEmpty) {
    _err('Đã tạo $done đoạn, ${failures.length} đoạn lỗi (chạy lại để thử lại).');
    if (exitCode == 0) exitCode = 1;
  } else if (limit != null) {
    stdout.writeln('Đã tạo $done đoạn, còn $remaining đoạn.');
  }

  if (prune) {
    final keep = allParts.keys.toSet();
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

class _BatchStats {
  int requests = 0;
  int clean = 0;
  int fallback = 0;
  int cached = 0;
  int partsCut = 0;
}

/// Runs the batches [_concurrency] at a time. A batch that cannot be split
/// cleanly leaves its parts uncached, so the normal per-part pass redoes them.
Future<void> _runBatches(_Vbee vbee, List<List<UtterancePart>> batches, _BatchStats stats) async {
  var next = 0;
  Future<void> worker() async {
    while (next < batches.length) {
      final i = next++;
      final b = batches[i];
      final label = 'batch ${i + 1}/${batches.length} (${b.length} × ${b.first.lang})';
      try {
        final r = await vbee.batch(b, stats);
        if (r) {
          stats.clean++;
          stats.partsCut += b.length;
          stdout.writeln('✓ $label split cleanly');
        } else {
          stats.fallback++;
          stdout.writeln('↩ $label: segment count mismatch, falling back to per-part requests');
        }
      } on _StopRun {
        rethrow;
      } on Object catch (e) {
        stats.fallback++;
        _err('↩ $label failed ($e), falling back to per-part requests');
      }
    }
  }

  await Future.wait([for (var i = 0; i < _concurrency; i++) worker()]);
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

  /// Synthesises [parts] (one language) in one request and cuts the MP3 apart on
  /// silence into the per-part cache. True when it split cleanly; false (nothing
  /// written) when the segment count did not match the item count.
  Future<bool> batch(List<UtterancePart> parts, _BatchStats stats) async {
    final lang = parts.first.lang;
    final voice = voiceFor(lang);
    final texts = [for (final p in parts) p.text];
    final whole = _partFile('batch-${batchCacheKey(lang, texts, voice, voiceSpeed)}');
    if (whole.existsSync()) {
      stats.cached++;
    } else {
      // One retry: a dropped download should not cost 50 single requests.
      for (var attempt = 1;; attempt++) {
        stats.requests++;
        try {
          await _synthesise(batchText(parts), voice, whole, extra: {'clientPause': batchPause});
          _breaker.recordSuccess(voice);
          break;
        } on _StopRun {
          rethrow;
        } on Object {
          if (_breaker.recordFailure(voice)) {
            throw _StopRun('giọng $voice bị Vbee từ chối liên tục khi tạo theo lô');
          }
          if (attempt >= 2) rethrow;
        }
      }
    }
    return _splitBatch(whole, parts, voice);
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

  Future<File> _synthesise(String text, String voice, File out, {Map<String, Object>? extra}) async {
    final created = await _request('POST', Uri.parse(_api), {
      'text': text,
      'voiceCode': voice,
      'mode': 'async',
      'outputFormat': 'mp3',
      'bitrate': 128,
      'speed': voiceSpeed,
      'webhookUrl': _webhook,
      ...?extra,
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

/// Encodes one part MP3 to Opus mono 32 kbps at `<name>.ogg.part` (forced
/// `-f ogg`), then renames, so a crash never leaves a half-written `.ogg` that
/// could get bundled. The part MP3 stays cached in build/voice-parts/, so an
/// ffmpeg failure never wastes credits.
Future<void> _toOgg(File mp3, File out) async {
  final tmpOgg = File('${out.path}.part');
  try {
    final r = await Process.run('ffmpeg', [
      '-y',
      '-loglevel',
      'error',
      '-i',
      mp3.path,
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

/// Cuts [whole] into one MP3 per part (cache key of each part). Returns false,
/// writing nothing, unless the speech segments match the parts one to one.
Future<bool> _splitBatch(File whole, List<UtterancePart> parts, String voice) async {
  final r = await Process.run('ffmpeg', [
    '-hide_banner',
    '-nostats',
    '-i',
    whole.path,
    '-af',
    'silencedetect=noise=$silenceNoise:d=$silenceMinDuration',
    '-f',
    'null',
    '-',
  ]);
  final log = '${r.stderr}';
  if (r.exitCode != 0) throw ProcessException('ffmpeg', [], log, r.exitCode);
  final total = parseDuration(log);
  if (total == null) throw StateError('ffmpeg: no Duration in batch audio');
  final segments = speechSegments(parseSilences(log), total);
  if (!canSplit(parts.length, segments)) {
    stdout.writeln('  expected ${parts.length} segments, found ${segments.length}');
    return false;
  }
  final written = <File>[];
  try {
    for (var i = 0; i < parts.length; i++) {
      final w = cutWindow(segments[i], total);
      final out = _partFile(partCacheKey(parts[i].lang, parts[i].text, voice, voiceSpeed));
      final tmp = File('${out.path}.tmp');
      final c = await Process.run('ffmpeg', [
        '-y',
        '-loglevel',
        'error',
        '-ss',
        w.start.toStringAsFixed(3),
        '-to',
        w.end.toStringAsFixed(3),
        '-i',
        whole.path,
        '-ac',
        '1',
        '-c:a',
        'libmp3lame',
        '-b:a',
        '128k',
        '-f',
        'mp3',
        tmp.path,
      ]);
      if (c.exitCode != 0) throw ProcessException('ffmpeg', [], '${c.stderr}', c.exitCode);
      written.add(tmp);
    }
  } on Object {
    for (final t in written) {
      if (t.existsSync()) t.deleteSync();
    }
    rethrow;
  }
  // Publish only once every cut succeeded.
  for (var i = 0; i < parts.length; i++) {
    written[i].renameSync(_partFile(partCacheKey(parts[i].lang, parts[i].text, voice, voiceSpeed)).path);
  }
  return true;
}
