class RewardState {
  const RewardState({
    this.snowflakesTotal = 0,
    this.castleLevel = 1,
    this.streakDays = 0,
    this.lastPlayDate,
    this.dailyQuestDate,
    this.dailyRoundsDone = 0,
  });

  final int snowflakesTotal;
  final int castleLevel;
  final int streakDays;
  final String? lastPlayDate;
  final String? dailyQuestDate;
  final int dailyRoundsDone;
}

class RewardOutcome {
  const RewardOutcome({
    required this.earned,
    this.questBonus = 0,
    required this.questCompleted,
    required this.previousLevel,
    required this.newLevel,
    required this.friendUnlocked,
    required this.state,
  });

  /// Snowflakes in total for the round, the quest gift included.
  final int earned;

  /// The part of [earned] that is the daily-quest gift (0 without a quest);
  /// the reward screen shows it inside the gift box until it is opened.
  final int questBonus;
  final bool questCompleted;
  final int previousLevel;
  final int newLevel;
  final String? friendUnlocked;
  final RewardState state;

  bool get leveledUp => newLevel > previousLevel;
}
