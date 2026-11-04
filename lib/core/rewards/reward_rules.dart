import '../content/models.dart';
import 'reward_state.dart';

const kRoundBonus = 5;
const kQuestRounds = 3;

/// Gift for finishing the daily quest while there are no stickers yet.
const kQuestBonus = 20;

/// [levels] must be sorted by snowflakes ascending.
int castleLevelFor(int total, List<CastleLevel> levels) {
  var level = 1;
  for (final l in levels) {
    if (total >= l.snowflakes) level = l.level;
  }
  return level;
}

int roundsToday(RewardState s, String today) => s.dailyQuestDate == today ? s.dailyRoundsDone : 0;

RewardOutcome applyRound(
  RewardState s, {
  required int firstTryCorrect,
  required String today,
  required List<CastleLevel> levels,
}) {
  final rounds = roundsToday(s, today) + 1;
  final questCompleted = rounds == kQuestRounds;
  final earned = firstTryCorrect + kRoundBonus + (questCompleted ? kQuestBonus : 0);
  final total = s.snowflakesTotal + earned;
  final newLevel = castleLevelFor(total, levels);
  String? friend;
  for (final l in levels) {
    if (l.level > s.castleLevel && l.level <= newLevel && l.friend != null) friend = l.friend;
  }
  return RewardOutcome(
    earned: earned,
    questBonus: questCompleted ? kQuestBonus : 0,
    questCompleted: questCompleted,
    previousLevel: s.castleLevel,
    newLevel: newLevel,
    friendUnlocked: friend,
    state: RewardState(
      snowflakesTotal: total,
      castleLevel: newLevel,
      streakDays: s.streakDays,
      lastPlayDate: today,
      dailyQuestDate: today,
      dailyRoundsDone: rounds,
    ),
  );
}
