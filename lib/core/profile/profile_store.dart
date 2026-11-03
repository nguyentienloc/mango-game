import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../content/models.dart';
import '../db/database.dart';
import 'names.dart';

/// Parent-chosen speech speed per language (1.0 = as recorded / normal rate).
@immutable
class VoiceSpeeds {
  const VoiceSpeeds({this.en = defaultEn, this.vi = defaultVi});

  static const defaultEn = 0.85;
  static const defaultVi = 1.0;
  static const min = 0.6;
  static const max = 1.3;

  final double en;
  final double vi;

  double forLang(String lang) => lang == 'vi' ? vi : en;

  /// Both speeds limited to [min]..[max].
  VoiceSpeeds clamped() => VoiceSpeeds(en: en.clamp(min, max), vi: vi.clamp(min, max));

  VoiceSpeeds copyWith({double? en, double? vi}) => VoiceSpeeds(en: en ?? this.en, vi: vi ?? this.vi);

  @override
  bool operator ==(Object other) => other is VoiceSpeeds && other.en == en && other.vi == vi;

  @override
  int get hashCode => Object.hash(en, vi);

  @override
  String toString() => 'VoiceSpeeds(en: $en, vi: $vi)';
}

abstract interface class ProfileStore {
  /// Returns the stored names, creating the profile from [defaults] on first run.
  Future<Names> loadNames(ProfileDefaults defaults);

  /// Parent switch: whether the find-letter game is shown on the home screen.
  // unused since v0.4.0 (column kept so the schema and migrations stay unchanged)
  Future<bool> showFindLetter();

  // unused since v0.4.0
  Future<void> setShowFindLetter(bool value);

  Future<VoiceSpeeds> voiceSpeeds();

  /// Values outside [VoiceSpeeds.min]..[VoiceSpeeds.max] are clamped.
  Future<void> setVoiceSpeeds(VoiceSpeeds speeds);
}

class DriftProfileStore implements ProfileStore {
  DriftProfileStore(this._db);

  final AppDatabase _db;

  @override
  Future<Names> loadNames(ProfileDefaults defaults) async {
    await _db
        .into(_db.profile)
        .insert(
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

  @override
  Future<VoiceSpeeds> voiceSpeeds() async {
    final row = await (_db.select(_db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row == null) return const VoiceSpeeds();
    return VoiceSpeeds(en: row.enSpeed, vi: row.viSpeed).clamped();
  }

  @override
  Future<void> setVoiceSpeeds(VoiceSpeeds speeds) async {
    final s = speeds.clamped();
    await (_db.update(
      _db.profile,
    )..where((t) => t.id.equals(1))).write(ProfileCompanion(enSpeed: Value(s.en), viSpeed: Value(s.vi)));
  }
}
