enum AnswerOutcome { firstTry, retry, hinted }

class ItemStat {
  const ItemStat({required this.key, this.mastery = 0, this.correct = 0, this.wrong = 0, this.lastSeen});

  final String key;
  final int mastery;
  final int correct;
  final int wrong;
  final DateTime? lastSeen;
}
