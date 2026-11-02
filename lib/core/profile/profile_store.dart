import 'package:drift/drift.dart';

import '../content/models.dart';
import '../db/database.dart';
import 'names.dart';

abstract interface class ProfileStore {
  /// Returns the stored names, creating the profile from [defaults] on first run.
  Future<Names> loadNames(ProfileDefaults defaults);

  /// Parent switch: whether the find-letter game is shown on the home screen.
  Future<bool> showFindLetter();

  Future<void> setShowFindLetter(bool value);
}

class DriftProfileStore implements ProfileStore {
  DriftProfileStore(this._db);

  final AppDatabase _db;

  @override
  Future<Names> loadNames(ProfileDefaults defaults) async {
    await _db.into(_db.profile).insert(
          ProfileCompanion.insert(
            id: const Value(1),
            nameEn: defaults.nameEn,
            nameVi: defaults.nameVi,
            dailyLimitMin: defaults.dailyLimitMin,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final row = await _db.select(_db.profile).getSingle();
    return Names(en: row.nameEn, vi: row.nameVi);
  }

  @override
  Future<bool> showFindLetter() async {
    final row = await (_db.select(_db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();
    return row?.showFindLetter ?? false;
  }

  @override
  Future<void> setShowFindLetter(bool value) async {
    await (_db.update(_db.profile)..where((t) => t.id.equals(1))).write(ProfileCompanion(showFindLetter: Value(value)));
  }
}
