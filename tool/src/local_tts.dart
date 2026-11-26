import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xoai_castle/core/voice/utterance.dart';

import 'local_voice.dart';

/// Runs the local TTS helpers (tool/tts/*_batch.py) for many parts at once.
/// Process launching, the server probe and file checks are injected, so the
/// orchestration is tested without Python, a server or the network.

class HelperRun {
  const HelperRun(this.exitCode, this.stderr, {this.timedOut = false});
  final int exitCode;
  final String stderr;

  /// The helper made no progress for [helperIdleTimeout] and was killed.
  final bool timedOut;
}

/// How long a helper may go without printing anything before it is taken as hung
/// (e.g. a Gradio `predict` that never answers) and killed. Measured from its last
/// output line, not from its start: one run makes every part of a language, which
/// can take much longer than this while it is busy.
const helperIdleTimeout = Duration(minutes: 20);

/// Runs [cmd], passing each stdout line to [onStdoutLine] as it arrives.
typedef HelperRunner = Future<HelperRun> Function(HelperCommand cmd, void Function(String line) onStdoutLine);

/// True when [url] answers at all (the VieNeu Gradio server is up).
typedef UrlProbe = Future<bool> Function(Uri url);

/// A local engine cannot be used at all (server down, Python or uv missing).
/// The message is Vietnamese and says what to fix; gen_voice exits with code 2.
class LocalTtsUnavailable implements Exception {
  LocalTtsUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocalSynthesizer {
  LocalSynthesizer({
    required this.runner,
    required this.probe,
    required this.cacheDir,
    required this.workDir,
    this.environment = const {},
    this.enSpeed = defaultEnSpeed,
    bool Function(String path)? fileExists,
  }) : _exists = fileExists ?? ((p) => File(p).existsSync());

  final HelperRunner runner;
  final UrlProbe probe;

  /// Where each part's WAV is written (`<cacheDir>/<localPartCacheKey>.wav`).
  final String cacheDir;

  /// Where job files are written (and deleted afterwards).
  final String workDir;
  final Map<String, String> environment;

  /// Kokoro reading speed (also part of each English cache key).
  final double enSpeed;
  final bool Function(String path) _exists;

  /// Synthesises [parts] into [cacheDir]. Returns the parts that failed
  /// (part key → message); throws [LocalTtsUnavailable] when an engine that is
  /// needed cannot be used, before any helper runs.
  Future<Map<String, String>> synthesize(List<UtterancePart> parts, {void Function(String line)? log}) async {
    final plan = planLocalJobs(parts, cacheDir, enSpeed: enSpeed);
    final failures = {for (final k in plan.unsupported) k: 'không có giọng local cho ngôn ngữ này'};
    if (plan.jobs.isEmpty) return failures;
    await _preflight(plan.jobs.keys.toSet());
    final results = await Future.wait([
      for (final e in plan.jobs.entries) _runJob(e.key, e.value, log),
    ]);
    for (final r in results) {
      failures.addAll(r);
    }
    return failures;
  }

  Future<void> _preflight(Set<String> engines) async {
    if (engines.contains(vieneuEngine)) {
      final url = vieneuUrl(environment);
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !await probe(uri)) {
        throw LocalTtsUnavailable(
          'Không kết nối được VieNeu-TTS tại $url. Hãy mở server VieNeu (Gradio) rồi chạy lại, '
          'hoặc đặt VIENEU_URL đúng địa chỉ.',
        );
      }
    }
    if (engines.contains(kokoroEngine)) {
      final python = kokoroPython(environment);
      if (!_exists(python)) {
        throw LocalTtsUnavailable(
          'Không tìm thấy Python cho Kokoro tại $python. Đặt KOKORO_PYTHON trỏ tới python của venv có gói kokoro.',
        );
      }
    }
  }

  Future<Map<String, String>> _runJob(String engine, List<LocalJobItem> items, void Function(String)? log) async {
    Directory(workDir).createSync(recursive: true);
    final jobFile = File('$workDir/$engine-job-${DateTime.now().microsecondsSinceEpoch}.json')
      ..writeAsStringSync(jsonEncode(jobJson(engine, items, environment, enSpeed: enSpeed)));
    final cmd = helperCommand(engine, jobFile.path, environment);
    var done = 0;
    final HelperRun run;
    try {
      run = await runner(cmd, (line) {
        final m = RegExp(r'^OK (\d+)$').firstMatch(line.trim());
        if (m == null) return;
        final i = int.parse(m[1]!);
        if (i < items.length) log?.call('🎙 $engine ${++done}/${items.length}  ${items[i].key}');
      });
    } on ProcessException catch (e) {
      throw LocalTtsUnavailable(
        engine == vieneuEngine
            ? 'Không chạy được uv (${e.message}). Cài uv (brew install uv) để gọi VieNeu-TTS.'
            : 'Không chạy được Python cho Kokoro ${cmd.executable} (${e.message}). Kiểm tra KOKORO_PYTHON.',
      );
    } finally {
      if (jobFile.existsSync()) jobFile.deleteSync();
    }
    if (run.exitCode == helperUnavailableExit) {
      final why = lastLine(run.stderr);
      throw LocalTtsUnavailable(
        engine == vieneuEngine
            ? 'VieNeu-TTS không dùng được: $why'
            : 'Kokoro không dùng được: $why (kiểm tra KOKORO_PYTHON và mô hình hexgrad/Kokoro-82M trong ~/.cache/huggingface).',
      );
    }
    final failed = parseHelperFailures(run.stderr);
    return {
      for (var i = 0; i < items.length; i++)
        if (!_exists(items[i].out))
          items[i].key:
              failed[i] ??
              (run.timedOut
                  ? 'helper $engine bị treo (không tiến triển ${helperIdleTimeout.inMinutes} phút), đã dừng'
                  : run.exitCode == 0
                  ? 'helper $engine không tạo ra file'
                  : 'helper $engine thoát mã ${run.exitCode}: ${lastLine(run.stderr)}'),
    };
  }
}

/// Starts [cmd] for real, streaming stdout lines and collecting stderr.
///
/// A helper that prints nothing for [idleTimeout] is hung: it gets SIGTERM (uv passes
/// it on to Python), then SIGKILL after [killGrace], and the run comes back with
/// [HelperRun.timedOut]. After the helper exits its pipes are drained for at most a few
/// seconds, so a stray child that keeps them open cannot block the run either.
Future<HelperRun> runHelperProcess(
  HelperCommand cmd,
  void Function(String line) onStdoutLine, {
  Duration idleTimeout = helperIdleTimeout,
  Duration killGrace = const Duration(seconds: 5),
}) async {
  final p = await Process.start(cmd.executable, cmd.arguments, environment: cmd.environment);
  final err = StringBuffer();
  var timedOut = false;
  Timer? idle;
  Timer? hardKill;
  void progress() {
    idle?.cancel();
    idle = Timer(idleTimeout, () {
      timedOut = true;
      p.kill();
      hardKill = Timer(killGrace, () => p.kill(ProcessSignal.sigkill));
    });
  }

  progress();
  final outDone = Completer<void>();
  final errDone = Completer<void>();
  final outSub = p.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
        (line) {
          if (!timedOut) progress();
          onStdoutLine(line);
        },
        onDone: outDone.complete,
        onError: (Object _) {},
      );
  final errSub = p.stderr
      .transform(utf8.decoder)
      .listen(
        (chunk) {
          if (!timedOut) progress();
          err.write(chunk);
        },
        onDone: errDone.complete,
        onError: (Object _) {},
      );
  final code = await p.exitCode;
  idle?.cancel();
  hardKill?.cancel();
  await Future.wait([outDone.future, errDone.future]).timeout(const Duration(seconds: 3), onTimeout: () => const []);
  await Future.wait([outSub.cancel(), errSub.cancel()]);
  if (timedOut) err.writeln('helper bị treo: không có tiến triển sau ${idleTimeout.inSeconds} giây, đã dừng');
  return HelperRun(code, '$err', timedOut: timedOut);
}

/// Any HTTP answer from [url] within a few seconds counts as "up".
Future<bool> probeUrl(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final req = await client.getUrl(url).timeout(const Duration(seconds: 5));
    final res = await req.close().timeout(const Duration(seconds: 5));
    await res.drain<void>();
    return true;
  } on Object {
    return false;
  } finally {
    client.close(force: true);
  }
}
