// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ItemStatsTable extends ItemStats
    with TableInfo<$ItemStatsTable, ItemStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemKeyMeta = const VerificationMeta(
    'itemKey',
  );
  @override
  late final GeneratedColumn<String> itemKey = GeneratedColumn<String>(
    'item_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _masteryMeta = const VerificationMeta(
    'mastery',
  );
  @override
  late final GeneratedColumn<int> mastery = GeneratedColumn<int>(
    'mastery',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wrongMeta = const VerificationMeta('wrong');
  @override
  late final GeneratedColumn<int> wrong = GeneratedColumn<int>(
    'wrong',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemKey,
    mastery,
    correct,
    wrong,
    lastSeen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_key')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['item_key']!, _itemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeyMeta);
    }
    if (data.containsKey('mastery')) {
      context.handle(
        _masteryMeta,
        mastery.isAcceptableOrUnknown(data['mastery']!, _masteryMeta),
      );
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    }
    if (data.containsKey('wrong')) {
      context.handle(
        _wrongMeta,
        wrong.isAcceptableOrUnknown(data['wrong']!, _wrongMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemKey};
  @override
  ItemStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemStatRow(
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_key'],
      )!,
      mastery: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mastery'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      wrong: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      ),
    );
  }

  @override
  $ItemStatsTable createAlias(String alias) {
    return $ItemStatsTable(attachedDatabase, alias);
  }
}

class ItemStatRow extends DataClass implements Insertable<ItemStatRow> {
  final String itemKey;
  final int mastery;
  final int correct;
  final int wrong;
  final DateTime? lastSeen;
  const ItemStatRow({
    required this.itemKey,
    required this.mastery,
    required this.correct,
    required this.wrong,
    this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_key'] = Variable<String>(itemKey);
    map['mastery'] = Variable<int>(mastery);
    map['correct'] = Variable<int>(correct);
    map['wrong'] = Variable<int>(wrong);
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<DateTime>(lastSeen);
    }
    return map;
  }

  ItemStatsCompanion toCompanion(bool nullToAbsent) {
    return ItemStatsCompanion(
      itemKey: Value(itemKey),
      mastery: Value(mastery),
      correct: Value(correct),
      wrong: Value(wrong),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
    );
  }

  factory ItemStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemStatRow(
      itemKey: serializer.fromJson<String>(json['itemKey']),
      mastery: serializer.fromJson<int>(json['mastery']),
      correct: serializer.fromJson<int>(json['correct']),
      wrong: serializer.fromJson<int>(json['wrong']),
      lastSeen: serializer.fromJson<DateTime?>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemKey': serializer.toJson<String>(itemKey),
      'mastery': serializer.toJson<int>(mastery),
      'correct': serializer.toJson<int>(correct),
      'wrong': serializer.toJson<int>(wrong),
      'lastSeen': serializer.toJson<DateTime?>(lastSeen),
    };
  }

  ItemStatRow copyWith({
    String? itemKey,
    int? mastery,
    int? correct,
    int? wrong,
    Value<DateTime?> lastSeen = const Value.absent(),
  }) => ItemStatRow(
    itemKey: itemKey ?? this.itemKey,
    mastery: mastery ?? this.mastery,
    correct: correct ?? this.correct,
    wrong: wrong ?? this.wrong,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
  );
  ItemStatRow copyWithCompanion(ItemStatsCompanion data) {
    return ItemStatRow(
      itemKey: data.itemKey.present ? data.itemKey.value : this.itemKey,
      mastery: data.mastery.present ? data.mastery.value : this.mastery,
      correct: data.correct.present ? data.correct.value : this.correct,
      wrong: data.wrong.present ? data.wrong.value : this.wrong,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemStatRow(')
          ..write('itemKey: $itemKey, ')
          ..write('mastery: $mastery, ')
          ..write('correct: $correct, ')
          ..write('wrong: $wrong, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemKey, mastery, correct, wrong, lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemStatRow &&
          other.itemKey == this.itemKey &&
          other.mastery == this.mastery &&
          other.correct == this.correct &&
          other.wrong == this.wrong &&
          other.lastSeen == this.lastSeen);
}

class ItemStatsCompanion extends UpdateCompanion<ItemStatRow> {
  final Value<String> itemKey;
  final Value<int> mastery;
  final Value<int> correct;
  final Value<int> wrong;
  final Value<DateTime?> lastSeen;
  final Value<int> rowid;
  const ItemStatsCompanion({
    this.itemKey = const Value.absent(),
    this.mastery = const Value.absent(),
    this.correct = const Value.absent(),
    this.wrong = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemStatsCompanion.insert({
    required String itemKey,
    this.mastery = const Value.absent(),
    this.correct = const Value.absent(),
    this.wrong = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemKey = Value(itemKey);
  static Insertable<ItemStatRow> custom({
    Expression<String>? itemKey,
    Expression<int>? mastery,
    Expression<int>? correct,
    Expression<int>? wrong,
    Expression<DateTime>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemKey != null) 'item_key': itemKey,
      if (mastery != null) 'mastery': mastery,
      if (correct != null) 'correct': correct,
      if (wrong != null) 'wrong': wrong,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemStatsCompanion copyWith({
    Value<String>? itemKey,
    Value<int>? mastery,
    Value<int>? correct,
    Value<int>? wrong,
    Value<DateTime?>? lastSeen,
    Value<int>? rowid,
  }) {
    return ItemStatsCompanion(
      itemKey: itemKey ?? this.itemKey,
      mastery: mastery ?? this.mastery,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemKey.present) {
      map['item_key'] = Variable<String>(itemKey.value);
    }
    if (mastery.present) {
      map['mastery'] = Variable<int>(mastery.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (wrong.present) {
      map['wrong'] = Variable<int>(wrong.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemStatsCompanion(')
          ..write('itemKey: $itemKey, ')
          ..write('mastery: $mastery, ')
          ..write('correct: $correct, ')
          ..write('wrong: $wrong, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameMeta = const VerificationMeta('game');
  @override
  late final GeneratedColumn<String> game = GeneratedColumn<String>(
    'game',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    game,
    startedAt,
    durationSec,
    correct,
    total,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('game')) {
      context.handle(
        _gameMeta,
        game.isAcceptableOrUnknown(data['game']!, _gameMeta),
      );
    } else if (isInserting) {
      context.missing(_gameMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      game: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final int id;
  final String date;
  final String game;
  final DateTime startedAt;
  final int durationSec;
  final int correct;
  final int total;
  const SessionRow({
    required this.id,
    required this.date,
    required this.game,
    required this.startedAt,
    required this.durationSec,
    required this.correct,
    required this.total,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    map['game'] = Variable<String>(game);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_sec'] = Variable<int>(durationSec);
    map['correct'] = Variable<int>(correct);
    map['total'] = Variable<int>(total);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      date: Value(date),
      game: Value(game),
      startedAt: Value(startedAt),
      durationSec: Value(durationSec),
      correct: Value(correct),
      total: Value(total),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      game: serializer.fromJson<String>(json['game']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      correct: serializer.fromJson<int>(json['correct']),
      total: serializer.fromJson<int>(json['total']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'game': serializer.toJson<String>(game),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationSec': serializer.toJson<int>(durationSec),
      'correct': serializer.toJson<int>(correct),
      'total': serializer.toJson<int>(total),
    };
  }

  SessionRow copyWith({
    int? id,
    String? date,
    String? game,
    DateTime? startedAt,
    int? durationSec,
    int? correct,
    int? total,
  }) => SessionRow(
    id: id ?? this.id,
    date: date ?? this.date,
    game: game ?? this.game,
    startedAt: startedAt ?? this.startedAt,
    durationSec: durationSec ?? this.durationSec,
    correct: correct ?? this.correct,
    total: total ?? this.total,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      game: data.game.present ? data.game.value : this.game,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      correct: data.correct.present ? data.correct.value : this.correct,
      total: data.total.present ? data.total.value : this.total,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('game: $game, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSec: $durationSec, ')
          ..write('correct: $correct, ')
          ..write('total: $total')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, game, startedAt, durationSec, correct, total);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.game == this.game &&
          other.startedAt == this.startedAt &&
          other.durationSec == this.durationSec &&
          other.correct == this.correct &&
          other.total == this.total);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<int> id;
  final Value<String> date;
  final Value<String> game;
  final Value<DateTime> startedAt;
  final Value<int> durationSec;
  final Value<int> correct;
  final Value<int> total;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.game = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.correct = const Value.absent(),
    this.total = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    required String game,
    required DateTime startedAt,
    required int durationSec,
    required int correct,
    required int total,
  }) : date = Value(date),
       game = Value(game),
       startedAt = Value(startedAt),
       durationSec = Value(durationSec),
       correct = Value(correct),
       total = Value(total);
  static Insertable<SessionRow> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<String>? game,
    Expression<DateTime>? startedAt,
    Expression<int>? durationSec,
    Expression<int>? correct,
    Expression<int>? total,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (game != null) 'game': game,
      if (startedAt != null) 'started_at': startedAt,
      if (durationSec != null) 'duration_sec': durationSec,
      if (correct != null) 'correct': correct,
      if (total != null) 'total': total,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<String>? game,
    Value<DateTime>? startedAt,
    Value<int>? durationSec,
    Value<int>? correct,
    Value<int>? total,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      game: game ?? this.game,
      startedAt: startedAt ?? this.startedAt,
      durationSec: durationSec ?? this.durationSec,
      correct: correct ?? this.correct,
      total: total ?? this.total,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (game.present) {
      map['game'] = Variable<String>(game.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('game: $game, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSec: $durationSec, ')
          ..write('correct: $correct, ')
          ..write('total: $total')
          ..write(')'))
        .toString();
  }
}

class $RewardsTable extends Rewards with TableInfo<$RewardsTable, RewardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _snowflakesTotalMeta = const VerificationMeta(
    'snowflakesTotal',
  );
  @override
  late final GeneratedColumn<int> snowflakesTotal = GeneratedColumn<int>(
    'snowflakes_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _castleLevelMeta = const VerificationMeta(
    'castleLevel',
  );
  @override
  late final GeneratedColumn<int> castleLevel = GeneratedColumn<int>(
    'castle_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _streakDaysMeta = const VerificationMeta(
    'streakDays',
  );
  @override
  late final GeneratedColumn<int> streakDays = GeneratedColumn<int>(
    'streak_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayDateMeta = const VerificationMeta(
    'lastPlayDate',
  );
  @override
  late final GeneratedColumn<String> lastPlayDate = GeneratedColumn<String>(
    'last_play_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyQuestDateMeta = const VerificationMeta(
    'dailyQuestDate',
  );
  @override
  late final GeneratedColumn<String> dailyQuestDate = GeneratedColumn<String>(
    'daily_quest_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyRoundsDoneMeta = const VerificationMeta(
    'dailyRoundsDone',
  );
  @override
  late final GeneratedColumn<int> dailyRoundsDone = GeneratedColumn<int>(
    'daily_rounds_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snowflakesTotal,
    castleLevel,
    streakDays,
    lastPlayDate,
    dailyQuestDate,
    dailyRoundsDone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rewards';
  @override
  VerificationContext validateIntegrity(
    Insertable<RewardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('snowflakes_total')) {
      context.handle(
        _snowflakesTotalMeta,
        snowflakesTotal.isAcceptableOrUnknown(
          data['snowflakes_total']!,
          _snowflakesTotalMeta,
        ),
      );
    }
    if (data.containsKey('castle_level')) {
      context.handle(
        _castleLevelMeta,
        castleLevel.isAcceptableOrUnknown(
          data['castle_level']!,
          _castleLevelMeta,
        ),
      );
    }
    if (data.containsKey('streak_days')) {
      context.handle(
        _streakDaysMeta,
        streakDays.isAcceptableOrUnknown(data['streak_days']!, _streakDaysMeta),
      );
    }
    if (data.containsKey('last_play_date')) {
      context.handle(
        _lastPlayDateMeta,
        lastPlayDate.isAcceptableOrUnknown(
          data['last_play_date']!,
          _lastPlayDateMeta,
        ),
      );
    }
    if (data.containsKey('daily_quest_date')) {
      context.handle(
        _dailyQuestDateMeta,
        dailyQuestDate.isAcceptableOrUnknown(
          data['daily_quest_date']!,
          _dailyQuestDateMeta,
        ),
      );
    }
    if (data.containsKey('daily_rounds_done')) {
      context.handle(
        _dailyRoundsDoneMeta,
        dailyRoundsDone.isAcceptableOrUnknown(
          data['daily_rounds_done']!,
          _dailyRoundsDoneMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RewardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RewardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      snowflakesTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snowflakes_total'],
      )!,
      castleLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}castle_level'],
      )!,
      streakDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak_days'],
      )!,
      lastPlayDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_play_date'],
      ),
      dailyQuestDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}daily_quest_date'],
      ),
      dailyRoundsDone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_rounds_done'],
      )!,
    );
  }

  @override
  $RewardsTable createAlias(String alias) {
    return $RewardsTable(attachedDatabase, alias);
  }
}

class RewardRow extends DataClass implements Insertable<RewardRow> {
  final int id;
  final int snowflakesTotal;
  final int castleLevel;
  final int streakDays;
  final String? lastPlayDate;
  final String? dailyQuestDate;
  final int dailyRoundsDone;
  const RewardRow({
    required this.id,
    required this.snowflakesTotal,
    required this.castleLevel,
    required this.streakDays,
    this.lastPlayDate,
    this.dailyQuestDate,
    required this.dailyRoundsDone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['snowflakes_total'] = Variable<int>(snowflakesTotal);
    map['castle_level'] = Variable<int>(castleLevel);
    map['streak_days'] = Variable<int>(streakDays);
    if (!nullToAbsent || lastPlayDate != null) {
      map['last_play_date'] = Variable<String>(lastPlayDate);
    }
    if (!nullToAbsent || dailyQuestDate != null) {
      map['daily_quest_date'] = Variable<String>(dailyQuestDate);
    }
    map['daily_rounds_done'] = Variable<int>(dailyRoundsDone);
    return map;
  }

  RewardsCompanion toCompanion(bool nullToAbsent) {
    return RewardsCompanion(
      id: Value(id),
      snowflakesTotal: Value(snowflakesTotal),
      castleLevel: Value(castleLevel),
      streakDays: Value(streakDays),
      lastPlayDate: lastPlayDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayDate),
      dailyQuestDate: dailyQuestDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dailyQuestDate),
      dailyRoundsDone: Value(dailyRoundsDone),
    );
  }

  factory RewardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RewardRow(
      id: serializer.fromJson<int>(json['id']),
      snowflakesTotal: serializer.fromJson<int>(json['snowflakesTotal']),
      castleLevel: serializer.fromJson<int>(json['castleLevel']),
      streakDays: serializer.fromJson<int>(json['streakDays']),
      lastPlayDate: serializer.fromJson<String?>(json['lastPlayDate']),
      dailyQuestDate: serializer.fromJson<String?>(json['dailyQuestDate']),
      dailyRoundsDone: serializer.fromJson<int>(json['dailyRoundsDone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'snowflakesTotal': serializer.toJson<int>(snowflakesTotal),
      'castleLevel': serializer.toJson<int>(castleLevel),
      'streakDays': serializer.toJson<int>(streakDays),
      'lastPlayDate': serializer.toJson<String?>(lastPlayDate),
      'dailyQuestDate': serializer.toJson<String?>(dailyQuestDate),
      'dailyRoundsDone': serializer.toJson<int>(dailyRoundsDone),
    };
  }

  RewardRow copyWith({
    int? id,
    int? snowflakesTotal,
    int? castleLevel,
    int? streakDays,
    Value<String?> lastPlayDate = const Value.absent(),
    Value<String?> dailyQuestDate = const Value.absent(),
    int? dailyRoundsDone,
  }) => RewardRow(
    id: id ?? this.id,
    snowflakesTotal: snowflakesTotal ?? this.snowflakesTotal,
    castleLevel: castleLevel ?? this.castleLevel,
    streakDays: streakDays ?? this.streakDays,
    lastPlayDate: lastPlayDate.present ? lastPlayDate.value : this.lastPlayDate,
    dailyQuestDate: dailyQuestDate.present
        ? dailyQuestDate.value
        : this.dailyQuestDate,
    dailyRoundsDone: dailyRoundsDone ?? this.dailyRoundsDone,
  );
  RewardRow copyWithCompanion(RewardsCompanion data) {
    return RewardRow(
      id: data.id.present ? data.id.value : this.id,
      snowflakesTotal: data.snowflakesTotal.present
          ? data.snowflakesTotal.value
          : this.snowflakesTotal,
      castleLevel: data.castleLevel.present
          ? data.castleLevel.value
          : this.castleLevel,
      streakDays: data.streakDays.present
          ? data.streakDays.value
          : this.streakDays,
      lastPlayDate: data.lastPlayDate.present
          ? data.lastPlayDate.value
          : this.lastPlayDate,
      dailyQuestDate: data.dailyQuestDate.present
          ? data.dailyQuestDate.value
          : this.dailyQuestDate,
      dailyRoundsDone: data.dailyRoundsDone.present
          ? data.dailyRoundsDone.value
          : this.dailyRoundsDone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RewardRow(')
          ..write('id: $id, ')
          ..write('snowflakesTotal: $snowflakesTotal, ')
          ..write('castleLevel: $castleLevel, ')
          ..write('streakDays: $streakDays, ')
          ..write('lastPlayDate: $lastPlayDate, ')
          ..write('dailyQuestDate: $dailyQuestDate, ')
          ..write('dailyRoundsDone: $dailyRoundsDone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snowflakesTotal,
    castleLevel,
    streakDays,
    lastPlayDate,
    dailyQuestDate,
    dailyRoundsDone,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RewardRow &&
          other.id == this.id &&
          other.snowflakesTotal == this.snowflakesTotal &&
          other.castleLevel == this.castleLevel &&
          other.streakDays == this.streakDays &&
          other.lastPlayDate == this.lastPlayDate &&
          other.dailyQuestDate == this.dailyQuestDate &&
          other.dailyRoundsDone == this.dailyRoundsDone);
}

class RewardsCompanion extends UpdateCompanion<RewardRow> {
  final Value<int> id;
  final Value<int> snowflakesTotal;
  final Value<int> castleLevel;
  final Value<int> streakDays;
  final Value<String?> lastPlayDate;
  final Value<String?> dailyQuestDate;
  final Value<int> dailyRoundsDone;
  const RewardsCompanion({
    this.id = const Value.absent(),
    this.snowflakesTotal = const Value.absent(),
    this.castleLevel = const Value.absent(),
    this.streakDays = const Value.absent(),
    this.lastPlayDate = const Value.absent(),
    this.dailyQuestDate = const Value.absent(),
    this.dailyRoundsDone = const Value.absent(),
  });
  RewardsCompanion.insert({
    this.id = const Value.absent(),
    this.snowflakesTotal = const Value.absent(),
    this.castleLevel = const Value.absent(),
    this.streakDays = const Value.absent(),
    this.lastPlayDate = const Value.absent(),
    this.dailyQuestDate = const Value.absent(),
    this.dailyRoundsDone = const Value.absent(),
  });
  static Insertable<RewardRow> custom({
    Expression<int>? id,
    Expression<int>? snowflakesTotal,
    Expression<int>? castleLevel,
    Expression<int>? streakDays,
    Expression<String>? lastPlayDate,
    Expression<String>? dailyQuestDate,
    Expression<int>? dailyRoundsDone,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snowflakesTotal != null) 'snowflakes_total': snowflakesTotal,
      if (castleLevel != null) 'castle_level': castleLevel,
      if (streakDays != null) 'streak_days': streakDays,
      if (lastPlayDate != null) 'last_play_date': lastPlayDate,
      if (dailyQuestDate != null) 'daily_quest_date': dailyQuestDate,
      if (dailyRoundsDone != null) 'daily_rounds_done': dailyRoundsDone,
    });
  }

  RewardsCompanion copyWith({
    Value<int>? id,
    Value<int>? snowflakesTotal,
    Value<int>? castleLevel,
    Value<int>? streakDays,
    Value<String?>? lastPlayDate,
    Value<String?>? dailyQuestDate,
    Value<int>? dailyRoundsDone,
  }) {
    return RewardsCompanion(
      id: id ?? this.id,
      snowflakesTotal: snowflakesTotal ?? this.snowflakesTotal,
      castleLevel: castleLevel ?? this.castleLevel,
      streakDays: streakDays ?? this.streakDays,
      lastPlayDate: lastPlayDate ?? this.lastPlayDate,
      dailyQuestDate: dailyQuestDate ?? this.dailyQuestDate,
      dailyRoundsDone: dailyRoundsDone ?? this.dailyRoundsDone,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (snowflakesTotal.present) {
      map['snowflakes_total'] = Variable<int>(snowflakesTotal.value);
    }
    if (castleLevel.present) {
      map['castle_level'] = Variable<int>(castleLevel.value);
    }
    if (streakDays.present) {
      map['streak_days'] = Variable<int>(streakDays.value);
    }
    if (lastPlayDate.present) {
      map['last_play_date'] = Variable<String>(lastPlayDate.value);
    }
    if (dailyQuestDate.present) {
      map['daily_quest_date'] = Variable<String>(dailyQuestDate.value);
    }
    if (dailyRoundsDone.present) {
      map['daily_rounds_done'] = Variable<int>(dailyRoundsDone.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardsCompanion(')
          ..write('id: $id, ')
          ..write('snowflakesTotal: $snowflakesTotal, ')
          ..write('castleLevel: $castleLevel, ')
          ..write('streakDays: $streakDays, ')
          ..write('lastPlayDate: $lastPlayDate, ')
          ..write('dailyQuestDate: $dailyQuestDate, ')
          ..write('dailyRoundsDone: $dailyRoundsDone')
          ..write(')'))
        .toString();
  }
}

class $ProfileTable extends Profile with TableInfo<$ProfileTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _nameEnMeta = const VerificationMeta('nameEn');
  @override
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
    'name_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameViMeta = const VerificationMeta('nameVi');
  @override
  late final GeneratedColumn<String> nameVi = GeneratedColumn<String>(
    'name_vi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyLimitMinMeta = const VerificationMeta(
    'dailyLimitMin',
  );
  @override
  late final GeneratedColumn<int> dailyLimitMin = GeneratedColumn<int>(
    'daily_limit_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _musicOnMeta = const VerificationMeta(
    'musicOn',
  );
  @override
  late final GeneratedColumn<bool> musicOn = GeneratedColumn<bool>(
    'music_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("music_on" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _testModeMeta = const VerificationMeta(
    'testMode',
  );
  @override
  late final GeneratedColumn<bool> testMode = GeneratedColumn<bool>(
    'test_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("test_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showFindLetterMeta = const VerificationMeta(
    'showFindLetter',
  );
  @override
  late final GeneratedColumn<bool> showFindLetter = GeneratedColumn<bool>(
    'show_find_letter',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_find_letter" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nameEn,
    nameVi,
    dailyLimitMin,
    musicOn,
    testMode,
    showFindLetter,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name_en')) {
      context.handle(
        _nameEnMeta,
        nameEn.isAcceptableOrUnknown(data['name_en']!, _nameEnMeta),
      );
    } else if (isInserting) {
      context.missing(_nameEnMeta);
    }
    if (data.containsKey('name_vi')) {
      context.handle(
        _nameViMeta,
        nameVi.isAcceptableOrUnknown(data['name_vi']!, _nameViMeta),
      );
    } else if (isInserting) {
      context.missing(_nameViMeta);
    }
    if (data.containsKey('daily_limit_min')) {
      context.handle(
        _dailyLimitMinMeta,
        dailyLimitMin.isAcceptableOrUnknown(
          data['daily_limit_min']!,
          _dailyLimitMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyLimitMinMeta);
    }
    if (data.containsKey('music_on')) {
      context.handle(
        _musicOnMeta,
        musicOn.isAcceptableOrUnknown(data['music_on']!, _musicOnMeta),
      );
    }
    if (data.containsKey('test_mode')) {
      context.handle(
        _testModeMeta,
        testMode.isAcceptableOrUnknown(data['test_mode']!, _testModeMeta),
      );
    }
    if (data.containsKey('show_find_letter')) {
      context.handle(
        _showFindLetterMeta,
        showFindLetter.isAcceptableOrUnknown(
          data['show_find_letter']!,
          _showFindLetterMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nameEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_en'],
      )!,
      nameVi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_vi'],
      )!,
      dailyLimitMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_limit_min'],
      )!,
      musicOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}music_on'],
      )!,
      testMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}test_mode'],
      )!,
      showFindLetter: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_find_letter'],
      )!,
    );
  }

  @override
  $ProfileTable createAlias(String alias) {
    return $ProfileTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final int id;
  final String nameEn;
  final String nameVi;
  final int dailyLimitMin;
  final bool musicOn;
  final bool testMode;
  final bool showFindLetter;
  const ProfileRow({
    required this.id,
    required this.nameEn,
    required this.nameVi,
    required this.dailyLimitMin,
    required this.musicOn,
    required this.testMode,
    required this.showFindLetter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name_en'] = Variable<String>(nameEn);
    map['name_vi'] = Variable<String>(nameVi);
    map['daily_limit_min'] = Variable<int>(dailyLimitMin);
    map['music_on'] = Variable<bool>(musicOn);
    map['test_mode'] = Variable<bool>(testMode);
    map['show_find_letter'] = Variable<bool>(showFindLetter);
    return map;
  }

  ProfileCompanion toCompanion(bool nullToAbsent) {
    return ProfileCompanion(
      id: Value(id),
      nameEn: Value(nameEn),
      nameVi: Value(nameVi),
      dailyLimitMin: Value(dailyLimitMin),
      musicOn: Value(musicOn),
      testMode: Value(testMode),
      showFindLetter: Value(showFindLetter),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<int>(json['id']),
      nameEn: serializer.fromJson<String>(json['nameEn']),
      nameVi: serializer.fromJson<String>(json['nameVi']),
      dailyLimitMin: serializer.fromJson<int>(json['dailyLimitMin']),
      musicOn: serializer.fromJson<bool>(json['musicOn']),
      testMode: serializer.fromJson<bool>(json['testMode']),
      showFindLetter: serializer.fromJson<bool>(json['showFindLetter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nameEn': serializer.toJson<String>(nameEn),
      'nameVi': serializer.toJson<String>(nameVi),
      'dailyLimitMin': serializer.toJson<int>(dailyLimitMin),
      'musicOn': serializer.toJson<bool>(musicOn),
      'testMode': serializer.toJson<bool>(testMode),
      'showFindLetter': serializer.toJson<bool>(showFindLetter),
    };
  }

  ProfileRow copyWith({
    int? id,
    String? nameEn,
    String? nameVi,
    int? dailyLimitMin,
    bool? musicOn,
    bool? testMode,
    bool? showFindLetter,
  }) => ProfileRow(
    id: id ?? this.id,
    nameEn: nameEn ?? this.nameEn,
    nameVi: nameVi ?? this.nameVi,
    dailyLimitMin: dailyLimitMin ?? this.dailyLimitMin,
    musicOn: musicOn ?? this.musicOn,
    testMode: testMode ?? this.testMode,
    showFindLetter: showFindLetter ?? this.showFindLetter,
  );
  ProfileRow copyWithCompanion(ProfileCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      nameEn: data.nameEn.present ? data.nameEn.value : this.nameEn,
      nameVi: data.nameVi.present ? data.nameVi.value : this.nameVi,
      dailyLimitMin: data.dailyLimitMin.present
          ? data.dailyLimitMin.value
          : this.dailyLimitMin,
      musicOn: data.musicOn.present ? data.musicOn.value : this.musicOn,
      testMode: data.testMode.present ? data.testMode.value : this.testMode,
      showFindLetter: data.showFindLetter.present
          ? data.showFindLetter.value
          : this.showFindLetter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('nameEn: $nameEn, ')
          ..write('nameVi: $nameVi, ')
          ..write('dailyLimitMin: $dailyLimitMin, ')
          ..write('musicOn: $musicOn, ')
          ..write('testMode: $testMode, ')
          ..write('showFindLetter: $showFindLetter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nameEn,
    nameVi,
    dailyLimitMin,
    musicOn,
    testMode,
    showFindLetter,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.nameEn == this.nameEn &&
          other.nameVi == this.nameVi &&
          other.dailyLimitMin == this.dailyLimitMin &&
          other.musicOn == this.musicOn &&
          other.testMode == this.testMode &&
          other.showFindLetter == this.showFindLetter);
}

class ProfileCompanion extends UpdateCompanion<ProfileRow> {
  final Value<int> id;
  final Value<String> nameEn;
  final Value<String> nameVi;
  final Value<int> dailyLimitMin;
  final Value<bool> musicOn;
  final Value<bool> testMode;
  final Value<bool> showFindLetter;
  const ProfileCompanion({
    this.id = const Value.absent(),
    this.nameEn = const Value.absent(),
    this.nameVi = const Value.absent(),
    this.dailyLimitMin = const Value.absent(),
    this.musicOn = const Value.absent(),
    this.testMode = const Value.absent(),
    this.showFindLetter = const Value.absent(),
  });
  ProfileCompanion.insert({
    this.id = const Value.absent(),
    required String nameEn,
    required String nameVi,
    required int dailyLimitMin,
    this.musicOn = const Value.absent(),
    this.testMode = const Value.absent(),
    this.showFindLetter = const Value.absent(),
  }) : nameEn = Value(nameEn),
       nameVi = Value(nameVi),
       dailyLimitMin = Value(dailyLimitMin);
  static Insertable<ProfileRow> custom({
    Expression<int>? id,
    Expression<String>? nameEn,
    Expression<String>? nameVi,
    Expression<int>? dailyLimitMin,
    Expression<bool>? musicOn,
    Expression<bool>? testMode,
    Expression<bool>? showFindLetter,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nameEn != null) 'name_en': nameEn,
      if (nameVi != null) 'name_vi': nameVi,
      if (dailyLimitMin != null) 'daily_limit_min': dailyLimitMin,
      if (musicOn != null) 'music_on': musicOn,
      if (testMode != null) 'test_mode': testMode,
      if (showFindLetter != null) 'show_find_letter': showFindLetter,
    });
  }

  ProfileCompanion copyWith({
    Value<int>? id,
    Value<String>? nameEn,
    Value<String>? nameVi,
    Value<int>? dailyLimitMin,
    Value<bool>? musicOn,
    Value<bool>? testMode,
    Value<bool>? showFindLetter,
  }) {
    return ProfileCompanion(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameVi: nameVi ?? this.nameVi,
      dailyLimitMin: dailyLimitMin ?? this.dailyLimitMin,
      musicOn: musicOn ?? this.musicOn,
      testMode: testMode ?? this.testMode,
      showFindLetter: showFindLetter ?? this.showFindLetter,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nameEn.present) {
      map['name_en'] = Variable<String>(nameEn.value);
    }
    if (nameVi.present) {
      map['name_vi'] = Variable<String>(nameVi.value);
    }
    if (dailyLimitMin.present) {
      map['daily_limit_min'] = Variable<int>(dailyLimitMin.value);
    }
    if (musicOn.present) {
      map['music_on'] = Variable<bool>(musicOn.value);
    }
    if (testMode.present) {
      map['test_mode'] = Variable<bool>(testMode.value);
    }
    if (showFindLetter.present) {
      map['show_find_letter'] = Variable<bool>(showFindLetter.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileCompanion(')
          ..write('id: $id, ')
          ..write('nameEn: $nameEn, ')
          ..write('nameVi: $nameVi, ')
          ..write('dailyLimitMin: $dailyLimitMin, ')
          ..write('musicOn: $musicOn, ')
          ..write('testMode: $testMode, ')
          ..write('showFindLetter: $showFindLetter')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ItemStatsTable itemStats = $ItemStatsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $RewardsTable rewards = $RewardsTable(this);
  late final $ProfileTable profile = $ProfileTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    itemStats,
    sessions,
    rewards,
    profile,
  ];
}

typedef $$ItemStatsTableCreateCompanionBuilder = ItemStatsCompanion Function({
  required String itemKey,
  Value<int> mastery,
  Value<int> correct,
  Value<int> wrong,
  Value<DateTime?> lastSeen,
  Value<int> rowid,
});
typedef $$ItemStatsTableUpdateCompanionBuilder = ItemStatsCompanion Function({
  Value<String> itemKey,
  Value<int> mastery,
  Value<int> correct,
  Value<int> wrong,
  Value<DateTime?> lastSeen,
  Value<int> rowid,
});

class $$ItemStatsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemStatsTable> {
  $$ItemStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mastery => $composableBuilder(
    column: $table.mastery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrong => $composableBuilder(
    column: $table.wrong,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemStatsTable> {
  $$ItemStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mastery => $composableBuilder(
    column: $table.mastery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrong => $composableBuilder(
    column: $table.wrong,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemStatsTable> {
  $$ItemStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemKey =>
      $composableBuilder(column: $table.itemKey, builder: (column) => column);

  GeneratedColumn<int> get mastery =>
      $composableBuilder(column: $table.mastery, builder: (column) => column);

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get wrong =>
      $composableBuilder(column: $table.wrong, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$ItemStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemStatsTable,
          ItemStatRow,
          $$ItemStatsTableFilterComposer,
          $$ItemStatsTableOrderingComposer,
          $$ItemStatsTableAnnotationComposer,
          $$ItemStatsTableCreateCompanionBuilder,
          $$ItemStatsTableUpdateCompanionBuilder,
          (
            ItemStatRow,
            BaseReferences<_$AppDatabase, $ItemStatsTable, ItemStatRow>,
          ),
          ItemStatRow,
          PrefetchHooks Function()
        > {
  $$ItemStatsTableTableManager(_$AppDatabase db, $ItemStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemKey = const Value.absent(),
                Value<int> mastery = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<int> wrong = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemStatsCompanion(
                itemKey: itemKey,
                mastery: mastery,
                correct: correct,
                wrong: wrong,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemKey,
                Value<int> mastery = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<int> wrong = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemStatsCompanion.insert(
                itemKey: itemKey,
                mastery: mastery,
                correct: correct,
                wrong: wrong,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemStatsTable, ItemStatRow>(table),
                  BaseReferences<_$AppDatabase, $ItemStatsTable, ItemStatRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemStatsTable,
      ItemStatRow,
      $$ItemStatsTableFilterComposer,
      $$ItemStatsTableOrderingComposer,
      $$ItemStatsTableAnnotationComposer,
      $$ItemStatsTableCreateCompanionBuilder,
      $$ItemStatsTableUpdateCompanionBuilder,
      (
        ItemStatRow,
        BaseReferences<_$AppDatabase, $ItemStatsTable, ItemStatRow>,
      ),
      ItemStatRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  required String date,
  required String game,
  required DateTime startedAt,
  required int durationSec,
  required int correct,
  required int total,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<String> date,
  Value<String> game,
  Value<DateTime> startedAt,
  Value<int> durationSec,
  Value<int> correct,
  Value<int> total,
});

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get game => $composableBuilder(
    column: $table.game,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get game => $composableBuilder(
    column: $table.game,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get game =>
      $composableBuilder(column: $table.game, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> game = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<int> total = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                date: date,
                game: game,
                startedAt: startedAt,
                durationSec: durationSec,
                correct: correct,
                total: total,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                required String game,
                required DateTime startedAt,
                required int durationSec,
                required int correct,
                required int total,
              }) => SessionsCompanion.insert(
                id: id,
                date: date,
                game: game,
                startedAt: startedAt,
                durationSec: durationSec,
                correct: correct,
                total: total,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$RewardsTableCreateCompanionBuilder = RewardsCompanion Function({
  Value<int> id,
  Value<int> snowflakesTotal,
  Value<int> castleLevel,
  Value<int> streakDays,
  Value<String?> lastPlayDate,
  Value<String?> dailyQuestDate,
  Value<int> dailyRoundsDone,
});
typedef $$RewardsTableUpdateCompanionBuilder = RewardsCompanion Function({
  Value<int> id,
  Value<int> snowflakesTotal,
  Value<int> castleLevel,
  Value<int> streakDays,
  Value<String?> lastPlayDate,
  Value<String?> dailyQuestDate,
  Value<int> dailyRoundsDone,
});

class $$RewardsTableFilterComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snowflakesTotal => $composableBuilder(
    column: $table.snowflakesTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get castleLevel => $composableBuilder(
    column: $table.castleLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastPlayDate => $composableBuilder(
    column: $table.lastPlayDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dailyQuestDate => $composableBuilder(
    column: $table.dailyQuestDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyRoundsDone => $composableBuilder(
    column: $table.dailyRoundsDone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RewardsTableOrderingComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snowflakesTotal => $composableBuilder(
    column: $table.snowflakesTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get castleLevel => $composableBuilder(
    column: $table.castleLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastPlayDate => $composableBuilder(
    column: $table.lastPlayDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dailyQuestDate => $composableBuilder(
    column: $table.dailyQuestDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyRoundsDone => $composableBuilder(
    column: $table.dailyRoundsDone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RewardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get snowflakesTotal => $composableBuilder(
    column: $table.snowflakesTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get castleLevel => $composableBuilder(
    column: $table.castleLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastPlayDate => $composableBuilder(
    column: $table.lastPlayDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dailyQuestDate => $composableBuilder(
    column: $table.dailyQuestDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyRoundsDone => $composableBuilder(
    column: $table.dailyRoundsDone,
    builder: (column) => column,
  );
}

class $$RewardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RewardsTable,
          RewardRow,
          $$RewardsTableFilterComposer,
          $$RewardsTableOrderingComposer,
          $$RewardsTableAnnotationComposer,
          $$RewardsTableCreateCompanionBuilder,
          $$RewardsTableUpdateCompanionBuilder,
          (RewardRow, BaseReferences<_$AppDatabase, $RewardsTable, RewardRow>),
          RewardRow,
          PrefetchHooks Function()
        > {
  $$RewardsTableTableManager(_$AppDatabase db, $RewardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RewardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RewardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RewardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> snowflakesTotal = const Value.absent(),
                Value<int> castleLevel = const Value.absent(),
                Value<int> streakDays = const Value.absent(),
                Value<String?> lastPlayDate = const Value.absent(),
                Value<String?> dailyQuestDate = const Value.absent(),
                Value<int> dailyRoundsDone = const Value.absent(),
              }) => RewardsCompanion(
                id: id,
                snowflakesTotal: snowflakesTotal,
                castleLevel: castleLevel,
                streakDays: streakDays,
                lastPlayDate: lastPlayDate,
                dailyQuestDate: dailyQuestDate,
                dailyRoundsDone: dailyRoundsDone,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> snowflakesTotal = const Value.absent(),
                Value<int> castleLevel = const Value.absent(),
                Value<int> streakDays = const Value.absent(),
                Value<String?> lastPlayDate = const Value.absent(),
                Value<String?> dailyQuestDate = const Value.absent(),
                Value<int> dailyRoundsDone = const Value.absent(),
              }) => RewardsCompanion.insert(
                id: id,
                snowflakesTotal: snowflakesTotal,
                castleLevel: castleLevel,
                streakDays: streakDays,
                lastPlayDate: lastPlayDate,
                dailyQuestDate: dailyQuestDate,
                dailyRoundsDone: dailyRoundsDone,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RewardsTable, RewardRow>(table),
                  BaseReferences<_$AppDatabase, $RewardsTable, RewardRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RewardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RewardsTable,
      RewardRow,
      $$RewardsTableFilterComposer,
      $$RewardsTableOrderingComposer,
      $$RewardsTableAnnotationComposer,
      $$RewardsTableCreateCompanionBuilder,
      $$RewardsTableUpdateCompanionBuilder,
      (RewardRow, BaseReferences<_$AppDatabase, $RewardsTable, RewardRow>),
      RewardRow,
      PrefetchHooks Function()
    >;
typedef $$ProfileTableCreateCompanionBuilder = ProfileCompanion Function({
  Value<int> id,
  required String nameEn,
  required String nameVi,
  required int dailyLimitMin,
  Value<bool> musicOn,
  Value<bool> testMode,
  Value<bool> showFindLetter,
});
typedef $$ProfileTableUpdateCompanionBuilder = ProfileCompanion Function({
  Value<int> id,
  Value<String> nameEn,
  Value<String> nameVi,
  Value<int> dailyLimitMin,
  Value<bool> musicOn,
  Value<bool> testMode,
  Value<bool> showFindLetter,
});

class $$ProfileTableFilterComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameVi => $composableBuilder(
    column: $table.nameVi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyLimitMin => $composableBuilder(
    column: $table.dailyLimitMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get musicOn => $composableBuilder(
    column: $table.musicOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get testMode => $composableBuilder(
    column: $table.testMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showFindLetter => $composableBuilder(
    column: $table.showFindLetter,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameVi => $composableBuilder(
    column: $table.nameVi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyLimitMin => $composableBuilder(
    column: $table.dailyLimitMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get musicOn => $composableBuilder(
    column: $table.musicOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get testMode => $composableBuilder(
    column: $table.testMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showFindLetter => $composableBuilder(
    column: $table.showFindLetter,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nameEn =>
      $composableBuilder(column: $table.nameEn, builder: (column) => column);

  GeneratedColumn<String> get nameVi =>
      $composableBuilder(column: $table.nameVi, builder: (column) => column);

  GeneratedColumn<int> get dailyLimitMin => $composableBuilder(
    column: $table.dailyLimitMin,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get musicOn =>
      $composableBuilder(column: $table.musicOn, builder: (column) => column);

  GeneratedColumn<bool> get testMode =>
      $composableBuilder(column: $table.testMode, builder: (column) => column);

  GeneratedColumn<bool> get showFindLetter => $composableBuilder(
    column: $table.showFindLetter,
    builder: (column) => column,
  );
}

class $$ProfileTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfileTable,
          ProfileRow,
          $$ProfileTableFilterComposer,
          $$ProfileTableOrderingComposer,
          $$ProfileTableAnnotationComposer,
          $$ProfileTableCreateCompanionBuilder,
          $$ProfileTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<_$AppDatabase, $ProfileTable, ProfileRow>,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfileTableTableManager(_$AppDatabase db, $ProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nameEn = const Value.absent(),
                Value<String> nameVi = const Value.absent(),
                Value<int> dailyLimitMin = const Value.absent(),
                Value<bool> musicOn = const Value.absent(),
                Value<bool> testMode = const Value.absent(),
                Value<bool> showFindLetter = const Value.absent(),
              }) => ProfileCompanion(
                id: id,
                nameEn: nameEn,
                nameVi: nameVi,
                dailyLimitMin: dailyLimitMin,
                musicOn: musicOn,
                testMode: testMode,
                showFindLetter: showFindLetter,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nameEn,
                required String nameVi,
                required int dailyLimitMin,
                Value<bool> musicOn = const Value.absent(),
                Value<bool> testMode = const Value.absent(),
                Value<bool> showFindLetter = const Value.absent(),
              }) => ProfileCompanion.insert(
                id: id,
                nameEn: nameEn,
                nameVi: nameVi,
                dailyLimitMin: dailyLimitMin,
                musicOn: musicOn,
                testMode: testMode,
                showFindLetter: showFindLetter,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfileTable, ProfileRow>(table),
                  BaseReferences<_$AppDatabase, $ProfileTable, ProfileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfileTable,
      ProfileRow,
      $$ProfileTableFilterComposer,
      $$ProfileTableOrderingComposer,
      $$ProfileTableAnnotationComposer,
      $$ProfileTableCreateCompanionBuilder,
      $$ProfileTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$AppDatabase, $ProfileTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ItemStatsTableTableManager get itemStats =>
      $$ItemStatsTableTableManager(_db, _db.itemStats);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$RewardsTableTableManager get rewards =>
      $$RewardsTableTableManager(_db, _db.rewards);
  $$ProfileTableTableManager get profile =>
      $$ProfileTableTableManager(_db, _db.profile);
}
