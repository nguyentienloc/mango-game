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
  BoolColumn get showFindLetter => boolean().withDefault(const Constant(false))();
  RealColumn get enSpeed => real().withDefault(const Constant(0.85))();
  RealColumn get viSpeed => real().withDefault(const Constant(1.0))();

  /// JSON of the last story setup (StorySetup.toJson); null until the parent picks one.
  TextColumn get storySetup => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stories a parent added by pasting a YouTube link.
@DataClassName('UserStoryRow')
class UserStories extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get topic => text()();
  IntColumn get durationSec => integer().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {videoId};
}

/// Story ids ('yt:<videoId>') the parent hid from the list.
@DataClassName('HiddenStoryRow')
class HiddenStories extends Table {
  TextColumn get storyId => text()();

  @override
  Set<Column> get primaryKey => {storyId};
}

@DriftDatabase(tables: [ItemStats, Sessions, Rewards, Profile, UserStories, HiddenStories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(profile, profile.showFindLetter);
      if (from < 3) {
        await m.addColumn(profile, profile.enSpeed);
        await m.addColumn(profile, profile.viSpeed);
      }
      if (from < 4) {
        await m.createTable(userStories);
        await m.createTable(hiddenStories);
        await m.addColumn(profile, profile.storySetup);
      }
    },
  );
}
