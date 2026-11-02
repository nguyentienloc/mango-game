import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/rewards/reward_rules.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/time.dart';

const levels = [
  CastleLevel(level: 1, snowflakes: 0),
  CastleLevel(level: 2, snowflakes: 20, friend: 'olaf'),
  CastleLevel(level: 3, snowflakes: 50),
  CastleLevel(level: 4, snowflakes: 100, friend: 'anna'),
  CastleLevel(level: 5, snowflakes: 170),
  CastleLevel(level: 6, snowflakes: 260, friend: 'sven'),
  CastleLevel(level: 7, snowflakes: 380),
  CastleLevel(level: 8, snowflakes: 530, friend: 'kristoff'),
];

void main() {
  test('dayKey formats local dates', () {
    expect(dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('castleLevelFor picks the highest reached level', () {
    expect(castleLevelFor(0, levels), 1);
    expect(castleLevelFor(19, levels), 1);
    expect(castleLevelFor(20, levels), 2);
    expect(castleLevelFor(529, levels), 7);
    expect(castleLevelFor(99999, levels), 8);
  });

  test('a round earns one per first-try answer plus the round bonus', () {
    final o = applyRound(const RewardState(), firstTryCorrect: 6, today: '2026-11-02', levels: levels);
    expect(o.earned, 11);
    expect(o.questCompleted, isFalse);
    expect(o.state.snowflakesTotal, 11);
    expect(o.state.dailyRoundsDone, 1);
    expect(o.state.dailyQuestDate, '2026-11-02');
    expect(o.state.lastPlayDate, '2026-11-02');
  });

  test('the third round of the day completes the quest', () {
    const s = RewardState(snowflakesTotal: 30, castleLevel: 2, dailyQuestDate: '2026-11-02', dailyRoundsDone: 2);
    final o = applyRound(s, firstTryCorrect: 8, today: '2026-11-02', levels: levels);
    expect(o.questCompleted, isTrue);
    expect(o.earned, 8 + kRoundBonus + kQuestBonus);
    expect(o.state.dailyRoundsDone, 3);
  });

  test('a fourth round does not complete the quest again', () {
    const s = RewardState(dailyQuestDate: '2026-11-02', dailyRoundsDone: 3);
    final o = applyRound(s, firstTryCorrect: 0, today: '2026-11-02', levels: levels);
    expect(o.questCompleted, isFalse);
    expect(o.earned, kRoundBonus);
  });

  test('a new day resets the daily round count', () {
    const s = RewardState(dailyQuestDate: '2026-11-01', dailyRoundsDone: 2);
    final o = applyRound(s, firstTryCorrect: 0, today: '2026-11-02', levels: levels);
    expect(o.questCompleted, isFalse);
    expect(o.state.dailyRoundsDone, 1);
  });

  test('crossing a level with a friend unlocks it', () {
    const s = RewardState(snowflakesTotal: 15);
    final o = applyRound(s, firstTryCorrect: 0, today: '2026-11-02', levels: levels);
    expect(o.state.snowflakesTotal, 20);
    expect(o.previousLevel, 1);
    expect(o.newLevel, 2);
    expect(o.leveledUp, isTrue);
    expect(o.friendUnlocked, 'olaf');
  });

  test('crossing a level without a friend unlocks nobody', () {
    const s = RewardState(snowflakesTotal: 45, castleLevel: 2);
    final o = applyRound(s, firstTryCorrect: 0, today: '2026-11-02', levels: levels);
    expect(o.newLevel, 3);
    expect(o.friendUnlocked, isNull);
  });

  test('roundsToday ignores counts from other days', () {
    const s = RewardState(dailyQuestDate: '2026-11-01', dailyRoundsDone: 2);
    expect(roundsToday(s, '2026-11-01'), 2);
    expect(roundsToday(s, '2026-11-02'), 0);
  });
}
