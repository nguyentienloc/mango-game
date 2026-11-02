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
    required this.questCompleted,
    required this.previousLevel,
    required this.newLevel,
    required this.friendUnlocked,
    required this.state,
  });

  final int earned;
  final bool questCompleted;
  final int previousLevel;
  final int newLevel;
  final String? friendUnlocked;
  final RewardState state;

  bool get leveledUp => newLevel > previousLevel;
}
