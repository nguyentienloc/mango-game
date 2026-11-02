import 'package:drift/drift.dart';

import '../content/models.dart';
import '../db/database.dart';
import 'names.dart';

abstract interface class ProfileStore {
  /// Returns the stored names, creating the profile from [defaults] on first run.
  Future<Names> loadNames(ProfileDefaults defaults);
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
}
