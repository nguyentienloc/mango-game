import '../db/database.dart';

class SessionRecord {
  const SessionRecord({
    required this.date,
    required this.game,
    required this.startedAt,
    required this.durationSec,
    required this.correct,
    required this.total,
  });

  final String date;
  final String game;
  final DateTime startedAt;
  final int durationSec;
  final int correct;
  final int total;
}

abstract interface class SessionStore {
  Future<void> add(SessionRecord record);
}

class DriftSessionStore implements SessionStore {
  DriftSessionStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> add(SessionRecord r) async {
    await _db.into(_db.sessions).insert(SessionsCompanion.insert(
          date: r.date,
          game: r.game,
          startedAt: r.startedAt,
          durationSec: r.durationSec,
          correct: r.correct,
          total: r.total,
        ));
  }
}
