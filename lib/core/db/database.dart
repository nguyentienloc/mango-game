import 'package:drift/drift.dart';

part 'database.g.dart';

@DataClassName('ItemStatRow')
class ItemStats extends Table {
  TextColumn get itemKey => text()();
  IntColumn get mastery => integer().withDefault(const Constant(0))();
  IntColumn get correct => integer().withDefault(const Constant(0))();
  IntColumn get wrong => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSeen => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {itemKey};
}

@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  TextColumn get game => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationSec => integer()();
  IntColumn get correct => integer()();
  IntColumn get total => integer()();
}

@DataClassName('RewardRow')
class Rewards extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get snowflakesTotal => integer().withDefault(const Constant(0))();
  IntColumn get castleLevel => integer().withDefault(const Constant(1))();
  IntColumn get streakDays => integer().withDefault(const Constant(0))();
  TextColumn get lastPlayDate => text().nullable()();
  TextColumn get dailyQuestDate => text().nullable()();
  IntColumn get dailyRoundsDone => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProfileRow')
class Profile extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get nameEn => text()();
  TextColumn get nameVi => text()();
  IntColumn get dailyLimitMin => integer()();
  BoolColumn get musicOn => boolean().withDefault(const Constant(true))();
  BoolColumn get testMode => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ItemStats, Sessions, Rewards, Profile])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
