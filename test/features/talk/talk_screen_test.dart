import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/profile/names.dart';
import 'package:xoai_castle/core/voice/utterances.dart';
import 'package:xoai_castle/features/games/talk/mic_button.dart';
import 'package:xoai_castle/features/games/talk/talk_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

const _names = Names(en: 'An', vi: 'Xoài');
const _again = 'Hmm, can you say it again?';
const _hint = 'Bấm giữ nút micro rồi nói nha!';
const _sayAfterVi = 'Con nói theo Elsa nhé:';
const _praise = ['Great job!', 'Wonderful, An!', 'You did it!', 'Giỏi quá Xoài ơi!', 'Xoài làm đúng rồi!'];
final _mic = find.byKey(const Key('mic-button'));
final _confirm = find.byKey(const Key('confirm-button'));

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await ContentRepository(FileContentSource('content')).load();
  });

  String question(ConversationItem i) => talkQuestionVars(i, _names)['question']!;
  String model(ConversationItem i) => talkModelVars(i, _names)['model']!;

  /// The conversation item Elsa asked last.
  ConversationItem current(FakeTts tts) {
    for (final t in tts.texts.reversed) {
      for (final i in content.conversation) {
        if (question(i) == t) return i;
      }
    }
    throw StateError('Elsa has not asked anything: ${tts.texts}');
  }

  int count(FakeTts tts, String text) => tts.texts.where((t) => t == text).length;
  int praises(FakeTts tts) => tts.texts.where(_praise.contains).length;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Holds the mic, "says" [heard] and lets go.
  Future<void> speak(WidgetTester tester, FakeSpeechRecognizer speech, List<String> heard) async {
    final g = await tester.startGesture(tester.getCenter(_mic));
    await tester.pump(const Duration(milliseconds: 100));
    speech.scripts.add(heard);
    await g.up();
    await tester.pump();
    await settle(tester);
  }

  Future<void> answerRight(WidgetTester tester, FakeTts tts, FakeSpeechRecognizer speech) =>
      speak(tester, speech, [model(current(tts))]);

  Future<(FakeTts, FakeSpeechRecognizer, MemorySessionStore, MemoryRewardStore, MemoryItemStatsStore)> pumpTalk(
    WidgetTester tester, {
    FakeSpeechRecognizer? speech,
    FakeTts? tts,
  }) async {
    final t = tts ?? FakeTts();
    final s = speech ?? FakeSpeechRecognizer();
    final sessions = MemorySessionStore();
    final rewards = MemoryRewardStore();
    final stats = MemoryItemStatsStore();
    await tester.pumpWidget(testApp(
      content: content,
      tts: t,
      home: const TalkScreen(),
      speech: s,
      sessions: sessions,
      rewards: rewards,
      itemStats: stats,
    ));
    await tester.pump();
    await settle(tester);
    return (t, s, sessions, rewards, stats);
  }

  testWidgets('entering asks for the mic once, asks a question and says the hold hint once', (tester) async {
    final (tts, speech, _, _, _) = await pumpTalk(tester);
    expect(speech.inits, 1);
    expect(tts.texts.where((t) => content.conversation.any((i) => question(i) == t)), hasLength(1));
    expect(count(tts, _hint), 1);
    expect(_mic, findsOneWidget);
    expect(_confirm, findsNothing);
    expect(tester.getSize(_mic).shortestSide, greaterThanOrEqualTo(120));
    expect(tester.widget<MicButton>(_mic).enabled, isTrue);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('a right answer is praised with +1 and moves on; five right ones reach the reward screen', (tester) async {
    final (tts, speech, sessions, rewards, stats) = await pumpTalk(tester);
    final seen = <String>{};
    for (var i = 0; i < 5; i++) {
      final item = current(tts);
      expect(seen.add(item.id), isTrue, reason: 'question ${i + 1} repeats');
      expect(find.text('${i + 1}/5'), findsOneWidget);
      await answerRight(tester, tts, speech);
      expect(praises(tts), i + 1);
      if (i < 4) expect(current(tts).id, isNot(item.id));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+10 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'talk');
    expect(sessions.records.single.correct, 5);
    expect(sessions.records.single.total, 5);
    expect(stats.stats.keys.every((k) => k.startsWith('conv:')), isTrue);
    expect(stats.stats.values.every((s) => s.mastery == 1), isTrue);
    expect(rewards.state.snowflakesTotal, 10);
  });

  testWidgets('a wrong answer gets "say it again" and the same question stays', (tester) async {
    final (tts, speech, _, _, _) = await pumpTalk(tester);
    final item = current(tts);
    await speak(tester, speech, ['banana']);
    expect(count(tts, _again), 1);
    expect(praises(tts), 0);
    expect(find.text('1/5'), findsOneWidget);
    expect(current(tts).id, item.id);
    expect(speech.starts, 1);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a second miss says the model answer; a third attempt always passes (hinted)', (tester) async {
    final (tts, speech, _, _, stats) = await pumpTalk(tester);
    final item = current(tts);
    await speak(tester, speech, ['banana']);
    await speak(tester, speech, ['banana']);
    expect(count(tts, _again), 1);
    expect(tts.spoken, contains((text: _sayAfterVi, lang: 'vi')));
    expect(tts.spoken, contains((text: model(item), lang: 'en')));
    expect(find.text('1/5'), findsOneWidget);
    await speak(tester, speech, ['banana']);
    expect(praises(tts), 1);
    expect(find.text('2/5'), findsOneWidget);
    expect(stats.stats['conv:${item.id}']!.mastery, 0);
    expect(stats.stats['conv:${item.id}']!.wrong, 1);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a retry earns no snowflake: 4 first tries + 1 retry = +9', (tester) async {
    final (tts, speech, _, rewards, stats) = await pumpTalk(tester);
    final firstId = current(tts).id;
    await speak(tester, speech, ['banana']);
    await answerRight(tester, tts, speech);
    for (var i = 0; i < 4; i++) {
      await answerRight(tester, tts, speech);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('+9 ❄️'), findsOneWidget);
    expect(rewards.state.snowflakesTotal, 9);
    expect(stats.stats['conv:$firstId']!.mastery, 0);
  });

  testWidgets('a silent release is not an attempt', (tester) async {
    final (tts, speech, _, _, _) = await pumpTalk(tester);
    await speak(tester, speech, const []);
    await speak(tester, speech, ['  ', '']);
    expect(count(tts, _hint), 3);
    expect(count(tts, _again), 0);
    expect(tts.spoken.where((s) => s.text == _sayAfterVi), isEmpty);
    // The first real miss is still the first attempt: "again", not the model answer.
    await speak(tester, speech, ['banana']);
    expect(count(tts, _again), 1);
    expect(tts.spoken.where((s) => s.text == _sayAfterVi), isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tapping Elsa asks the question again', (tester) async {
    final (tts, _, _, _, _) = await pumpTalk(tester);
    final item = current(tts);
    final before = count(tts, question(item));
    await tester.tap(find.byKey(const Key('elsa')));
    await settle(tester);
    expect(count(tts, question(item)), before + 1);
  });

  testWidgets('speech not available: a big check button and the follow-along flow, +1 per question', (tester) async {
    final (tts, speech, sessions, rewards, stats) = await pumpTalk(tester, speech: FakeSpeechRecognizer(initResult: false));
    expect(_mic, findsNothing);
    expect(_confirm, findsOneWidget);
    expect(find.text('✅'), findsOneWidget);
    expect(count(tts, _hint), 0);
    for (var i = 0; i < 5; i++) {
      final item = current(tts);
      expect(tts.spoken, contains((text: model(item), lang: 'en')));
      expect(tts.texts.where((t) => t == _sayAfterVi).length, i + 1);
      await tester.tap(_confirm);
      await tester.pump();
      await settle(tester);
      expect(praises(tts), i + 1);
      if (i == 3) {
        // Four confirmed so far.
        expect(find.text('5/5'), findsOneWidget);
      }
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+10 ❄️'), findsOneWidget);
    expect(rewards.state.snowflakesTotal, 10);
    expect(sessions.records.single.game, 'talk');
    expect(stats.stats, isEmpty, reason: 'follow-along does not change mastery');
    expect(speech.starts, 0);
  });

  testWidgets('the mic is locked while Elsa speaks and unlocks when she is done', (tester) async {
    final tts = GatedTts();
    final speech = FakeSpeechRecognizer();
    await pumpTalk(tester, speech: speech, tts: tts);
    expect(tester.widget<MicButton>(_mic).enabled, isFalse);
    final g = await tester.startGesture(tester.getCenter(_mic));
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await tester.pump();
    expect(speech.starts, 0);

    for (var i = 0; i < 4; i++) {
      tts.release();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.widget<MicButton>(_mic).enabled, isTrue);
    final g2 = await tester.startGesture(tester.getCenter(_mic));
    await tester.pump(const Duration(milliseconds: 100));
    expect(speech.starts, 1);
    await g2.up();
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      tts.release();
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('holding longer than 8 s stops by itself', (tester) async {
    final (tts, speech, _, _, _) = await pumpTalk(tester);
    final item = current(tts);
    final g = await tester.startGesture(tester.getCenter(_mic));
    await tester.pump(const Duration(seconds: 7));
    expect(speech.stops, 0);
    speech.scripts.add([model(item)]);
    await tester.pump(const Duration(seconds: 2));
    expect(speech.stops, 1);
    await settle(tester);
    expect(praises(tts), 1);
    await g.up();
    await tester.pump();
    expect(speech.stops, 1);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('fits a 360x640 phone in both modes', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTalk(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(_mic).dy, lessThanOrEqualTo(640));
    await tester.pumpWidget(const SizedBox());
    await pumpTalk(tester, speech: FakeSpeechRecognizer(initResult: false));
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(_confirm).dy, lessThanOrEqualTo(640));
  });

  testWidgets('the home button says go_home and leaves', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TalkScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await settle(tester);
    expect(find.byType(TalkScreen), findsOneWidget);
    await tester.tap(find.text('🏠'));
    await tester.pump();
    await settle(tester);
    expect(tts.texts, contains('Về lâu đài nào!'));
    expect(find.byType(TalkScreen), findsNothing);
  });

  testWidgets('the system back gesture says go_home too', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(
      content: content,
      tts: tts,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TalkScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await settle(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await settle(tester);
    expect(tts.texts, contains('Về lâu đài nào!'));
    expect(find.byType(TalkScreen), findsNothing);
  });
}
