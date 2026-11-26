import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xoai_castle/core/voice/utterance.dart';

import '../../tool/src/local_tts.dart';
import '../../tool/src/local_voice.dart';
import '../../tool/src/voice_gen.dart';

void main() {
  UtterancePart vi(String t) => UtterancePart('vi', t);
  UtterancePart en(String t) => UtterancePart('en', t);

  group('local voices', () {
    test('Vietnamese is VieNeu "Trúc Ly", English is Kokoro af_heart at 0.8 (slow, for a 5-year-old)', () {
      expect(defaultEnSpeed, 0.8);
      expect(localVoiceFor('vi').id, 'vieneu:Trúc Ly');
      expect(localVoiceFor('vi').settings, {'temperature': 0.7});
      expect(localVoiceFor('en').id, 'kokoro:af_heart');
      expect(localVoiceFor('en').settings, {'speed': 0.8});
      expect(() => localVoiceFor('fr'), throwsArgumentError);
    });

    test('the English speed can be overridden; Vietnamese ignores it', () {
      expect(localVoiceFor('en', enSpeed: 0.9).settings, {'speed': 0.9});
      expect(localVoiceFor('vi', enSpeed: 0.9).settings, {'temperature': 0.7});
    });

    test('closeSentence adds a full stop unless the line already ends one', () {
      expect(closeSentence('Con mèo'), 'Con mèo.');
      expect(closeSentence('Lion'), 'Lion.');
      expect(closeSentence('Lion '), 'Lion.');
      expect(closeSentence('Giỏi quá!'), 'Giỏi quá!');
      expect(closeSentence('Bé tên gì?'), 'Bé tên gì?');
      expect(closeSentence('Xong.'), 'Xong.');
      expect(closeSentence('Ừm…'), 'Ừm…');
      expect(closeSentence('một, hai'), 'một, hai.');
    });

    test('env overrides for the server URL and the Kokoro python', () {
      expect(vieneuUrl({}), 'http://127.0.0.1:7860');
      expect(vieneuUrl({'VIENEU_URL': ' http://box:9000 '}), 'http://box:9000');
      expect(vieneuUrl({'VIENEU_URL': ''}), 'http://127.0.0.1:7860');
      expect(kokoroPython({}), endsWith('.venv-kokoro/bin/python'));
      expect(kokoroPython({'KOKORO_PYTHON': '/x/python'}), '/x/python');
    });
  });

  group('part cache keys', () {
    test('local key is stable, 40 hex, and depends on lang and text', () {
      final k = localPartCacheKey('vi', 'Con mèo');
      expect(k, localPartCacheKey('vi', 'Con mèo'));
      expect(k, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(localPartCacheKey('vi', 'Con chó'), isNot(k));
      expect(localPartCacheKey('en', 'Con mèo', voice: localVoiceFor('vi')), isNot(k));
    });

    test('the English speed is part of the English key only (old 0.9 WAVs are not reused)', () {
      expect(localPartCacheKey('en', 'Cat', enSpeed: 0.9), isNot(localPartCacheKey('en', 'Cat')));
      expect(localPartCacheKey('en', 'Cat', enSpeed: 0.8), localPartCacheKey('en', 'Cat'));
      expect(localPartCacheKey('vi', 'Mèo', enSpeed: 0.9), localPartCacheKey('vi', 'Mèo'));
      final p = en('Cat');
      expect(partCachePath(VoiceProvider.local, p, enSpeed: 0.9), isNot(partCachePath(VoiceProvider.local, p)));
      expect(partCachePath(VoiceProvider.vbee, p, enSpeed: 0.7), partCachePath(VoiceProvider.vbee, p), reason: 'Vbee keeps its own speed');
    });

    test('local key changes with the voice name, engine or settings', () {
      const base = LocalVoice('vieneu', 'Trúc Ly', {'temperature': 0.7});
      final k = localPartCacheKey('vi', 'a', voice: base);
      expect(k, localPartCacheKey('vi', 'a'));
      expect(localPartCacheKey('vi', 'a', voice: const LocalVoice('vieneu', 'Khác', {'temperature': 0.7})), isNot(k));
      expect(localPartCacheKey('vi', 'a', voice: const LocalVoice('other', 'Trúc Ly', {'temperature': 0.7})), isNot(k));
      expect(localPartCacheKey('vi', 'a', voice: const LocalVoice('vieneu', 'Trúc Ly', {'temperature': 0.8})), isNot(k));
    });

    test('provider picks the key and the cache file; Vbee keys stay as before', () {
      final p = en('Lion!');
      expect(partCacheKeyFor(VoiceProvider.vbee, p), partCacheKey('en', 'Lion!', voiceFor('en'), voiceSpeed));
      expect(partCacheKeyFor(VoiceProvider.local, p), localPartCacheKey('en', 'Lion!'));
      expect(partCacheKeyFor(VoiceProvider.local, p), isNot(partCacheKeyFor(VoiceProvider.vbee, p)));
      expect(partCachePath(VoiceProvider.vbee, p), 'build/voice-parts/${partCacheKeyFor(VoiceProvider.vbee, p)}.mp3');
      expect(partCachePath(VoiceProvider.local, p), 'build/voice-parts/${partCacheKeyFor(VoiceProvider.local, p)}.wav');
    });
  });

  group('job planning', () {
    test('Vietnamese goes to VieNeu, English to Kokoro, in order, closed, one WAV per part', () {
      final plan = planLocalJobs([vi('Con mèo'), en('Lion'), vi('Giỏi quá!'), en('Cat!')], 'cache');
      expect(plan.jobs.keys, unorderedEquals([vieneuEngine, kokoroEngine]));
      expect(plan.jobs[vieneuEngine]!.map((i) => i.text), ['Con mèo.', 'Giỏi quá!']);
      expect(plan.jobs[vieneuEngine]!.map((i) => i.key), ['vi|Con mèo', 'vi|Giỏi quá!']);
      expect(plan.jobs[kokoroEngine]!.map((i) => i.text), ['Lion.', 'Cat!']);
      expect(plan.jobs[vieneuEngine]!.first.out, 'cache/${localPartCacheKey('vi', 'Con mèo')}.wav');
      expect(plan.unsupported, isEmpty);
    });

    test('planning with another English speed writes to that speed\'s cache file', () {
      final plan = planLocalJobs([en('Lion'), vi('Mèo')], 'cache', enSpeed: 0.7);
      expect(plan.jobs[kokoroEngine]!.single.out, 'cache/${localPartCacheKey('en', 'Lion', enSpeed: 0.7)}.wav');
      expect(plan.jobs[vieneuEngine]!.single.out, 'cache/${localPartCacheKey('vi', 'Mèo')}.wav');
    });

    test('a language without a local voice is reported, not sent', () {
      final plan = planLocalJobs([UtterancePart('fr', 'Chat'), en('Cat')], 'c');
      expect(plan.unsupported, ['fr|Chat']);
      expect(plan.jobs.keys, [kokoroEngine]);
    });

    test('job JSON carries the voice settings and the server URL', () {
      final items = [const LocalJobItem('vi|a', 'a.', 'o.wav')];
      expect(jobJson(vieneuEngine, items, {'VIENEU_URL': 'http://h:1'}), {
        'url': 'http://h:1',
        'voice': 'Trúc Ly',
        'temperature': 0.7,
        'workers': 4,
        'items': [
          {'text': 'a.', 'out': 'o.wav'},
        ],
      });
      expect(jobJson(kokoroEngine, items, {}, enSpeed: 0.7)['speed'], 0.7);
      expect(jobJson(kokoroEngine, items, {}), {
        'voice': 'af_heart',
        'speed': 0.8,
        'items': [
          {'text': 'a.', 'out': 'o.wav'},
        ],
      });
    });

    test('helper commands: VieNeu through uv + gradio_client, Kokoro through its python, offline', () {
      final v = helperCommand(vieneuEngine, 'job.json', {});
      expect(v.executable, 'uv');
      expect(v.arguments, ['run', '--quiet', '--with', 'gradio_client', 'python', '-I', 'tool/tts/vieneu_batch.py', 'job.json']);
      final k = helperCommand(kokoroEngine, 'job.json', {'KOKORO_PYTHON': '/k/python'});
      expect(k.executable, '/k/python');
      expect(k.arguments, ['-I', 'tool/tts/kokoro_batch.py', 'job.json']);
      expect(k.environment, {'HF_HUB_OFFLINE': '1'});
      expect(helperCommand(kokoroEngine, 'j', {'HF_HUB_OFFLINE': '0'}).environment, isEmpty);
    });

    test('helper stderr: FAIL lines by index, last line for messages', () {
      const err = 'W1126 torch warning\nFAIL 2 boom bang\nnoise\nFAIL 0 \n';
      expect(parseHelperFailures(err), {2: 'boom bang', 0: ''});
      expect(lastLine('a\nb\n\n'), 'b');
      expect(lastLine(''), '');
    });

    test('the helper scripts exist where the commands point', () {
      expect(File('tool/tts/vieneu_batch.py').existsSync(), isTrue);
      expect(File('tool/tts/kokoro_batch.py').existsSync(), isTrue);
    });
  });

  group('post-processing', () {
    test('volumedetect output is parsed; silence gives null', () {
      const log = '[Parsed_volumedetect_0 @ 0x1] mean_volume: -24.3 dB\n[Parsed_volumedetect_0 @ 0x1] max_volume: -6.1 dB\n';
      final s = parseVolumeDetect(log)!;
      expect(s.meanDb, -24.3);
      expect(s.maxDb, -6.1);
      expect(parseVolumeDetect('mean_volume: -inf dB\nmax_volume: -inf dB'), isNull);
      expect(parseVolumeDetect('nothing'), isNull);
    });

    test('gain brings the mean to -19 dB but keeps peaks under -1 dB', () {
      expect(levelGainDb(const VolumeStats(-25, -10)), closeTo(6, 1e-9));
      expect(levelGainDb(const VolumeStats(-25, -3)), closeTo(2, 1e-9), reason: 'peak-limited');
      expect(levelGainDb(const VolumeStats(-12, -0.5)), closeTo(-7, 1e-9));
      expect(levelGainDb(const VolumeStats(-70, -60)), 24, reason: 'never more than +24 dB');
    });

    test('encode chain trims both ends, levels, pads 0.15 s and writes Opus 32k mono', () {
      final a = localEncodeArgs('in.wav', 'out.ogg.part', 3.456);
      final af = a[a.indexOf('-af') + 1];
      expect(RegExp('silenceremove').allMatches(af), hasLength(2));
      expect(RegExp('areverse').allMatches(af), hasLength(2));
      expect(af, contains('volume=3.46dB'));
      expect(af, contains('adelay=150:all=1'));
      expect(af, contains('apad=pad_dur=0.15'));
      expect(af.indexOf('silenceremove'), lessThan(af.indexOf('volume=')));
      expect(af.indexOf('volume='), lessThan(af.indexOf('adelay')));
      for (final pair in [
        ['-c:a', 'libopus'],
        ['-b:a', '32k'],
        ['-ac', '1'],
        ['-f', 'ogg'],
      ]) {
        expect(a[a.indexOf(pair[0]) + 1], pair[1]);
      }
      expect(a.last, 'out.ogg.part');
      final probe = volumeProbeArgs('in.wav');
      expect(probe[probe.indexOf('-af') + 1], '$trimFilter,volumedetect');
    });
  });

  group('LocalSynthesizer', () {
    late Directory tmp;
    late List<HelperCommand> calls;
    late List<Uri> probed;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('local_tts_test');
      calls = [];
      probed = [];
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    /// A fake helper: reads the job, writes every `out` except [skip] texts,
    /// prints `OK i`, and reports [stderr]/[exitCode].
    HelperRunner fakeRunner({Set<String> skip = const {}, int exitCode = 0, String stderr = '', bool throwNotFound = false}) =>
        (cmd, onLine) async {
          calls.add(cmd);
          if (throwNotFound) throw ProcessException(cmd.executable, cmd.arguments, 'No such file', 2);
          final job = jsonDecode(File(cmd.arguments.last).readAsStringSync()) as Map<String, dynamic>;
          final items = (job['items'] as List).cast<Map<String, dynamic>>();
          for (var i = 0; i < items.length; i++) {
            if (skip.contains(items[i]['text'])) continue;
            File(items[i]['out'] as String)
              ..createSync(recursive: true)
              ..writeAsStringSync('RIFF');
            onLine('OK $i');
          }
          return HelperRun(exitCode, stderr);
        };

    LocalSynthesizer synth(HelperRunner runner, {bool up = true, Map<String, String> env = const {}, bool pythonExists = true}) =>
        LocalSynthesizer(
          runner: runner,
          probe: (u) async {
            probed.add(u);
            return up;
          },
          cacheDir: '${tmp.path}/cache',
          workDir: '${tmp.path}/work',
          environment: {'KOKORO_PYTHON': '${tmp.path}/python', ...env},
          fileExists: (p) => p == '${tmp.path}/python' ? pythonExists : File(p).existsSync(),
        );

    test('runs one job per engine and writes every part into the cache', () async {
      final log = <String>[];
      final failures = await synth(fakeRunner()).synthesize([vi('Con mèo'), en('Lion'), vi('Bông tuyết')], log: log.add);
      expect(failures, isEmpty);
      expect(calls.map((c) => c.executable), unorderedEquals(['uv', '${tmp.path}/python']));
      for (final p in [vi('Con mèo'), en('Lion'), vi('Bông tuyết')]) {
        expect(File('${tmp.path}/cache/${localPartCacheKey(p.lang, p.text)}.wav').existsSync(), isTrue, reason: p.key);
      }
      expect(log.where((l) => l.contains('vieneu')), hasLength(2));
      expect(log.last, contains('/'));
      expect(probed.single.toString(), 'http://127.0.0.1:7860');
      expect(Directory('${tmp.path}/work').listSync(), isEmpty, reason: 'job files are deleted');
    });

    test('the English speed reaches the Kokoro job and the cache key', () async {
      calls.clear();
      final s = LocalSynthesizer(
        runner: (cmd, onLine) async {
          final job = jsonDecode(File(cmd.arguments.last).readAsStringSync()) as Map<String, dynamic>;
          expect(job['speed'], 0.7);
          return fakeRunner()(cmd, onLine);
        },
        probe: (_) async => true,
        cacheDir: '${tmp.path}/cache',
        workDir: '${tmp.path}/work',
        environment: {'KOKORO_PYTHON': '${tmp.path}/python'},
        fileExists: (p) => p == '${tmp.path}/python' || File(p).existsSync(),
        enSpeed: 0.7,
      );
      expect(await s.synthesize([en('Lion')]), isEmpty);
      expect(File('${tmp.path}/cache/${localPartCacheKey('en', 'Lion', enSpeed: 0.7)}.wav').existsSync(), isTrue);
    });

    test('only the engines that are needed are checked and run', () async {
      await synth(fakeRunner(), up: false).synthesize([en('Lion')]);
      expect(probed, isEmpty, reason: 'no Vietnamese part: the server is not needed');
      expect(calls.single.arguments, contains('tool/tts/kokoro_batch.py'));
      calls.clear();
      await synth(fakeRunner(), pythonExists: false).synthesize([vi('Mèo')]);
      expect(calls.single.executable, 'uv');
      calls.clear();
      expect(await synth(fakeRunner()).synthesize([]), isEmpty);
      expect(calls, isEmpty);
    });

    test('server down: clear Vietnamese error, nothing runs', () async {
      final f = synth(fakeRunner(), up: false, env: {'VIENEU_URL': 'http://127.0.0.1:9'}).synthesize([vi('Mèo'), en('Cat')]);
      await expectLater(
        f,
        throwsA(isA<LocalTtsUnavailable>().having((e) => e.message, 'message', allOf(contains('VieNeu'), contains('http://127.0.0.1:9')))),
      );
      expect(calls, isEmpty);
    });

    test('Kokoro python missing: error names KOKORO_PYTHON, nothing runs', () async {
      await expectLater(
        synth(fakeRunner(), pythonExists: false).synthesize([vi('Mèo'), en('Cat')]),
        throwsA(isA<LocalTtsUnavailable>().having((e) => e.message, 'message', contains('KOKORO_PYTHON'))),
      );
      expect(calls, isEmpty);
    });

    test('uv not installed: unavailable', () async {
      await expectLater(
        synth(fakeRunner(throwNotFound: true)).synthesize([vi('Mèo')]),
        throwsA(isA<LocalTtsUnavailable>().having((e) => e.message, 'message', contains('uv'))),
      );
    });

    test('helper exit 3 (engine unavailable) becomes LocalTtsUnavailable with its reason', () async {
      await expectLater(
        synth(fakeRunner(skip: {'Cat.'}, exitCode: 3, stderr: 'warning\nKhông nạp được Kokoro: No module named kokoro\n')).synthesize([en('Cat')]),
        throwsA(isA<LocalTtsUnavailable>().having((e) => e.message, 'message', contains('No module named kokoro'))),
      );
    });

    test('items the helper failed are reported per part; the others are kept', () async {
      final failures = await synth(
        fakeRunner(skip: {'Hai.'}, exitCode: 1, stderr: 'FAIL 1 server error 500\n'),
      ).synthesize([vi('Một'), vi('Hai'), vi('Ba')]);
      expect(failures, {'vi|Hai': 'server error 500'});
      expect(File('${tmp.path}/cache/${localPartCacheKey('vi', 'Một')}.wav').existsSync(), isTrue);
    });

    test('a missing WAV is a failure even when the helper says it succeeded', () async {
      final failures = await synth(fakeRunner(skip: {'Cat.'})).synthesize([en('Cat'), en('Dog')]);
      expect(failures.keys, ['en|Cat']);
      expect(failures['en|Cat'], contains('không tạo ra file'));
    });

    test('a helper crash fails every part it did not write', () async {
      final failures = await synth(fakeRunner(skip: {'Cat.', 'Dog.'}, exitCode: 139, stderr: 'Segmentation fault\n')).synthesize([en('Cat'), en('Dog')]);
      expect(failures.keys, ['en|Cat', 'en|Dog']);
      expect(failures['en|Dog'], contains('139'));
    });

    test('a part in a language without a local voice fails without stopping the rest', () async {
      final failures = await synth(fakeRunner()).synthesize([UtterancePart('fr', 'Chat'), en('Cat')]);
      expect(failures.keys, ['fr|Chat']);
      expect(calls, hasLength(1));
    });
  });
}
