// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ia_database.dart';

// ignore_for_file: type=lint
class $RepositoryRootsTable extends RepositoryRoots
    with TableInfo<$RepositoryRootsTable, RepositoryRoot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepositoryRootsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RepositoryMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RepositoryMode>($RepositoryRootsTable.$convertermode);
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, label, mode, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repository_roots';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepositoryRoot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepositoryRoot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepositoryRoot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      mode: $RepositoryRootsTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $RepositoryRootsTable createAlias(String alias) {
    return $RepositoryRootsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RepositoryMode, String, String> $convertermode =
      const EnumNameConverter<RepositoryMode>(RepositoryMode.values);
}

class RepositoryRoot extends DataClass implements Insertable<RepositoryRoot> {
  final int id;
  final String path;
  final String? label;
  final RepositoryMode mode;
  final int addedAt;
  const RepositoryRoot({
    required this.id,
    required this.path,
    this.label,
    required this.mode,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    {
      map['mode'] = Variable<String>(
        $RepositoryRootsTable.$convertermode.toSql(mode),
      );
    }
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  RepositoryRootsCompanion toCompanion(bool nullToAbsent) {
    return RepositoryRootsCompanion(
      id: Value(id),
      path: Value(path),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      mode: Value(mode),
      addedAt: Value(addedAt),
    );
  }

  factory RepositoryRoot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepositoryRoot(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      label: serializer.fromJson<String?>(json['label']),
      mode: $RepositoryRootsTable.$convertermode.fromJson(
        serializer.fromJson<String>(json['mode']),
      ),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'label': serializer.toJson<String?>(label),
      'mode': serializer.toJson<String>(
        $RepositoryRootsTable.$convertermode.toJson(mode),
      ),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  RepositoryRoot copyWith({
    int? id,
    String? path,
    Value<String?> label = const Value.absent(),
    RepositoryMode? mode,
    int? addedAt,
  }) => RepositoryRoot(
    id: id ?? this.id,
    path: path ?? this.path,
    label: label.present ? label.value : this.label,
    mode: mode ?? this.mode,
    addedAt: addedAt ?? this.addedAt,
  );
  RepositoryRoot copyWithCompanion(RepositoryRootsCompanion data) {
    return RepositoryRoot(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      label: data.label.present ? data.label.value : this.label,
      mode: data.mode.present ? data.mode.value : this.mode,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepositoryRoot(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('label: $label, ')
          ..write('mode: $mode, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, label, mode, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepositoryRoot &&
          other.id == this.id &&
          other.path == this.path &&
          other.label == this.label &&
          other.mode == this.mode &&
          other.addedAt == this.addedAt);
}

class RepositoryRootsCompanion extends UpdateCompanion<RepositoryRoot> {
  final Value<int> id;
  final Value<String> path;
  final Value<String?> label;
  final Value<RepositoryMode> mode;
  final Value<int> addedAt;
  const RepositoryRootsCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.label = const Value.absent(),
    this.mode = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  RepositoryRootsCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    this.label = const Value.absent(),
    required RepositoryMode mode,
    required int addedAt,
  }) : path = Value(path),
       mode = Value(mode),
       addedAt = Value(addedAt);
  static Insertable<RepositoryRoot> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? label,
    Expression<String>? mode,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (label != null) 'label': label,
      if (mode != null) 'mode': mode,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  RepositoryRootsCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String?>? label,
    Value<RepositoryMode>? mode,
    Value<int>? addedAt,
  }) {
    return RepositoryRootsCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      label: label ?? this.label,
      mode: mode ?? this.mode,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $RepositoryRootsTable.$convertermode.toSql(mode.value),
      );
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepositoryRootsCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('label: $label, ')
          ..write('mode: $mode, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $ArtistsTable extends Artists with TableInfo<$ArtistsTable, Artist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameNormMeta = const VerificationMeta(
    'nameNorm',
  );
  @override
  late final GeneratedColumn<String> nameNorm = GeneratedColumn<String>(
    'name_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameNorm,
    sortKey,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Artist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_norm')) {
      context.handle(
        _nameNormMeta,
        nameNorm.isAcceptableOrUnknown(data['name_norm']!, _nameNormMeta),
      );
    } else if (isInserting) {
      context.missing(_nameNormMeta);
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Artist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Artist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_norm'],
      )!,
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ArtistsTable createAlias(String alias) {
    return $ArtistsTable(attachedDatabase, alias);
  }
}

class Artist extends DataClass implements Insertable<Artist> {
  final int id;
  final String name;
  final String nameNorm;
  final String? sortKey;
  final int updatedAt;
  const Artist({
    required this.id,
    required this.name,
    required this.nameNorm,
    this.sortKey,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['name_norm'] = Variable<String>(nameNorm);
    if (!nullToAbsent || sortKey != null) {
      map['sort_key'] = Variable<String>(sortKey);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ArtistsCompanion toCompanion(bool nullToAbsent) {
    return ArtistsCompanion(
      id: Value(id),
      name: Value(name),
      nameNorm: Value(nameNorm),
      sortKey: sortKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sortKey),
      updatedAt: Value(updatedAt),
    );
  }

  factory Artist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Artist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameNorm: serializer.fromJson<String>(json['nameNorm']),
      sortKey: serializer.fromJson<String?>(json['sortKey']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'nameNorm': serializer.toJson<String>(nameNorm),
      'sortKey': serializer.toJson<String?>(sortKey),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Artist copyWith({
    int? id,
    String? name,
    String? nameNorm,
    Value<String?> sortKey = const Value.absent(),
    int? updatedAt,
  }) => Artist(
    id: id ?? this.id,
    name: name ?? this.name,
    nameNorm: nameNorm ?? this.nameNorm,
    sortKey: sortKey.present ? sortKey.value : this.sortKey,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Artist copyWithCompanion(ArtistsCompanion data) {
    return Artist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameNorm: data.nameNorm.present ? data.nameNorm.value : this.nameNorm,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Artist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNorm: $nameNorm, ')
          ..write('sortKey: $sortKey, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, nameNorm, sortKey, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Artist &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameNorm == this.nameNorm &&
          other.sortKey == this.sortKey &&
          other.updatedAt == this.updatedAt);
}

class ArtistsCompanion extends UpdateCompanion<Artist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> nameNorm;
  final Value<String?> sortKey;
  final Value<int> updatedAt;
  const ArtistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameNorm = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ArtistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String nameNorm,
    this.sortKey = const Value.absent(),
    required int updatedAt,
  }) : name = Value(name),
       nameNorm = Value(nameNorm),
       updatedAt = Value(updatedAt);
  static Insertable<Artist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? nameNorm,
    Expression<String>? sortKey,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameNorm != null) 'name_norm': nameNorm,
      if (sortKey != null) 'sort_key': sortKey,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ArtistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? nameNorm,
    Value<String?>? sortKey,
    Value<int>? updatedAt,
  }) {
    return ArtistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameNorm: nameNorm ?? this.nameNorm,
      sortKey: sortKey ?? this.sortKey,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameNorm.present) {
      map['name_norm'] = Variable<String>(nameNorm.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNorm: $nameNorm, ')
          ..write('sortKey: $sortKey, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTable extends Albums with TableInfo<$AlbumsTable, Album> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameNormMeta = const VerificationMeta(
    'nameNorm',
  );
  @override
  late final GeneratedColumn<String> nameNorm = GeneratedColumn<String>(
    'name_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameNorm,
    sortKey,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<Album> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_norm')) {
      context.handle(
        _nameNormMeta,
        nameNorm.isAcceptableOrUnknown(data['name_norm']!, _nameNormMeta),
      );
    } else if (isInserting) {
      context.missing(_nameNormMeta);
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Album map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Album(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_norm'],
      )!,
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AlbumsTable createAlias(String alias) {
    return $AlbumsTable(attachedDatabase, alias);
  }
}

class Album extends DataClass implements Insertable<Album> {
  final int id;
  final String name;
  final String nameNorm;
  final String? sortKey;
  final int updatedAt;
  const Album({
    required this.id,
    required this.name,
    required this.nameNorm,
    this.sortKey,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['name_norm'] = Variable<String>(nameNorm);
    if (!nullToAbsent || sortKey != null) {
      map['sort_key'] = Variable<String>(sortKey);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AlbumsCompanion toCompanion(bool nullToAbsent) {
    return AlbumsCompanion(
      id: Value(id),
      name: Value(name),
      nameNorm: Value(nameNorm),
      sortKey: sortKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sortKey),
      updatedAt: Value(updatedAt),
    );
  }

  factory Album.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Album(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameNorm: serializer.fromJson<String>(json['nameNorm']),
      sortKey: serializer.fromJson<String?>(json['sortKey']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'nameNorm': serializer.toJson<String>(nameNorm),
      'sortKey': serializer.toJson<String?>(sortKey),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Album copyWith({
    int? id,
    String? name,
    String? nameNorm,
    Value<String?> sortKey = const Value.absent(),
    int? updatedAt,
  }) => Album(
    id: id ?? this.id,
    name: name ?? this.name,
    nameNorm: nameNorm ?? this.nameNorm,
    sortKey: sortKey.present ? sortKey.value : this.sortKey,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Album copyWithCompanion(AlbumsCompanion data) {
    return Album(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameNorm: data.nameNorm.present ? data.nameNorm.value : this.nameNorm,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Album(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNorm: $nameNorm, ')
          ..write('sortKey: $sortKey, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, nameNorm, sortKey, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Album &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameNorm == this.nameNorm &&
          other.sortKey == this.sortKey &&
          other.updatedAt == this.updatedAt);
}

class AlbumsCompanion extends UpdateCompanion<Album> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> nameNorm;
  final Value<String?> sortKey;
  final Value<int> updatedAt;
  const AlbumsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameNorm = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AlbumsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String nameNorm,
    this.sortKey = const Value.absent(),
    required int updatedAt,
  }) : name = Value(name),
       nameNorm = Value(nameNorm),
       updatedAt = Value(updatedAt);
  static Insertable<Album> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? nameNorm,
    Expression<String>? sortKey,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameNorm != null) 'name_norm': nameNorm,
      if (sortKey != null) 'sort_key': sortKey,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AlbumsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? nameNorm,
    Value<String?>? sortKey,
    Value<int>? updatedAt,
  }) {
    return AlbumsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameNorm: nameNorm ?? this.nameNorm,
      sortKey: sortKey ?? this.sortKey,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameNorm.present) {
      map['name_norm'] = Variable<String>(nameNorm.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNorm: $nameNorm, ')
          ..write('sortKey: $sortKey, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, Track> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _rootIdMeta = const VerificationMeta('rootId');
  @override
  late final GeneratedColumn<int> rootId = GeneratedColumn<int>(
    'root_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repository_roots (id)',
    ),
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistDisplayMeta = const VerificationMeta(
    'artistDisplay',
  );
  @override
  late final GeneratedColumn<String> artistDisplay = GeneratedColumn<String>(
    'artist_display',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumDisplayMeta = const VerificationMeta(
    'albumDisplay',
  );
  @override
  late final GeneratedColumn<String> albumDisplay = GeneratedColumn<String>(
    'album_display',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<int> artistId = GeneratedColumn<int>(
    'artist_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id)',
    ),
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<int> albumId = GeneratedColumn<int>(
    'album_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES albums (id)',
    ),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AudioFormatSpec, String>
  audioFormat = GeneratedColumn<String>(
    'audio_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<AudioFormatSpec>($TracksTable.$converteraudioFormat);
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelsMeta = const VerificationMeta(
    'channels',
  );
  @override
  late final GeneratedColumn<int> channels = GeneratedColumn<int>(
    'channels',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missingAtMeta = const VerificationMeta(
    'missingAt',
  );
  @override
  late final GeneratedColumn<int> missingAt = GeneratedColumn<int>(
    'missing_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rootId,
    relPath,
    title,
    artistDisplay,
    albumDisplay,
    artistId,
    albumId,
    durationMs,
    audioFormat,
    fileSize,
    mtime,
    contentHash,
    sourceType,
    sourceId,
    sampleRate,
    channels,
    addedAt,
    updatedAt,
    deletedAt,
    missingAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Track> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('root_id')) {
      context.handle(
        _rootIdMeta,
        rootId.isAcceptableOrUnknown(data['root_id']!, _rootIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rootIdMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('artist_display')) {
      context.handle(
        _artistDisplayMeta,
        artistDisplay.isAcceptableOrUnknown(
          data['artist_display']!,
          _artistDisplayMeta,
        ),
      );
    }
    if (data.containsKey('album_display')) {
      context.handle(
        _albumDisplayMeta,
        albumDisplay.isAcceptableOrUnknown(
          data['album_display']!,
          _albumDisplayMeta,
        ),
      );
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('channels')) {
      context.handle(
        _channelsMeta,
        channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('missing_at')) {
      context.handle(
        _missingAtMeta,
        missingAt.isAcceptableOrUnknown(data['missing_at']!, _missingAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {rootId, relPath},
  ];
  @override
  Track map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Track(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rootId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}root_id'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      artistDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_display'],
      ),
      albumDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_display'],
      ),
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}artist_id'],
      ),
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}album_id'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      audioFormat: $TracksTable.$converteraudioFormat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}audio_format'],
        )!,
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      channels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channels'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      missingAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}missing_at'],
      ),
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AudioFormatSpec, String, String>
  $converteraudioFormat = const EnumNameConverter<AudioFormatSpec>(
    AudioFormatSpec.values,
  );
}

class Track extends DataClass implements Insertable<Track> {
  final int id;
  final int rootId;
  final String relPath;

  /// 标签缺失时由扫描以文件名兜底填充（可空→扫描层保证非空值写入）。
  final String? title;
  final String? artistDisplay;
  final String? albumDisplay;
  final int? artistId;
  final int? albumId;

  /// 内容中位值（多来源时长统计后填充；未确定前可空）。
  final int? durationMs;
  final AudioFormatSpec audioFormat;
  final int fileSize;
  final int mtime;

  /// 入库时计算（范围=音频帧）；同步比对用。
  final String contentHash;
  final String? sourceType;
  final String? sourceId;
  final int? sampleRate;
  final int? channels;
  final int addedAt;
  final int updatedAt;
  final int? deletedAt;
  final int? missingAt;
  const Track({
    required this.id,
    required this.rootId,
    required this.relPath,
    this.title,
    this.artistDisplay,
    this.albumDisplay,
    this.artistId,
    this.albumId,
    this.durationMs,
    required this.audioFormat,
    required this.fileSize,
    required this.mtime,
    required this.contentHash,
    this.sourceType,
    this.sourceId,
    this.sampleRate,
    this.channels,
    required this.addedAt,
    required this.updatedAt,
    this.deletedAt,
    this.missingAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['root_id'] = Variable<int>(rootId);
    map['rel_path'] = Variable<String>(relPath);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || artistDisplay != null) {
      map['artist_display'] = Variable<String>(artistDisplay);
    }
    if (!nullToAbsent || albumDisplay != null) {
      map['album_display'] = Variable<String>(albumDisplay);
    }
    if (!nullToAbsent || artistId != null) {
      map['artist_id'] = Variable<int>(artistId);
    }
    if (!nullToAbsent || albumId != null) {
      map['album_id'] = Variable<int>(albumId);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    {
      map['audio_format'] = Variable<String>(
        $TracksTable.$converteraudioFormat.toSql(audioFormat),
      );
    }
    map['file_size'] = Variable<int>(fileSize);
    map['mtime'] = Variable<int>(mtime);
    map['content_hash'] = Variable<String>(contentHash);
    if (!nullToAbsent || sourceType != null) {
      map['source_type'] = Variable<String>(sourceType);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || channels != null) {
      map['channels'] = Variable<int>(channels);
    }
    map['added_at'] = Variable<int>(addedAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    if (!nullToAbsent || missingAt != null) {
      map['missing_at'] = Variable<int>(missingAt);
    }
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      rootId: Value(rootId),
      relPath: Value(relPath),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      artistDisplay: artistDisplay == null && nullToAbsent
          ? const Value.absent()
          : Value(artistDisplay),
      albumDisplay: albumDisplay == null && nullToAbsent
          ? const Value.absent()
          : Value(albumDisplay),
      artistId: artistId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistId),
      albumId: albumId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumId),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      audioFormat: Value(audioFormat),
      fileSize: Value(fileSize),
      mtime: Value(mtime),
      contentHash: Value(contentHash),
      sourceType: sourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceType),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      channels: channels == null && nullToAbsent
          ? const Value.absent()
          : Value(channels),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      missingAt: missingAt == null && nullToAbsent
          ? const Value.absent()
          : Value(missingAt),
    );
  }

  factory Track.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Track(
      id: serializer.fromJson<int>(json['id']),
      rootId: serializer.fromJson<int>(json['rootId']),
      relPath: serializer.fromJson<String>(json['relPath']),
      title: serializer.fromJson<String?>(json['title']),
      artistDisplay: serializer.fromJson<String?>(json['artistDisplay']),
      albumDisplay: serializer.fromJson<String?>(json['albumDisplay']),
      artistId: serializer.fromJson<int?>(json['artistId']),
      albumId: serializer.fromJson<int?>(json['albumId']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      audioFormat: $TracksTable.$converteraudioFormat.fromJson(
        serializer.fromJson<String>(json['audioFormat']),
      ),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      mtime: serializer.fromJson<int>(json['mtime']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      sourceType: serializer.fromJson<String?>(json['sourceType']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      channels: serializer.fromJson<int?>(json['channels']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      missingAt: serializer.fromJson<int?>(json['missingAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rootId': serializer.toJson<int>(rootId),
      'relPath': serializer.toJson<String>(relPath),
      'title': serializer.toJson<String?>(title),
      'artistDisplay': serializer.toJson<String?>(artistDisplay),
      'albumDisplay': serializer.toJson<String?>(albumDisplay),
      'artistId': serializer.toJson<int?>(artistId),
      'albumId': serializer.toJson<int?>(albumId),
      'durationMs': serializer.toJson<int?>(durationMs),
      'audioFormat': serializer.toJson<String>(
        $TracksTable.$converteraudioFormat.toJson(audioFormat),
      ),
      'fileSize': serializer.toJson<int>(fileSize),
      'mtime': serializer.toJson<int>(mtime),
      'contentHash': serializer.toJson<String>(contentHash),
      'sourceType': serializer.toJson<String?>(sourceType),
      'sourceId': serializer.toJson<String?>(sourceId),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'channels': serializer.toJson<int?>(channels),
      'addedAt': serializer.toJson<int>(addedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'missingAt': serializer.toJson<int?>(missingAt),
    };
  }

  Track copyWith({
    int? id,
    int? rootId,
    String? relPath,
    Value<String?> title = const Value.absent(),
    Value<String?> artistDisplay = const Value.absent(),
    Value<String?> albumDisplay = const Value.absent(),
    Value<int?> artistId = const Value.absent(),
    Value<int?> albumId = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    AudioFormatSpec? audioFormat,
    int? fileSize,
    int? mtime,
    String? contentHash,
    Value<String?> sourceType = const Value.absent(),
    Value<String?> sourceId = const Value.absent(),
    Value<int?> sampleRate = const Value.absent(),
    Value<int?> channels = const Value.absent(),
    int? addedAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    Value<int?> missingAt = const Value.absent(),
  }) => Track(
    id: id ?? this.id,
    rootId: rootId ?? this.rootId,
    relPath: relPath ?? this.relPath,
    title: title.present ? title.value : this.title,
    artistDisplay: artistDisplay.present
        ? artistDisplay.value
        : this.artistDisplay,
    albumDisplay: albumDisplay.present ? albumDisplay.value : this.albumDisplay,
    artistId: artistId.present ? artistId.value : this.artistId,
    albumId: albumId.present ? albumId.value : this.albumId,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    audioFormat: audioFormat ?? this.audioFormat,
    fileSize: fileSize ?? this.fileSize,
    mtime: mtime ?? this.mtime,
    contentHash: contentHash ?? this.contentHash,
    sourceType: sourceType.present ? sourceType.value : this.sourceType,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    channels: channels.present ? channels.value : this.channels,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    missingAt: missingAt.present ? missingAt.value : this.missingAt,
  );
  Track copyWithCompanion(TracksCompanion data) {
    return Track(
      id: data.id.present ? data.id.value : this.id,
      rootId: data.rootId.present ? data.rootId.value : this.rootId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      title: data.title.present ? data.title.value : this.title,
      artistDisplay: data.artistDisplay.present
          ? data.artistDisplay.value
          : this.artistDisplay,
      albumDisplay: data.albumDisplay.present
          ? data.albumDisplay.value
          : this.albumDisplay,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      audioFormat: data.audioFormat.present
          ? data.audioFormat.value
          : this.audioFormat,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      channels: data.channels.present ? data.channels.value : this.channels,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      missingAt: data.missingAt.present ? data.missingAt.value : this.missingAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Track(')
          ..write('id: $id, ')
          ..write('rootId: $rootId, ')
          ..write('relPath: $relPath, ')
          ..write('title: $title, ')
          ..write('artistDisplay: $artistDisplay, ')
          ..write('albumDisplay: $albumDisplay, ')
          ..write('artistId: $artistId, ')
          ..write('albumId: $albumId, ')
          ..write('durationMs: $durationMs, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('fileSize: $fileSize, ')
          ..write('mtime: $mtime, ')
          ..write('contentHash: $contentHash, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('channels: $channels, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('missingAt: $missingAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    rootId,
    relPath,
    title,
    artistDisplay,
    albumDisplay,
    artistId,
    albumId,
    durationMs,
    audioFormat,
    fileSize,
    mtime,
    contentHash,
    sourceType,
    sourceId,
    sampleRate,
    channels,
    addedAt,
    updatedAt,
    deletedAt,
    missingAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.id == this.id &&
          other.rootId == this.rootId &&
          other.relPath == this.relPath &&
          other.title == this.title &&
          other.artistDisplay == this.artistDisplay &&
          other.albumDisplay == this.albumDisplay &&
          other.artistId == this.artistId &&
          other.albumId == this.albumId &&
          other.durationMs == this.durationMs &&
          other.audioFormat == this.audioFormat &&
          other.fileSize == this.fileSize &&
          other.mtime == this.mtime &&
          other.contentHash == this.contentHash &&
          other.sourceType == this.sourceType &&
          other.sourceId == this.sourceId &&
          other.sampleRate == this.sampleRate &&
          other.channels == this.channels &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.missingAt == this.missingAt);
}

class TracksCompanion extends UpdateCompanion<Track> {
  final Value<int> id;
  final Value<int> rootId;
  final Value<String> relPath;
  final Value<String?> title;
  final Value<String?> artistDisplay;
  final Value<String?> albumDisplay;
  final Value<int?> artistId;
  final Value<int?> albumId;
  final Value<int?> durationMs;
  final Value<AudioFormatSpec> audioFormat;
  final Value<int> fileSize;
  final Value<int> mtime;
  final Value<String> contentHash;
  final Value<String?> sourceType;
  final Value<String?> sourceId;
  final Value<int?> sampleRate;
  final Value<int?> channels;
  final Value<int> addedAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int?> missingAt;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.rootId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.title = const Value.absent(),
    this.artistDisplay = const Value.absent(),
    this.albumDisplay = const Value.absent(),
    this.artistId = const Value.absent(),
    this.albumId = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.mtime = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.channels = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.missingAt = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required int rootId,
    required String relPath,
    this.title = const Value.absent(),
    this.artistDisplay = const Value.absent(),
    this.albumDisplay = const Value.absent(),
    this.artistId = const Value.absent(),
    this.albumId = const Value.absent(),
    this.durationMs = const Value.absent(),
    required AudioFormatSpec audioFormat,
    required int fileSize,
    required int mtime,
    required String contentHash,
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.channels = const Value.absent(),
    required int addedAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.missingAt = const Value.absent(),
  }) : rootId = Value(rootId),
       relPath = Value(relPath),
       audioFormat = Value(audioFormat),
       fileSize = Value(fileSize),
       mtime = Value(mtime),
       contentHash = Value(contentHash),
       addedAt = Value(addedAt),
       updatedAt = Value(updatedAt);
  static Insertable<Track> custom({
    Expression<int>? id,
    Expression<int>? rootId,
    Expression<String>? relPath,
    Expression<String>? title,
    Expression<String>? artistDisplay,
    Expression<String>? albumDisplay,
    Expression<int>? artistId,
    Expression<int>? albumId,
    Expression<int>? durationMs,
    Expression<String>? audioFormat,
    Expression<int>? fileSize,
    Expression<int>? mtime,
    Expression<String>? contentHash,
    Expression<String>? sourceType,
    Expression<String>? sourceId,
    Expression<int>? sampleRate,
    Expression<int>? channels,
    Expression<int>? addedAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? missingAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rootId != null) 'root_id': rootId,
      if (relPath != null) 'rel_path': relPath,
      if (title != null) 'title': title,
      if (artistDisplay != null) 'artist_display': artistDisplay,
      if (albumDisplay != null) 'album_display': albumDisplay,
      if (artistId != null) 'artist_id': artistId,
      if (albumId != null) 'album_id': albumId,
      if (durationMs != null) 'duration_ms': durationMs,
      if (audioFormat != null) 'audio_format': audioFormat,
      if (fileSize != null) 'file_size': fileSize,
      if (mtime != null) 'mtime': mtime,
      if (contentHash != null) 'content_hash': contentHash,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (channels != null) 'channels': channels,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (missingAt != null) 'missing_at': missingAt,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<int>? rootId,
    Value<String>? relPath,
    Value<String?>? title,
    Value<String?>? artistDisplay,
    Value<String?>? albumDisplay,
    Value<int?>? artistId,
    Value<int?>? albumId,
    Value<int?>? durationMs,
    Value<AudioFormatSpec>? audioFormat,
    Value<int>? fileSize,
    Value<int>? mtime,
    Value<String>? contentHash,
    Value<String?>? sourceType,
    Value<String?>? sourceId,
    Value<int?>? sampleRate,
    Value<int?>? channels,
    Value<int>? addedAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int?>? missingAt,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      rootId: rootId ?? this.rootId,
      relPath: relPath ?? this.relPath,
      title: title ?? this.title,
      artistDisplay: artistDisplay ?? this.artistDisplay,
      albumDisplay: albumDisplay ?? this.albumDisplay,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      durationMs: durationMs ?? this.durationMs,
      audioFormat: audioFormat ?? this.audioFormat,
      fileSize: fileSize ?? this.fileSize,
      mtime: mtime ?? this.mtime,
      contentHash: contentHash ?? this.contentHash,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      missingAt: missingAt ?? this.missingAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rootId.present) {
      map['root_id'] = Variable<int>(rootId.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistDisplay.present) {
      map['artist_display'] = Variable<String>(artistDisplay.value);
    }
    if (albumDisplay.present) {
      map['album_display'] = Variable<String>(albumDisplay.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<int>(artistId.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<int>(albumId.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (audioFormat.present) {
      map['audio_format'] = Variable<String>(
        $TracksTable.$converteraudioFormat.toSql(audioFormat.value),
      );
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (channels.present) {
      map['channels'] = Variable<int>(channels.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (missingAt.present) {
      map['missing_at'] = Variable<int>(missingAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('rootId: $rootId, ')
          ..write('relPath: $relPath, ')
          ..write('title: $title, ')
          ..write('artistDisplay: $artistDisplay, ')
          ..write('albumDisplay: $albumDisplay, ')
          ..write('artistId: $artistId, ')
          ..write('albumId: $albumId, ')
          ..write('durationMs: $durationMs, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('fileSize: $fileSize, ')
          ..write('mtime: $mtime, ')
          ..write('contentHash: $contentHash, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('channels: $channels, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('missingAt: $missingAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlaylistKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PlaylistKind>($PlaylistsTable.$converterkind);
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $PlaylistsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PlaylistKind, String, String> $converterkind =
      const EnumNameConverter<PlaylistKind>(PlaylistKind.values);
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;
  final PlaylistKind kind;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const Playlist({
    required this.id,
    required this.name,
    required this.kind,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>(
        $PlaylistsTable.$converterkind.toSql(kind),
      );
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: $PlaylistsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(
        $PlaylistsTable.$converterkind.toJson(kind),
      ),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Playlist copyWith({
    int? id,
    String? name,
    PlaylistKind? kind,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, kind, sortOrder, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<PlaylistKind> kind;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required PlaylistKind kind,
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
  }) : name = Value(name),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<PlaylistKind>? kind,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $PlaylistsTable.$converterkind.toSql(kind.value),
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTable extends PlaylistTracks
    with TableInfo<$PlaylistTracksTable, PlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    trackId,
    position,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, trackId},
  ];
  @override
  PlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistTrack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $PlaylistTracksTable createAlias(String alias) {
    return $PlaylistTracksTable(attachedDatabase, alias);
  }
}

class PlaylistTrack extends DataClass implements Insertable<PlaylistTrack> {
  final int id;
  final int playlistId;
  final int trackId;
  final int position;
  final int addedAt;
  const PlaylistTrack({
    required this.id,
    required this.playlistId,
    required this.trackId,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['track_id'] = Variable<int>(trackId);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  PlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory PlaylistTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistTrack(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      trackId: serializer.fromJson<int>(json['trackId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'trackId': serializer.toJson<int>(trackId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  PlaylistTrack copyWith({
    int? id,
    int? playlistId,
    int? trackId,
    int? position,
    int? addedAt,
  }) => PlaylistTrack(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    trackId: trackId ?? this.trackId,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  PlaylistTrack copyWithCompanion(PlaylistTracksCompanion data) {
    return PlaylistTrack(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTrack(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, playlistId, trackId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistTrack &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class PlaylistTracksCompanion extends UpdateCompanion<PlaylistTrack> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<int> trackId;
  final Value<int> position;
  final Value<int> addedAt;
  const PlaylistTracksCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  PlaylistTracksCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required int trackId,
    required int position,
    required int addedAt,
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId),
       position = Value(position),
       addedAt = Value(addedAt);
  static Insertable<PlaylistTrack> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<int>? trackId,
    Expression<int>? position,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  PlaylistTracksCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<int>? trackId,
    Value<int>? position,
    Value<int>? addedAt,
  }) {
    return PlaylistTracksCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoryTable extends PlayHistory
    with TableInfo<$PlayHistoryTable, PlayHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id)',
    ),
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    playedAt,
    completed,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    } else if (isInserting) {
      context.missing(_completedMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}played_at'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $PlayHistoryTable createAlias(String alias) {
    return $PlayHistoryTable(attachedDatabase, alias);
  }
}

class PlayHistoryData extends DataClass implements Insertable<PlayHistoryData> {
  final int id;
  final int trackId;
  final int playedAt;
  final bool completed;
  final String deviceId;
  const PlayHistoryData({
    required this.id,
    required this.trackId,
    required this.playedAt,
    required this.completed,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['played_at'] = Variable<int>(playedAt);
    map['completed'] = Variable<bool>(completed);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  PlayHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoryCompanion(
      id: Value(id),
      trackId: Value(trackId),
      playedAt: Value(playedAt),
      completed: Value(completed),
      deviceId: Value(deviceId),
    );
  }

  factory PlayHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistoryData(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      playedAt: serializer.fromJson<int>(json['playedAt']),
      completed: serializer.fromJson<bool>(json['completed']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'playedAt': serializer.toJson<int>(playedAt),
      'completed': serializer.toJson<bool>(completed),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  PlayHistoryData copyWith({
    int? id,
    int? trackId,
    int? playedAt,
    bool? completed,
    String? deviceId,
  }) => PlayHistoryData(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    playedAt: playedAt ?? this.playedAt,
    completed: completed ?? this.completed,
    deviceId: deviceId ?? this.deviceId,
  );
  PlayHistoryData copyWithCompanion(PlayHistoryCompanion data) {
    return PlayHistoryData(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      completed: data.completed.present ? data.completed.value : this.completed,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryData(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('completed: $completed, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackId, playedAt, completed, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryData &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.playedAt == this.playedAt &&
          other.completed == this.completed &&
          other.deviceId == this.deviceId);
}

class PlayHistoryCompanion extends UpdateCompanion<PlayHistoryData> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<int> playedAt;
  final Value<bool> completed;
  final Value<String> deviceId;
  const PlayHistoryCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.completed = const Value.absent(),
    this.deviceId = const Value.absent(),
  });
  PlayHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    required int playedAt,
    required bool completed,
    required String deviceId,
  }) : trackId = Value(trackId),
       playedAt = Value(playedAt),
       completed = Value(completed),
       deviceId = Value(deviceId);
  static Insertable<PlayHistoryData> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<int>? playedAt,
    Expression<bool>? completed,
    Expression<String>? deviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (playedAt != null) 'played_at': playedAt,
      if (completed != null) 'completed': completed,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  PlayHistoryCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<int>? playedAt,
    Value<bool>? completed,
    Value<String>? deviceId,
  }) {
    return PlayHistoryCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      playedAt: playedAt ?? this.playedAt,
      completed: completed ?? this.completed,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('completed: $completed, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }
}

class $FewWatchListTable extends FewWatchList
    with TableInfo<$FewWatchListTable, FewWatchListData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FewWatchListTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id)',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'few_watch_list';
  @override
  VerificationContext validateIntegrity(
    Insertable<FewWatchListData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  FewWatchListData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FewWatchListData(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FewWatchListTable createAlias(String alias) {
    return $FewWatchListTable(attachedDatabase, alias);
  }
}

class FewWatchListData extends DataClass
    implements Insertable<FewWatchListData> {
  final int trackId;
  final int addedAt;
  const FewWatchListData({required this.trackId, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  FewWatchListCompanion toCompanion(bool nullToAbsent) {
    return FewWatchListCompanion(
      trackId: Value(trackId),
      addedAt: Value(addedAt),
    );
  }

  factory FewWatchListData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FewWatchListData(
      trackId: serializer.fromJson<int>(json['trackId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  FewWatchListData copyWith({int? trackId, int? addedAt}) => FewWatchListData(
    trackId: trackId ?? this.trackId,
    addedAt: addedAt ?? this.addedAt,
  );
  FewWatchListData copyWithCompanion(FewWatchListCompanion data) {
    return FewWatchListData(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FewWatchListData(')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FewWatchListData &&
          other.trackId == this.trackId &&
          other.addedAt == this.addedAt);
}

class FewWatchListCompanion extends UpdateCompanion<FewWatchListData> {
  final Value<int> trackId;
  final Value<int> addedAt;
  const FewWatchListCompanion({
    this.trackId = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  FewWatchListCompanion.insert({
    this.trackId = const Value.absent(),
    required int addedAt,
  }) : addedAt = Value(addedAt);
  static Insertable<FewWatchListData> custom({
    Expression<int>? trackId,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  FewWatchListCompanion copyWith({Value<int>? trackId, Value<int>? addedAt}) {
    return FewWatchListCompanion(
      trackId: trackId ?? this.trackId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FewWatchListCompanion(')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $LyricsMetaTable extends LyricsMeta
    with TableInfo<$LyricsMetaTable, LyricsMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LyricsSourceType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LyricsSourceType>($LyricsMetaTable.$convertertype);
  static const VerificationMeta _lrcPathMeta = const VerificationMeta(
    'lrcPath',
  );
  @override
  late final GeneratedColumn<String> lrcPath = GeneratedColumn<String>(
    'lrc_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetMsMeta = const VerificationMeta(
    'offsetMs',
  );
  @override
  late final GeneratedColumn<int> offsetMs = GeneratedColumn<int>(
    'offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedMeta = const VerificationMeta('edited');
  @override
  late final GeneratedColumn<bool> edited = GeneratedColumn<bool>(
    'edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    type,
    lrcPath,
    sourceText,
    offsetMs,
    updatedAt,
    edited,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricsMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('lrc_path')) {
      context.handle(
        _lrcPathMeta,
        lrcPath.isAcceptableOrUnknown(data['lrc_path']!, _lrcPathMeta),
      );
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    }
    if (data.containsKey('offset_ms')) {
      context.handle(
        _offsetMsMeta,
        offsetMs.isAcceptableOrUnknown(data['offset_ms']!, _offsetMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('edited')) {
      context.handle(
        _editedMeta,
        edited.isAcceptableOrUnknown(data['edited']!, _editedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  LyricsMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsMetaData(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      type: $LyricsMetaTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      lrcPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lrc_path'],
      ),
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      ),
      offsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      edited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}edited'],
      )!,
    );
  }

  @override
  $LyricsMetaTable createAlias(String alias) {
    return $LyricsMetaTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LyricsSourceType, String, String> $convertertype =
      const EnumNameConverter<LyricsSourceType>(LyricsSourceType.values);
}

class LyricsMetaData extends DataClass implements Insertable<LyricsMetaData> {
  final int trackId;
  final LyricsSourceType type;
  final String? lrcPath;
  final String? sourceText;
  final int offsetMs;
  final int updatedAt;
  final bool edited;
  const LyricsMetaData({
    required this.trackId,
    required this.type,
    this.lrcPath,
    this.sourceText,
    required this.offsetMs,
    required this.updatedAt,
    required this.edited,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    {
      map['type'] = Variable<String>(
        $LyricsMetaTable.$convertertype.toSql(type),
      );
    }
    if (!nullToAbsent || lrcPath != null) {
      map['lrc_path'] = Variable<String>(lrcPath);
    }
    if (!nullToAbsent || sourceText != null) {
      map['source_text'] = Variable<String>(sourceText);
    }
    map['offset_ms'] = Variable<int>(offsetMs);
    map['updated_at'] = Variable<int>(updatedAt);
    map['edited'] = Variable<bool>(edited);
    return map;
  }

  LyricsMetaCompanion toCompanion(bool nullToAbsent) {
    return LyricsMetaCompanion(
      trackId: Value(trackId),
      type: Value(type),
      lrcPath: lrcPath == null && nullToAbsent
          ? const Value.absent()
          : Value(lrcPath),
      sourceText: sourceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceText),
      offsetMs: Value(offsetMs),
      updatedAt: Value(updatedAt),
      edited: Value(edited),
    );
  }

  factory LyricsMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsMetaData(
      trackId: serializer.fromJson<int>(json['trackId']),
      type: $LyricsMetaTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      lrcPath: serializer.fromJson<String?>(json['lrcPath']),
      sourceText: serializer.fromJson<String?>(json['sourceText']),
      offsetMs: serializer.fromJson<int>(json['offsetMs']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      edited: serializer.fromJson<bool>(json['edited']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'type': serializer.toJson<String>(
        $LyricsMetaTable.$convertertype.toJson(type),
      ),
      'lrcPath': serializer.toJson<String?>(lrcPath),
      'sourceText': serializer.toJson<String?>(sourceText),
      'offsetMs': serializer.toJson<int>(offsetMs),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'edited': serializer.toJson<bool>(edited),
    };
  }

  LyricsMetaData copyWith({
    int? trackId,
    LyricsSourceType? type,
    Value<String?> lrcPath = const Value.absent(),
    Value<String?> sourceText = const Value.absent(),
    int? offsetMs,
    int? updatedAt,
    bool? edited,
  }) => LyricsMetaData(
    trackId: trackId ?? this.trackId,
    type: type ?? this.type,
    lrcPath: lrcPath.present ? lrcPath.value : this.lrcPath,
    sourceText: sourceText.present ? sourceText.value : this.sourceText,
    offsetMs: offsetMs ?? this.offsetMs,
    updatedAt: updatedAt ?? this.updatedAt,
    edited: edited ?? this.edited,
  );
  LyricsMetaData copyWithCompanion(LyricsMetaCompanion data) {
    return LyricsMetaData(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      type: data.type.present ? data.type.value : this.type,
      lrcPath: data.lrcPath.present ? data.lrcPath.value : this.lrcPath,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      offsetMs: data.offsetMs.present ? data.offsetMs.value : this.offsetMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      edited: data.edited.present ? data.edited.value : this.edited,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsMetaData(')
          ..write('trackId: $trackId, ')
          ..write('type: $type, ')
          ..write('lrcPath: $lrcPath, ')
          ..write('sourceText: $sourceText, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('edited: $edited')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trackId,
    type,
    lrcPath,
    sourceText,
    offsetMs,
    updatedAt,
    edited,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsMetaData &&
          other.trackId == this.trackId &&
          other.type == this.type &&
          other.lrcPath == this.lrcPath &&
          other.sourceText == this.sourceText &&
          other.offsetMs == this.offsetMs &&
          other.updatedAt == this.updatedAt &&
          other.edited == this.edited);
}

class LyricsMetaCompanion extends UpdateCompanion<LyricsMetaData> {
  final Value<int> trackId;
  final Value<LyricsSourceType> type;
  final Value<String?> lrcPath;
  final Value<String?> sourceText;
  final Value<int> offsetMs;
  final Value<int> updatedAt;
  final Value<bool> edited;
  const LyricsMetaCompanion({
    this.trackId = const Value.absent(),
    this.type = const Value.absent(),
    this.lrcPath = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.edited = const Value.absent(),
  });
  LyricsMetaCompanion.insert({
    this.trackId = const Value.absent(),
    required LyricsSourceType type,
    this.lrcPath = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.offsetMs = const Value.absent(),
    required int updatedAt,
    this.edited = const Value.absent(),
  }) : type = Value(type),
       updatedAt = Value(updatedAt);
  static Insertable<LyricsMetaData> custom({
    Expression<int>? trackId,
    Expression<String>? type,
    Expression<String>? lrcPath,
    Expression<String>? sourceText,
    Expression<int>? offsetMs,
    Expression<int>? updatedAt,
    Expression<bool>? edited,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (type != null) 'type': type,
      if (lrcPath != null) 'lrc_path': lrcPath,
      if (sourceText != null) 'source_text': sourceText,
      if (offsetMs != null) 'offset_ms': offsetMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (edited != null) 'edited': edited,
    });
  }

  LyricsMetaCompanion copyWith({
    Value<int>? trackId,
    Value<LyricsSourceType>? type,
    Value<String?>? lrcPath,
    Value<String?>? sourceText,
    Value<int>? offsetMs,
    Value<int>? updatedAt,
    Value<bool>? edited,
  }) {
    return LyricsMetaCompanion(
      trackId: trackId ?? this.trackId,
      type: type ?? this.type,
      lrcPath: lrcPath ?? this.lrcPath,
      sourceText: sourceText ?? this.sourceText,
      offsetMs: offsetMs ?? this.offsetMs,
      updatedAt: updatedAt ?? this.updatedAt,
      edited: edited ?? this.edited,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $LyricsMetaTable.$convertertype.toSql(type.value),
      );
    }
    if (lrcPath.present) {
      map['lrc_path'] = Variable<String>(lrcPath.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (offsetMs.present) {
      map['offset_ms'] = Variable<int>(offsetMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsMetaCompanion(')
          ..write('trackId: $trackId, ')
          ..write('type: $type, ')
          ..write('lrcPath: $lrcPath, ')
          ..write('sourceText: $sourceText, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('edited: $edited')
          ..write(')'))
        .toString();
  }
}

class $ModelRegistryTable extends ModelRegistry
    with TableInfo<$ModelRegistryTable, ModelRegistryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelRegistryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ModelStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ModelStatus>($ModelRegistryTable.$converterstatus);
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<int> downloadedAt = GeneratedColumn<int>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    modelId,
    sizeBytes,
    sha256,
    status,
    localPath,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_registry';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelRegistryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {modelId};
  @override
  ModelRegistryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelRegistryData(
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      status: $ModelRegistryTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_at'],
      ),
    );
  }

  @override
  $ModelRegistryTable createAlias(String alias) {
    return $ModelRegistryTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ModelStatus, String, String> $converterstatus =
      const EnumNameConverter<ModelStatus>(ModelStatus.values);
}

class ModelRegistryData extends DataClass
    implements Insertable<ModelRegistryData> {
  final String modelId;
  final int? sizeBytes;
  final String? sha256;
  final ModelStatus status;
  final String? localPath;
  final int? downloadedAt;
  const ModelRegistryData({
    required this.modelId,
    this.sizeBytes,
    this.sha256,
    required this.status,
    this.localPath,
    this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['model_id'] = Variable<String>(modelId);
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    {
      map['status'] = Variable<String>(
        $ModelRegistryTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<int>(downloadedAt);
    }
    return map;
  }

  ModelRegistryCompanion toCompanion(bool nullToAbsent) {
    return ModelRegistryCompanion(
      modelId: Value(modelId),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      status: Value(status),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
    );
  }

  factory ModelRegistryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelRegistryData(
      modelId: serializer.fromJson<String>(json['modelId']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      status: $ModelRegistryTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      localPath: serializer.fromJson<String?>(json['localPath']),
      downloadedAt: serializer.fromJson<int?>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'modelId': serializer.toJson<String>(modelId),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'sha256': serializer.toJson<String?>(sha256),
      'status': serializer.toJson<String>(
        $ModelRegistryTable.$converterstatus.toJson(status),
      ),
      'localPath': serializer.toJson<String?>(localPath),
      'downloadedAt': serializer.toJson<int?>(downloadedAt),
    };
  }

  ModelRegistryData copyWith({
    String? modelId,
    Value<int?> sizeBytes = const Value.absent(),
    Value<String?> sha256 = const Value.absent(),
    ModelStatus? status,
    Value<String?> localPath = const Value.absent(),
    Value<int?> downloadedAt = const Value.absent(),
  }) => ModelRegistryData(
    modelId: modelId ?? this.modelId,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    sha256: sha256.present ? sha256.value : this.sha256,
    status: status ?? this.status,
    localPath: localPath.present ? localPath.value : this.localPath,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
  );
  ModelRegistryData copyWithCompanion(ModelRegistryCompanion data) {
    return ModelRegistryData(
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      status: data.status.present ? data.status.value : this.status,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelRegistryData(')
          ..write('modelId: $modelId, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sha256: $sha256, ')
          ..write('status: $status, ')
          ..write('localPath: $localPath, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(modelId, sizeBytes, sha256, status, localPath, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelRegistryData &&
          other.modelId == this.modelId &&
          other.sizeBytes == this.sizeBytes &&
          other.sha256 == this.sha256 &&
          other.status == this.status &&
          other.localPath == this.localPath &&
          other.downloadedAt == this.downloadedAt);
}

class ModelRegistryCompanion extends UpdateCompanion<ModelRegistryData> {
  final Value<String> modelId;
  final Value<int?> sizeBytes;
  final Value<String?> sha256;
  final Value<ModelStatus> status;
  final Value<String?> localPath;
  final Value<int?> downloadedAt;
  final Value<int> rowid;
  const ModelRegistryCompanion({
    this.modelId = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.status = const Value.absent(),
    this.localPath = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelRegistryCompanion.insert({
    required String modelId,
    this.sizeBytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    required ModelStatus status,
    this.localPath = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : modelId = Value(modelId),
       status = Value(status);
  static Insertable<ModelRegistryData> custom({
    Expression<String>? modelId,
    Expression<int>? sizeBytes,
    Expression<String>? sha256,
    Expression<String>? status,
    Expression<String>? localPath,
    Expression<int>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (modelId != null) 'model_id': modelId,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (sha256 != null) 'sha256': sha256,
      if (status != null) 'status': status,
      if (localPath != null) 'local_path': localPath,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelRegistryCompanion copyWith({
    Value<String>? modelId,
    Value<int?>? sizeBytes,
    Value<String?>? sha256,
    Value<ModelStatus>? status,
    Value<String?>? localPath,
    Value<int?>? downloadedAt,
    Value<int>? rowid,
  }) {
    return ModelRegistryCompanion(
      modelId: modelId ?? this.modelId,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sha256: sha256 ?? this.sha256,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ModelRegistryTable.$converterstatus.toSql(status.value),
      );
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<int>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelRegistryCompanion(')
          ..write('modelId: $modelId, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sha256: $sha256, ')
          ..write('status: $status, ')
          ..write('localPath: $localPath, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricsGenJobsTable extends LyricsGenJobs
    with TableInfo<$LyricsGenJobsTable, LyricsGenJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsGenJobsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LyricsJobStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LyricsJobStatus>($LyricsGenJobsTable.$converterstatus);
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES model_registry (model_id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<int> finishedAt = GeneratedColumn<int>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    status,
    progress,
    modelId,
    createdAt,
    updatedAt,
    startedAt,
    finishedAt,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_gen_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricsGenJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {trackId},
  ];
  @override
  LyricsGenJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsGenJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      status: $LyricsGenJobsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished_at'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $LyricsGenJobsTable createAlias(String alias) {
    return $LyricsGenJobsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LyricsJobStatus, String, String> $converterstatus =
      const EnumNameConverter<LyricsJobStatus>(LyricsJobStatus.values);
}

class LyricsGenJob extends DataClass implements Insertable<LyricsGenJob> {
  final int id;
  final int trackId;
  final LyricsJobStatus status;
  final double progress;
  final String? modelId;
  final int createdAt;
  final int updatedAt;
  final int? startedAt;
  final int? finishedAt;
  final String? errorCode;
  const LyricsGenJob({
    required this.id,
    required this.trackId,
    required this.status,
    required this.progress,
    this.modelId,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.finishedAt,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    {
      map['status'] = Variable<String>(
        $LyricsGenJobsTable.$converterstatus.toSql(status),
      );
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(finishedAt);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  LyricsGenJobsCompanion toCompanion(bool nullToAbsent) {
    return LyricsGenJobsCompanion(
      id: Value(id),
      trackId: Value(trackId),
      status: Value(status),
      progress: Value(progress),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory LyricsGenJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsGenJob(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      status: $LyricsGenJobsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      progress: serializer.fromJson<double>(json['progress']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      finishedAt: serializer.fromJson<int?>(json['finishedAt']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'status': serializer.toJson<String>(
        $LyricsGenJobsTable.$converterstatus.toJson(status),
      ),
      'progress': serializer.toJson<double>(progress),
      'modelId': serializer.toJson<String?>(modelId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'startedAt': serializer.toJson<int?>(startedAt),
      'finishedAt': serializer.toJson<int?>(finishedAt),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  LyricsGenJob copyWith({
    int? id,
    int? trackId,
    LyricsJobStatus? status,
    double? progress,
    Value<String?> modelId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> finishedAt = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
  }) => LyricsGenJob(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    modelId: modelId.present ? modelId.value : this.modelId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  LyricsGenJob copyWithCompanion(LyricsGenJobsCompanion data) {
    return LyricsGenJob(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsGenJob(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('modelId: $modelId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    status,
    progress,
    modelId,
    createdAt,
    updatedAt,
    startedAt,
    finishedAt,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsGenJob &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.modelId == this.modelId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.errorCode == this.errorCode);
}

class LyricsGenJobsCompanion extends UpdateCompanion<LyricsGenJob> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<LyricsJobStatus> status;
  final Value<double> progress;
  final Value<String?> modelId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> startedAt;
  final Value<int?> finishedAt;
  final Value<String?> errorCode;
  const LyricsGenJobsCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.modelId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.errorCode = const Value.absent(),
  });
  LyricsGenJobsCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    required LyricsJobStatus status,
    this.progress = const Value.absent(),
    this.modelId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.errorCode = const Value.absent(),
  }) : trackId = Value(trackId),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LyricsGenJob> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<String>? modelId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? startedAt,
    Expression<int>? finishedAt,
    Expression<String>? errorCode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (modelId != null) 'model_id': modelId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (errorCode != null) 'error_code': errorCode,
    });
  }

  LyricsGenJobsCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<LyricsJobStatus>? status,
    Value<double>? progress,
    Value<String?>? modelId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? startedAt,
    Value<int?>? finishedAt,
    Value<String?>? errorCode,
  }) {
    return LyricsGenJobsCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      errorCode: errorCode ?? this.errorCode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $LyricsGenJobsTable.$converterstatus.toSql(status.value),
      );
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(finishedAt.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsGenJobsCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('modelId: $modelId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }
}

class $ExtractTasksTable extends ExtractTasks
    with TableInfo<$ExtractTasksTable, ExtractTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtractTasksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploaderMeta = const VerificationMeta(
    'uploader',
  );
  @override
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
    'uploader',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskQuality, String> quality =
      GeneratedColumn<String>(
        'quality',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TaskQuality>($ExtractTasksTable.$converterquality);
  static const VerificationMeta _progressPctMeta = const VerificationMeta(
    'progressPct',
  );
  @override
  late final GeneratedColumn<double> progressPct = GeneratedColumn<double>(
    'progress_pct',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExtractTaskStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ExtractTaskStatus>($ExtractTasksTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<ExtractErrorCode?, String>
  errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<ExtractErrorCode?>($ExtractTasksTable.$convertererrorCoden);
  static const VerificationMeta _outputRelPathMeta = const VerificationMeta(
    'outputRelPath',
  );
  @override
  late final GeneratedColumn<String> outputRelPath = GeneratedColumn<String>(
    'output_rel_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cookiesUsedMeta = const VerificationMeta(
    'cookiesUsed',
  );
  @override
  late final GeneratedColumn<bool> cookiesUsed = GeneratedColumn<bool>(
    'cookies_used',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cookies_used" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceType,
    sourceId,
    url,
    title,
    uploader,
    durationMs,
    quality,
    progressPct,
    status,
    errorCode,
    outputRelPath,
    cookiesUsed,
    retryCount,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extract_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtractTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('uploader')) {
      context.handle(
        _uploaderMeta,
        uploader.isAcceptableOrUnknown(data['uploader']!, _uploaderMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('progress_pct')) {
      context.handle(
        _progressPctMeta,
        progressPct.isAcceptableOrUnknown(
          data['progress_pct']!,
          _progressPctMeta,
        ),
      );
    }
    if (data.containsKey('output_rel_path')) {
      context.handle(
        _outputRelPathMeta,
        outputRelPath.isAcceptableOrUnknown(
          data['output_rel_path']!,
          _outputRelPathMeta,
        ),
      );
    }
    if (data.containsKey('cookies_used')) {
      context.handle(
        _cookiesUsedMeta,
        cookiesUsed.isAcceptableOrUnknown(
          data['cookies_used']!,
          _cookiesUsedMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceType, sourceId},
  ];
  @override
  ExtractTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtractTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      uploader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uploader'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      quality: $ExtractTasksTable.$converterquality.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}quality'],
        )!,
      ),
      progressPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_pct'],
      )!,
      status: $ExtractTasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      errorCode: $ExtractTasksTable.$convertererrorCoden.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}error_code'],
        ),
      ),
      outputRelPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_rel_path'],
      ),
      cookiesUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cookies_used'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ExtractTasksTable createAlias(String alias) {
    return $ExtractTasksTable(attachedDatabase, alias);
  }

  static TypeConverter<TaskQuality, String> $converterquality =
      const TaskQualityConverter();
  static JsonTypeConverter2<ExtractTaskStatus, String, String>
  $converterstatus = const EnumNameConverter<ExtractTaskStatus>(
    ExtractTaskStatus.values,
  );
  static JsonTypeConverter2<ExtractErrorCode, String, String>
  $convertererrorCode = const EnumNameConverter<ExtractErrorCode>(
    ExtractErrorCode.values,
  );
  static JsonTypeConverter2<ExtractErrorCode?, String?, String?>
  $convertererrorCoden = JsonTypeConverter2.asNullable($convertererrorCode);
}

class ExtractTask extends DataClass implements Insertable<ExtractTask> {
  final int id;
  final String sourceType;
  final String sourceId;
  final String url;
  final String? title;
  final String? uploader;
  final int? durationMs;
  final TaskQuality quality;
  final double progressPct;
  final ExtractTaskStatus status;
  final ExtractErrorCode? errorCode;
  final String? outputRelPath;
  final bool cookiesUsed;
  final int retryCount;
  final int createdAt;
  final int updatedAt;
  const ExtractTask({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.url,
    this.title,
    this.uploader,
    this.durationMs,
    required this.quality,
    required this.progressPct,
    required this.status,
    this.errorCode,
    this.outputRelPath,
    required this.cookiesUsed,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_type'] = Variable<String>(sourceType);
    map['source_id'] = Variable<String>(sourceId);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String>(uploader);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    {
      map['quality'] = Variable<String>(
        $ExtractTasksTable.$converterquality.toSql(quality),
      );
    }
    map['progress_pct'] = Variable<double>(progressPct);
    {
      map['status'] = Variable<String>(
        $ExtractTasksTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(
        $ExtractTasksTable.$convertererrorCoden.toSql(errorCode),
      );
    }
    if (!nullToAbsent || outputRelPath != null) {
      map['output_rel_path'] = Variable<String>(outputRelPath);
    }
    map['cookies_used'] = Variable<bool>(cookiesUsed);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ExtractTasksCompanion toCompanion(bool nullToAbsent) {
    return ExtractTasksCompanion(
      id: Value(id),
      sourceType: Value(sourceType),
      sourceId: Value(sourceId),
      url: Value(url),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      uploader: uploader == null && nullToAbsent
          ? const Value.absent()
          : Value(uploader),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      quality: Value(quality),
      progressPct: Value(progressPct),
      status: Value(status),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      outputRelPath: outputRelPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputRelPath),
      cookiesUsed: Value(cookiesUsed),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExtractTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtractTask(
      id: serializer.fromJson<int>(json['id']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      url: serializer.fromJson<String>(json['url']),
      title: serializer.fromJson<String?>(json['title']),
      uploader: serializer.fromJson<String?>(json['uploader']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      quality: serializer.fromJson<TaskQuality>(json['quality']),
      progressPct: serializer.fromJson<double>(json['progressPct']),
      status: $ExtractTasksTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      errorCode: $ExtractTasksTable.$convertererrorCoden.fromJson(
        serializer.fromJson<String?>(json['errorCode']),
      ),
      outputRelPath: serializer.fromJson<String?>(json['outputRelPath']),
      cookiesUsed: serializer.fromJson<bool>(json['cookiesUsed']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceId': serializer.toJson<String>(sourceId),
      'url': serializer.toJson<String>(url),
      'title': serializer.toJson<String?>(title),
      'uploader': serializer.toJson<String?>(uploader),
      'durationMs': serializer.toJson<int?>(durationMs),
      'quality': serializer.toJson<TaskQuality>(quality),
      'progressPct': serializer.toJson<double>(progressPct),
      'status': serializer.toJson<String>(
        $ExtractTasksTable.$converterstatus.toJson(status),
      ),
      'errorCode': serializer.toJson<String?>(
        $ExtractTasksTable.$convertererrorCoden.toJson(errorCode),
      ),
      'outputRelPath': serializer.toJson<String?>(outputRelPath),
      'cookiesUsed': serializer.toJson<bool>(cookiesUsed),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ExtractTask copyWith({
    int? id,
    String? sourceType,
    String? sourceId,
    String? url,
    Value<String?> title = const Value.absent(),
    Value<String?> uploader = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    TaskQuality? quality,
    double? progressPct,
    ExtractTaskStatus? status,
    Value<ExtractErrorCode?> errorCode = const Value.absent(),
    Value<String?> outputRelPath = const Value.absent(),
    bool? cookiesUsed,
    int? retryCount,
    int? createdAt,
    int? updatedAt,
  }) => ExtractTask(
    id: id ?? this.id,
    sourceType: sourceType ?? this.sourceType,
    sourceId: sourceId ?? this.sourceId,
    url: url ?? this.url,
    title: title.present ? title.value : this.title,
    uploader: uploader.present ? uploader.value : this.uploader,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    quality: quality ?? this.quality,
    progressPct: progressPct ?? this.progressPct,
    status: status ?? this.status,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    outputRelPath: outputRelPath.present
        ? outputRelPath.value
        : this.outputRelPath,
    cookiesUsed: cookiesUsed ?? this.cookiesUsed,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExtractTask copyWithCompanion(ExtractTasksCompanion data) {
    return ExtractTask(
      id: data.id.present ? data.id.value : this.id,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      uploader: data.uploader.present ? data.uploader.value : this.uploader,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      quality: data.quality.present ? data.quality.value : this.quality,
      progressPct: data.progressPct.present
          ? data.progressPct.value
          : this.progressPct,
      status: data.status.present ? data.status.value : this.status,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      outputRelPath: data.outputRelPath.present
          ? data.outputRelPath.value
          : this.outputRelPath,
      cookiesUsed: data.cookiesUsed.present
          ? data.cookiesUsed.value
          : this.cookiesUsed,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtractTask(')
          ..write('id: $id, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('uploader: $uploader, ')
          ..write('durationMs: $durationMs, ')
          ..write('quality: $quality, ')
          ..write('progressPct: $progressPct, ')
          ..write('status: $status, ')
          ..write('errorCode: $errorCode, ')
          ..write('outputRelPath: $outputRelPath, ')
          ..write('cookiesUsed: $cookiesUsed, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceType,
    sourceId,
    url,
    title,
    uploader,
    durationMs,
    quality,
    progressPct,
    status,
    errorCode,
    outputRelPath,
    cookiesUsed,
    retryCount,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtractTask &&
          other.id == this.id &&
          other.sourceType == this.sourceType &&
          other.sourceId == this.sourceId &&
          other.url == this.url &&
          other.title == this.title &&
          other.uploader == this.uploader &&
          other.durationMs == this.durationMs &&
          other.quality == this.quality &&
          other.progressPct == this.progressPct &&
          other.status == this.status &&
          other.errorCode == this.errorCode &&
          other.outputRelPath == this.outputRelPath &&
          other.cookiesUsed == this.cookiesUsed &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ExtractTasksCompanion extends UpdateCompanion<ExtractTask> {
  final Value<int> id;
  final Value<String> sourceType;
  final Value<String> sourceId;
  final Value<String> url;
  final Value<String?> title;
  final Value<String?> uploader;
  final Value<int?> durationMs;
  final Value<TaskQuality> quality;
  final Value<double> progressPct;
  final Value<ExtractTaskStatus> status;
  final Value<ExtractErrorCode?> errorCode;
  final Value<String?> outputRelPath;
  final Value<bool> cookiesUsed;
  final Value<int> retryCount;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const ExtractTasksCompanion({
    this.id = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.uploader = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.quality = const Value.absent(),
    this.progressPct = const Value.absent(),
    this.status = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.outputRelPath = const Value.absent(),
    this.cookiesUsed = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ExtractTasksCompanion.insert({
    this.id = const Value.absent(),
    required String sourceType,
    required String sourceId,
    required String url,
    this.title = const Value.absent(),
    this.uploader = const Value.absent(),
    this.durationMs = const Value.absent(),
    required TaskQuality quality,
    this.progressPct = const Value.absent(),
    required ExtractTaskStatus status,
    this.errorCode = const Value.absent(),
    this.outputRelPath = const Value.absent(),
    this.cookiesUsed = const Value.absent(),
    this.retryCount = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : sourceType = Value(sourceType),
       sourceId = Value(sourceId),
       url = Value(url),
       quality = Value(quality),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ExtractTask> custom({
    Expression<int>? id,
    Expression<String>? sourceType,
    Expression<String>? sourceId,
    Expression<String>? url,
    Expression<String>? title,
    Expression<String>? uploader,
    Expression<int>? durationMs,
    Expression<String>? quality,
    Expression<double>? progressPct,
    Expression<String>? status,
    Expression<String>? errorCode,
    Expression<String>? outputRelPath,
    Expression<bool>? cookiesUsed,
    Expression<int>? retryCount,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (uploader != null) 'uploader': uploader,
      if (durationMs != null) 'duration_ms': durationMs,
      if (quality != null) 'quality': quality,
      if (progressPct != null) 'progress_pct': progressPct,
      if (status != null) 'status': status,
      if (errorCode != null) 'error_code': errorCode,
      if (outputRelPath != null) 'output_rel_path': outputRelPath,
      if (cookiesUsed != null) 'cookies_used': cookiesUsed,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ExtractTasksCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceType,
    Value<String>? sourceId,
    Value<String>? url,
    Value<String?>? title,
    Value<String?>? uploader,
    Value<int?>? durationMs,
    Value<TaskQuality>? quality,
    Value<double>? progressPct,
    Value<ExtractTaskStatus>? status,
    Value<ExtractErrorCode?>? errorCode,
    Value<String?>? outputRelPath,
    Value<bool>? cookiesUsed,
    Value<int>? retryCount,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return ExtractTasksCompanion(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      url: url ?? this.url,
      title: title ?? this.title,
      uploader: uploader ?? this.uploader,
      durationMs: durationMs ?? this.durationMs,
      quality: quality ?? this.quality,
      progressPct: progressPct ?? this.progressPct,
      status: status ?? this.status,
      errorCode: errorCode ?? this.errorCode,
      outputRelPath: outputRelPath ?? this.outputRelPath,
      cookiesUsed: cookiesUsed ?? this.cookiesUsed,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String>(uploader.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(
        $ExtractTasksTable.$converterquality.toSql(quality.value),
      );
    }
    if (progressPct.present) {
      map['progress_pct'] = Variable<double>(progressPct.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ExtractTasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(
        $ExtractTasksTable.$convertererrorCoden.toSql(errorCode.value),
      );
    }
    if (outputRelPath.present) {
      map['output_rel_path'] = Variable<String>(outputRelPath.value);
    }
    if (cookiesUsed.present) {
      map['cookies_used'] = Variable<bool>(cookiesUsed.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtractTasksCompanion(')
          ..write('id: $id, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('uploader: $uploader, ')
          ..write('durationMs: $durationMs, ')
          ..write('quality: $quality, ')
          ..write('progressPct: $progressPct, ')
          ..write('status: $status, ')
          ..write('errorCode: $errorCode, ')
          ..write('outputRelPath: $outputRelPath, ')
          ..write('cookiesUsed: $cookiesUsed, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncChannelTable extends SyncChannel
    with TableInfo<$SyncChannelTable, SyncChannelData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncChannelTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<SyncChannelType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncChannelType>($SyncChannelTable.$convertertype);
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteDirMeta = const VerificationMeta(
    'remoteDir',
  );
  @override
  late final GeneratedColumn<String> remoteDir = GeneratedColumn<String>(
    'remote_dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('iA-Music/'),
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialsRefMeta = const VerificationMeta(
    'credentialsRef',
  );
  @override
  late final GeneratedColumn<String> credentialsRef = GeneratedColumn<String>(
    'credentials_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastTestAtMeta = const VerificationMeta(
    'lastTestAt',
  );
  @override
  late final GeneratedColumn<int> lastTestAt = GeneratedColumn<int>(
    'last_test_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastTestOkMeta = const VerificationMeta(
    'lastTestOk',
  );
  @override
  late final GeneratedColumn<bool> lastTestOk = GeneratedColumn<bool>(
    'last_test_ok',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("last_test_ok" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    baseUrl,
    remoteDir,
    username,
    credentialsRef,
    isActive,
    lastTestAt,
    lastTestOk,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_channel';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncChannelData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('remote_dir')) {
      context.handle(
        _remoteDirMeta,
        remoteDir.isAcceptableOrUnknown(data['remote_dir']!, _remoteDirMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('credentials_ref')) {
      context.handle(
        _credentialsRefMeta,
        credentialsRef.isAcceptableOrUnknown(
          data['credentials_ref']!,
          _credentialsRefMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('last_test_at')) {
      context.handle(
        _lastTestAtMeta,
        lastTestAt.isAcceptableOrUnknown(
          data['last_test_at']!,
          _lastTestAtMeta,
        ),
      );
    }
    if (data.containsKey('last_test_ok')) {
      context.handle(
        _lastTestOkMeta,
        lastTestOk.isAcceptableOrUnknown(
          data['last_test_ok']!,
          _lastTestOkMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncChannelData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncChannelData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: $SyncChannelTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      remoteDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_dir'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      credentialsRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credentials_ref'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      lastTestAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_test_at'],
      ),
      lastTestOk: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}last_test_ok'],
      ),
    );
  }

  @override
  $SyncChannelTable createAlias(String alias) {
    return $SyncChannelTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncChannelType, String, String> $convertertype =
      const EnumNameConverter<SyncChannelType>(SyncChannelType.values);
}

class SyncChannelData extends DataClass implements Insertable<SyncChannelData> {
  final int id;
  final SyncChannelType type;
  final String baseUrl;
  final String remoteDir;
  final String? username;
  final String? credentialsRef;
  final bool isActive;
  final int? lastTestAt;

  /// 「last_test_at BOOLEAN result」落两列（六问自答：时间+结果分开存）。
  final bool? lastTestOk;
  const SyncChannelData({
    required this.id,
    required this.type,
    required this.baseUrl,
    required this.remoteDir,
    this.username,
    this.credentialsRef,
    required this.isActive,
    this.lastTestAt,
    this.lastTestOk,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['type'] = Variable<String>(
        $SyncChannelTable.$convertertype.toSql(type),
      );
    }
    map['base_url'] = Variable<String>(baseUrl);
    map['remote_dir'] = Variable<String>(remoteDir);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || credentialsRef != null) {
      map['credentials_ref'] = Variable<String>(credentialsRef);
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || lastTestAt != null) {
      map['last_test_at'] = Variable<int>(lastTestAt);
    }
    if (!nullToAbsent || lastTestOk != null) {
      map['last_test_ok'] = Variable<bool>(lastTestOk);
    }
    return map;
  }

  SyncChannelCompanion toCompanion(bool nullToAbsent) {
    return SyncChannelCompanion(
      id: Value(id),
      type: Value(type),
      baseUrl: Value(baseUrl),
      remoteDir: Value(remoteDir),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      credentialsRef: credentialsRef == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialsRef),
      isActive: Value(isActive),
      lastTestAt: lastTestAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTestAt),
      lastTestOk: lastTestOk == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTestOk),
    );
  }

  factory SyncChannelData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncChannelData(
      id: serializer.fromJson<int>(json['id']),
      type: $SyncChannelTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      remoteDir: serializer.fromJson<String>(json['remoteDir']),
      username: serializer.fromJson<String?>(json['username']),
      credentialsRef: serializer.fromJson<String?>(json['credentialsRef']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      lastTestAt: serializer.fromJson<int?>(json['lastTestAt']),
      lastTestOk: serializer.fromJson<bool?>(json['lastTestOk']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(
        $SyncChannelTable.$convertertype.toJson(type),
      ),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'remoteDir': serializer.toJson<String>(remoteDir),
      'username': serializer.toJson<String?>(username),
      'credentialsRef': serializer.toJson<String?>(credentialsRef),
      'isActive': serializer.toJson<bool>(isActive),
      'lastTestAt': serializer.toJson<int?>(lastTestAt),
      'lastTestOk': serializer.toJson<bool?>(lastTestOk),
    };
  }

  SyncChannelData copyWith({
    int? id,
    SyncChannelType? type,
    String? baseUrl,
    String? remoteDir,
    Value<String?> username = const Value.absent(),
    Value<String?> credentialsRef = const Value.absent(),
    bool? isActive,
    Value<int?> lastTestAt = const Value.absent(),
    Value<bool?> lastTestOk = const Value.absent(),
  }) => SyncChannelData(
    id: id ?? this.id,
    type: type ?? this.type,
    baseUrl: baseUrl ?? this.baseUrl,
    remoteDir: remoteDir ?? this.remoteDir,
    username: username.present ? username.value : this.username,
    credentialsRef: credentialsRef.present
        ? credentialsRef.value
        : this.credentialsRef,
    isActive: isActive ?? this.isActive,
    lastTestAt: lastTestAt.present ? lastTestAt.value : this.lastTestAt,
    lastTestOk: lastTestOk.present ? lastTestOk.value : this.lastTestOk,
  );
  SyncChannelData copyWithCompanion(SyncChannelCompanion data) {
    return SyncChannelData(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      remoteDir: data.remoteDir.present ? data.remoteDir.value : this.remoteDir,
      username: data.username.present ? data.username.value : this.username,
      credentialsRef: data.credentialsRef.present
          ? data.credentialsRef.value
          : this.credentialsRef,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      lastTestAt: data.lastTestAt.present
          ? data.lastTestAt.value
          : this.lastTestAt,
      lastTestOk: data.lastTestOk.present
          ? data.lastTestOk.value
          : this.lastTestOk,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncChannelData(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('remoteDir: $remoteDir, ')
          ..write('username: $username, ')
          ..write('credentialsRef: $credentialsRef, ')
          ..write('isActive: $isActive, ')
          ..write('lastTestAt: $lastTestAt, ')
          ..write('lastTestOk: $lastTestOk')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    baseUrl,
    remoteDir,
    username,
    credentialsRef,
    isActive,
    lastTestAt,
    lastTestOk,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncChannelData &&
          other.id == this.id &&
          other.type == this.type &&
          other.baseUrl == this.baseUrl &&
          other.remoteDir == this.remoteDir &&
          other.username == this.username &&
          other.credentialsRef == this.credentialsRef &&
          other.isActive == this.isActive &&
          other.lastTestAt == this.lastTestAt &&
          other.lastTestOk == this.lastTestOk);
}

class SyncChannelCompanion extends UpdateCompanion<SyncChannelData> {
  final Value<int> id;
  final Value<SyncChannelType> type;
  final Value<String> baseUrl;
  final Value<String> remoteDir;
  final Value<String?> username;
  final Value<String?> credentialsRef;
  final Value<bool> isActive;
  final Value<int?> lastTestAt;
  final Value<bool?> lastTestOk;
  const SyncChannelCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.remoteDir = const Value.absent(),
    this.username = const Value.absent(),
    this.credentialsRef = const Value.absent(),
    this.isActive = const Value.absent(),
    this.lastTestAt = const Value.absent(),
    this.lastTestOk = const Value.absent(),
  });
  SyncChannelCompanion.insert({
    this.id = const Value.absent(),
    required SyncChannelType type,
    required String baseUrl,
    this.remoteDir = const Value.absent(),
    this.username = const Value.absent(),
    this.credentialsRef = const Value.absent(),
    this.isActive = const Value.absent(),
    this.lastTestAt = const Value.absent(),
    this.lastTestOk = const Value.absent(),
  }) : type = Value(type),
       baseUrl = Value(baseUrl);
  static Insertable<SyncChannelData> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? baseUrl,
    Expression<String>? remoteDir,
    Expression<String>? username,
    Expression<String>? credentialsRef,
    Expression<bool>? isActive,
    Expression<int>? lastTestAt,
    Expression<bool>? lastTestOk,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (baseUrl != null) 'base_url': baseUrl,
      if (remoteDir != null) 'remote_dir': remoteDir,
      if (username != null) 'username': username,
      if (credentialsRef != null) 'credentials_ref': credentialsRef,
      if (isActive != null) 'is_active': isActive,
      if (lastTestAt != null) 'last_test_at': lastTestAt,
      if (lastTestOk != null) 'last_test_ok': lastTestOk,
    });
  }

  SyncChannelCompanion copyWith({
    Value<int>? id,
    Value<SyncChannelType>? type,
    Value<String>? baseUrl,
    Value<String>? remoteDir,
    Value<String?>? username,
    Value<String?>? credentialsRef,
    Value<bool>? isActive,
    Value<int?>? lastTestAt,
    Value<bool?>? lastTestOk,
  }) {
    return SyncChannelCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      remoteDir: remoteDir ?? this.remoteDir,
      username: username ?? this.username,
      credentialsRef: credentialsRef ?? this.credentialsRef,
      isActive: isActive ?? this.isActive,
      lastTestAt: lastTestAt ?? this.lastTestAt,
      lastTestOk: lastTestOk ?? this.lastTestOk,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $SyncChannelTable.$convertertype.toSql(type.value),
      );
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (remoteDir.present) {
      map['remote_dir'] = Variable<String>(remoteDir.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (credentialsRef.present) {
      map['credentials_ref'] = Variable<String>(credentialsRef.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (lastTestAt.present) {
      map['last_test_at'] = Variable<int>(lastTestAt.value);
    }
    if (lastTestOk.present) {
      map['last_test_ok'] = Variable<bool>(lastTestOk.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncChannelCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('remoteDir: $remoteDir, ')
          ..write('username: $username, ')
          ..write('credentialsRef: $credentialsRef, ')
          ..write('isActive: $isActive, ')
          ..write('lastTestAt: $lastTestAt, ')
          ..write('lastTestOk: $lastTestOk')
          ..write(')'))
        .toString();
  }
}

class $LastSyncStateTable extends LastSyncState
    with TableInfo<$LastSyncStateTable, LastSyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LastSyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<int> channelId = GeneratedColumn<int>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sync_channel (id)',
    ),
  );
  static const VerificationMeta _lastStartedAtMeta = const VerificationMeta(
    'lastStartedAt',
  );
  @override
  late final GeneratedColumn<int> lastStartedAt = GeneratedColumn<int>(
    'last_started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCompletedAtMeta = const VerificationMeta(
    'lastCompletedAt',
  );
  @override
  late final GeneratedColumn<int> lastCompletedAt = GeneratedColumn<int>(
    'last_completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingUpMeta = const VerificationMeta(
    'pendingUp',
  );
  @override
  late final GeneratedColumn<int> pendingUp = GeneratedColumn<int>(
    'pending_up',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingDownMeta = const VerificationMeta(
    'pendingDown',
  );
  @override
  late final GeneratedColumn<int> pendingDown = GeneratedColumn<int>(
    'pending_down',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    channelId,
    lastStartedAt,
    lastCompletedAt,
    pendingUp,
    pendingDown,
    summaryJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'last_sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<LastSyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    }
    if (data.containsKey('last_started_at')) {
      context.handle(
        _lastStartedAtMeta,
        lastStartedAt.isAcceptableOrUnknown(
          data['last_started_at']!,
          _lastStartedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_completed_at')) {
      context.handle(
        _lastCompletedAtMeta,
        lastCompletedAt.isAcceptableOrUnknown(
          data['last_completed_at']!,
          _lastCompletedAtMeta,
        ),
      );
    }
    if (data.containsKey('pending_up')) {
      context.handle(
        _pendingUpMeta,
        pendingUp.isAcceptableOrUnknown(data['pending_up']!, _pendingUpMeta),
      );
    }
    if (data.containsKey('pending_down')) {
      context.handle(
        _pendingDownMeta,
        pendingDown.isAcceptableOrUnknown(
          data['pending_down']!,
          _pendingDownMeta,
        ),
      );
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {channelId};
  @override
  LastSyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LastSyncStateData(
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channel_id'],
      )!,
      lastStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_started_at'],
      ),
      lastCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_completed_at'],
      ),
      pendingUp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_up'],
      ),
      pendingDown: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_down'],
      ),
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      ),
    );
  }

  @override
  $LastSyncStateTable createAlias(String alias) {
    return $LastSyncStateTable(attachedDatabase, alias);
  }
}

class LastSyncStateData extends DataClass
    implements Insertable<LastSyncStateData> {
  final int channelId;
  final int? lastStartedAt;
  final int? lastCompletedAt;
  final int? pendingUp;
  final int? pendingDown;
  final String? summaryJson;
  const LastSyncStateData({
    required this.channelId,
    this.lastStartedAt,
    this.lastCompletedAt,
    this.pendingUp,
    this.pendingDown,
    this.summaryJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['channel_id'] = Variable<int>(channelId);
    if (!nullToAbsent || lastStartedAt != null) {
      map['last_started_at'] = Variable<int>(lastStartedAt);
    }
    if (!nullToAbsent || lastCompletedAt != null) {
      map['last_completed_at'] = Variable<int>(lastCompletedAt);
    }
    if (!nullToAbsent || pendingUp != null) {
      map['pending_up'] = Variable<int>(pendingUp);
    }
    if (!nullToAbsent || pendingDown != null) {
      map['pending_down'] = Variable<int>(pendingDown);
    }
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    return map;
  }

  LastSyncStateCompanion toCompanion(bool nullToAbsent) {
    return LastSyncStateCompanion(
      channelId: Value(channelId),
      lastStartedAt: lastStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStartedAt),
      lastCompletedAt: lastCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCompletedAt),
      pendingUp: pendingUp == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingUp),
      pendingDown: pendingDown == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingDown),
      summaryJson: summaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryJson),
    );
  }

  factory LastSyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LastSyncStateData(
      channelId: serializer.fromJson<int>(json['channelId']),
      lastStartedAt: serializer.fromJson<int?>(json['lastStartedAt']),
      lastCompletedAt: serializer.fromJson<int?>(json['lastCompletedAt']),
      pendingUp: serializer.fromJson<int?>(json['pendingUp']),
      pendingDown: serializer.fromJson<int?>(json['pendingDown']),
      summaryJson: serializer.fromJson<String?>(json['summaryJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'channelId': serializer.toJson<int>(channelId),
      'lastStartedAt': serializer.toJson<int?>(lastStartedAt),
      'lastCompletedAt': serializer.toJson<int?>(lastCompletedAt),
      'pendingUp': serializer.toJson<int?>(pendingUp),
      'pendingDown': serializer.toJson<int?>(pendingDown),
      'summaryJson': serializer.toJson<String?>(summaryJson),
    };
  }

  LastSyncStateData copyWith({
    int? channelId,
    Value<int?> lastStartedAt = const Value.absent(),
    Value<int?> lastCompletedAt = const Value.absent(),
    Value<int?> pendingUp = const Value.absent(),
    Value<int?> pendingDown = const Value.absent(),
    Value<String?> summaryJson = const Value.absent(),
  }) => LastSyncStateData(
    channelId: channelId ?? this.channelId,
    lastStartedAt: lastStartedAt.present
        ? lastStartedAt.value
        : this.lastStartedAt,
    lastCompletedAt: lastCompletedAt.present
        ? lastCompletedAt.value
        : this.lastCompletedAt,
    pendingUp: pendingUp.present ? pendingUp.value : this.pendingUp,
    pendingDown: pendingDown.present ? pendingDown.value : this.pendingDown,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
  );
  LastSyncStateData copyWithCompanion(LastSyncStateCompanion data) {
    return LastSyncStateData(
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      lastStartedAt: data.lastStartedAt.present
          ? data.lastStartedAt.value
          : this.lastStartedAt,
      lastCompletedAt: data.lastCompletedAt.present
          ? data.lastCompletedAt.value
          : this.lastCompletedAt,
      pendingUp: data.pendingUp.present ? data.pendingUp.value : this.pendingUp,
      pendingDown: data.pendingDown.present
          ? data.pendingDown.value
          : this.pendingDown,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LastSyncStateData(')
          ..write('channelId: $channelId, ')
          ..write('lastStartedAt: $lastStartedAt, ')
          ..write('lastCompletedAt: $lastCompletedAt, ')
          ..write('pendingUp: $pendingUp, ')
          ..write('pendingDown: $pendingDown, ')
          ..write('summaryJson: $summaryJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    channelId,
    lastStartedAt,
    lastCompletedAt,
    pendingUp,
    pendingDown,
    summaryJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LastSyncStateData &&
          other.channelId == this.channelId &&
          other.lastStartedAt == this.lastStartedAt &&
          other.lastCompletedAt == this.lastCompletedAt &&
          other.pendingUp == this.pendingUp &&
          other.pendingDown == this.pendingDown &&
          other.summaryJson == this.summaryJson);
}

class LastSyncStateCompanion extends UpdateCompanion<LastSyncStateData> {
  final Value<int> channelId;
  final Value<int?> lastStartedAt;
  final Value<int?> lastCompletedAt;
  final Value<int?> pendingUp;
  final Value<int?> pendingDown;
  final Value<String?> summaryJson;
  const LastSyncStateCompanion({
    this.channelId = const Value.absent(),
    this.lastStartedAt = const Value.absent(),
    this.lastCompletedAt = const Value.absent(),
    this.pendingUp = const Value.absent(),
    this.pendingDown = const Value.absent(),
    this.summaryJson = const Value.absent(),
  });
  LastSyncStateCompanion.insert({
    this.channelId = const Value.absent(),
    this.lastStartedAt = const Value.absent(),
    this.lastCompletedAt = const Value.absent(),
    this.pendingUp = const Value.absent(),
    this.pendingDown = const Value.absent(),
    this.summaryJson = const Value.absent(),
  });
  static Insertable<LastSyncStateData> custom({
    Expression<int>? channelId,
    Expression<int>? lastStartedAt,
    Expression<int>? lastCompletedAt,
    Expression<int>? pendingUp,
    Expression<int>? pendingDown,
    Expression<String>? summaryJson,
  }) {
    return RawValuesInsertable({
      if (channelId != null) 'channel_id': channelId,
      if (lastStartedAt != null) 'last_started_at': lastStartedAt,
      if (lastCompletedAt != null) 'last_completed_at': lastCompletedAt,
      if (pendingUp != null) 'pending_up': pendingUp,
      if (pendingDown != null) 'pending_down': pendingDown,
      if (summaryJson != null) 'summary_json': summaryJson,
    });
  }

  LastSyncStateCompanion copyWith({
    Value<int>? channelId,
    Value<int?>? lastStartedAt,
    Value<int?>? lastCompletedAt,
    Value<int?>? pendingUp,
    Value<int?>? pendingDown,
    Value<String?>? summaryJson,
  }) {
    return LastSyncStateCompanion(
      channelId: channelId ?? this.channelId,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      pendingUp: pendingUp ?? this.pendingUp,
      pendingDown: pendingDown ?? this.pendingDown,
      summaryJson: summaryJson ?? this.summaryJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (channelId.present) {
      map['channel_id'] = Variable<int>(channelId.value);
    }
    if (lastStartedAt.present) {
      map['last_started_at'] = Variable<int>(lastStartedAt.value);
    }
    if (lastCompletedAt.present) {
      map['last_completed_at'] = Variable<int>(lastCompletedAt.value);
    }
    if (pendingUp.present) {
      map['pending_up'] = Variable<int>(pendingUp.value);
    }
    if (pendingDown.present) {
      map['pending_down'] = Variable<int>(pendingDown.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LastSyncStateCompanion(')
          ..write('channelId: $channelId, ')
          ..write('lastStartedAt: $lastStartedAt, ')
          ..write('lastCompletedAt: $lastCompletedAt, ')
          ..write('pendingUp: $pendingUp, ')
          ..write('pendingDown: $pendingDown, ')
          ..write('summaryJson: $summaryJson')
          ..write(')'))
        .toString();
  }
}

class $TombstonesTable extends Tombstones
    with TableInfo<$TombstonesTable, Tombstone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TombstonesTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<TombstoneKind, String>
  entityKind = GeneratedColumn<String>(
    'entity_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<TombstoneKind>($TombstonesTable.$converterentityKind);
  static const VerificationMeta _entityLocalIdMeta = const VerificationMeta(
    'entityLocalId',
  );
  @override
  late final GeneratedColumn<int> entityLocalId = GeneratedColumn<int>(
    'entity_local_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedByDeviceMeta = const VerificationMeta(
    'deletedByDevice',
  );
  @override
  late final GeneratedColumn<String> deletedByDevice = GeneratedColumn<String>(
    'deleted_by_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteClearedAtMeta = const VerificationMeta(
    'remoteClearedAt',
  );
  @override
  late final GeneratedColumn<int> remoteClearedAt = GeneratedColumn<int>(
    'remote_cleared_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityKind,
    entityLocalId,
    deletedAt,
    deletedByDevice,
    remoteClearedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_local_id')) {
      context.handle(
        _entityLocalIdMeta,
        entityLocalId.isAcceptableOrUnknown(
          data['entity_local_id']!,
          _entityLocalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityLocalIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    if (data.containsKey('deleted_by_device')) {
      context.handle(
        _deletedByDeviceMeta,
        deletedByDevice.isAcceptableOrUnknown(
          data['deleted_by_device']!,
          _deletedByDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deletedByDeviceMeta);
    }
    if (data.containsKey('remote_cleared_at')) {
      context.handle(
        _remoteClearedAtMeta,
        remoteClearedAt.isAcceptableOrUnknown(
          data['remote_cleared_at']!,
          _remoteClearedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tombstone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tombstone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityKind: $TombstonesTable.$converterentityKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}entity_kind'],
        )!,
      ),
      entityLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_local_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      )!,
      deletedByDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_by_device'],
      )!,
      remoteClearedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_cleared_at'],
      ),
    );
  }

  @override
  $TombstonesTable createAlias(String alias) {
    return $TombstonesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TombstoneKind, String, String>
  $converterentityKind = const EnumNameConverter<TombstoneKind>(
    TombstoneKind.values,
  );
}

class Tombstone extends DataClass implements Insertable<Tombstone> {
  final int id;
  final TombstoneKind entityKind;
  final int entityLocalId;
  final int deletedAt;
  final String deletedByDevice;
  final int? remoteClearedAt;
  const Tombstone({
    required this.id,
    required this.entityKind,
    required this.entityLocalId,
    required this.deletedAt,
    required this.deletedByDevice,
    this.remoteClearedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['entity_kind'] = Variable<String>(
        $TombstonesTable.$converterentityKind.toSql(entityKind),
      );
    }
    map['entity_local_id'] = Variable<int>(entityLocalId);
    map['deleted_at'] = Variable<int>(deletedAt);
    map['deleted_by_device'] = Variable<String>(deletedByDevice);
    if (!nullToAbsent || remoteClearedAt != null) {
      map['remote_cleared_at'] = Variable<int>(remoteClearedAt);
    }
    return map;
  }

  TombstonesCompanion toCompanion(bool nullToAbsent) {
    return TombstonesCompanion(
      id: Value(id),
      entityKind: Value(entityKind),
      entityLocalId: Value(entityLocalId),
      deletedAt: Value(deletedAt),
      deletedByDevice: Value(deletedByDevice),
      remoteClearedAt: remoteClearedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteClearedAt),
    );
  }

  factory Tombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tombstone(
      id: serializer.fromJson<int>(json['id']),
      entityKind: $TombstonesTable.$converterentityKind.fromJson(
        serializer.fromJson<String>(json['entityKind']),
      ),
      entityLocalId: serializer.fromJson<int>(json['entityLocalId']),
      deletedAt: serializer.fromJson<int>(json['deletedAt']),
      deletedByDevice: serializer.fromJson<String>(json['deletedByDevice']),
      remoteClearedAt: serializer.fromJson<int?>(json['remoteClearedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityKind': serializer.toJson<String>(
        $TombstonesTable.$converterentityKind.toJson(entityKind),
      ),
      'entityLocalId': serializer.toJson<int>(entityLocalId),
      'deletedAt': serializer.toJson<int>(deletedAt),
      'deletedByDevice': serializer.toJson<String>(deletedByDevice),
      'remoteClearedAt': serializer.toJson<int?>(remoteClearedAt),
    };
  }

  Tombstone copyWith({
    int? id,
    TombstoneKind? entityKind,
    int? entityLocalId,
    int? deletedAt,
    String? deletedByDevice,
    Value<int?> remoteClearedAt = const Value.absent(),
  }) => Tombstone(
    id: id ?? this.id,
    entityKind: entityKind ?? this.entityKind,
    entityLocalId: entityLocalId ?? this.entityLocalId,
    deletedAt: deletedAt ?? this.deletedAt,
    deletedByDevice: deletedByDevice ?? this.deletedByDevice,
    remoteClearedAt: remoteClearedAt.present
        ? remoteClearedAt.value
        : this.remoteClearedAt,
  );
  Tombstone copyWithCompanion(TombstonesCompanion data) {
    return Tombstone(
      id: data.id.present ? data.id.value : this.id,
      entityKind: data.entityKind.present
          ? data.entityKind.value
          : this.entityKind,
      entityLocalId: data.entityLocalId.present
          ? data.entityLocalId.value
          : this.entityLocalId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedByDevice: data.deletedByDevice.present
          ? data.deletedByDevice.value
          : this.deletedByDevice,
      remoteClearedAt: data.remoteClearedAt.present
          ? data.remoteClearedAt.value
          : this.remoteClearedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tombstone(')
          ..write('id: $id, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityLocalId: $entityLocalId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedByDevice: $deletedByDevice, ')
          ..write('remoteClearedAt: $remoteClearedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityKind,
    entityLocalId,
    deletedAt,
    deletedByDevice,
    remoteClearedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tombstone &&
          other.id == this.id &&
          other.entityKind == this.entityKind &&
          other.entityLocalId == this.entityLocalId &&
          other.deletedAt == this.deletedAt &&
          other.deletedByDevice == this.deletedByDevice &&
          other.remoteClearedAt == this.remoteClearedAt);
}

class TombstonesCompanion extends UpdateCompanion<Tombstone> {
  final Value<int> id;
  final Value<TombstoneKind> entityKind;
  final Value<int> entityLocalId;
  final Value<int> deletedAt;
  final Value<String> deletedByDevice;
  final Value<int?> remoteClearedAt;
  const TombstonesCompanion({
    this.id = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.entityLocalId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedByDevice = const Value.absent(),
    this.remoteClearedAt = const Value.absent(),
  });
  TombstonesCompanion.insert({
    this.id = const Value.absent(),
    required TombstoneKind entityKind,
    required int entityLocalId,
    required int deletedAt,
    required String deletedByDevice,
    this.remoteClearedAt = const Value.absent(),
  }) : entityKind = Value(entityKind),
       entityLocalId = Value(entityLocalId),
       deletedAt = Value(deletedAt),
       deletedByDevice = Value(deletedByDevice);
  static Insertable<Tombstone> custom({
    Expression<int>? id,
    Expression<String>? entityKind,
    Expression<int>? entityLocalId,
    Expression<int>? deletedAt,
    Expression<String>? deletedByDevice,
    Expression<int>? remoteClearedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityKind != null) 'entity_kind': entityKind,
      if (entityLocalId != null) 'entity_local_id': entityLocalId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedByDevice != null) 'deleted_by_device': deletedByDevice,
      if (remoteClearedAt != null) 'remote_cleared_at': remoteClearedAt,
    });
  }

  TombstonesCompanion copyWith({
    Value<int>? id,
    Value<TombstoneKind>? entityKind,
    Value<int>? entityLocalId,
    Value<int>? deletedAt,
    Value<String>? deletedByDevice,
    Value<int?>? remoteClearedAt,
  }) {
    return TombstonesCompanion(
      id: id ?? this.id,
      entityKind: entityKind ?? this.entityKind,
      entityLocalId: entityLocalId ?? this.entityLocalId,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedByDevice: deletedByDevice ?? this.deletedByDevice,
      remoteClearedAt: remoteClearedAt ?? this.remoteClearedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityKind.present) {
      map['entity_kind'] = Variable<String>(
        $TombstonesTable.$converterentityKind.toSql(entityKind.value),
      );
    }
    if (entityLocalId.present) {
      map['entity_local_id'] = Variable<int>(entityLocalId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deletedByDevice.present) {
      map['deleted_by_device'] = Variable<String>(deletedByDevice.value);
    }
    if (remoteClearedAt.present) {
      map['remote_cleared_at'] = Variable<int>(remoteClearedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TombstonesCompanion(')
          ..write('id: $id, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityLocalId: $entityLocalId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedByDevice: $deletedByDevice, ')
          ..write('remoteClearedAt: $remoteClearedAt')
          ..write(')'))
        .toString();
  }
}

class $ConflictCopiesTable extends ConflictCopies
    with TableInfo<$ConflictCopiesTable, ConflictCopy> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictCopiesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _originKindMeta = const VerificationMeta(
    'originKind',
  );
  @override
  late final GeneratedColumn<String> originKind = GeneratedColumn<String>(
    'origin_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originLocalIdMeta = const VerificationMeta(
    'originLocalId',
  );
  @override
  late final GeneratedColumn<int> originLocalId = GeneratedColumn<int>(
    'origin_local_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _winnerValueJsonMeta = const VerificationMeta(
    'winnerValueJson',
  );
  @override
  late final GeneratedColumn<String> winnerValueJson = GeneratedColumn<String>(
    'winner_value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loserPayloadJsonMeta = const VerificationMeta(
    'loserPayloadJson',
  );
  @override
  late final GeneratedColumn<String> loserPayloadJson = GeneratedColumn<String>(
    'loser_payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lostAtMeta = const VerificationMeta('lostAt');
  @override
  late final GeneratedColumn<int> lostAt = GeneratedColumn<int>(
    'lost_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    originKind,
    originLocalId,
    winnerValueJson,
    loserPayloadJson,
    lostAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflict_copies';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConflictCopy> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('origin_kind')) {
      context.handle(
        _originKindMeta,
        originKind.isAcceptableOrUnknown(data['origin_kind']!, _originKindMeta),
      );
    } else if (isInserting) {
      context.missing(_originKindMeta);
    }
    if (data.containsKey('origin_local_id')) {
      context.handle(
        _originLocalIdMeta,
        originLocalId.isAcceptableOrUnknown(
          data['origin_local_id']!,
          _originLocalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originLocalIdMeta);
    }
    if (data.containsKey('winner_value_json')) {
      context.handle(
        _winnerValueJsonMeta,
        winnerValueJson.isAcceptableOrUnknown(
          data['winner_value_json']!,
          _winnerValueJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_winnerValueJsonMeta);
    }
    if (data.containsKey('loser_payload_json')) {
      context.handle(
        _loserPayloadJsonMeta,
        loserPayloadJson.isAcceptableOrUnknown(
          data['loser_payload_json']!,
          _loserPayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_loserPayloadJsonMeta);
    }
    if (data.containsKey('lost_at')) {
      context.handle(
        _lostAtMeta,
        lostAt.isAcceptableOrUnknown(data['lost_at']!, _lostAtMeta),
      );
    } else if (isInserting) {
      context.missing(_lostAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConflictCopy map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConflictCopy(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      originKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_kind'],
      )!,
      originLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}origin_local_id'],
      )!,
      winnerValueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}winner_value_json'],
      )!,
      loserPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loser_payload_json'],
      )!,
      lostAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lost_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ConflictCopiesTable createAlias(String alias) {
    return $ConflictCopiesTable(attachedDatabase, alias);
  }
}

class ConflictCopy extends DataClass implements Insertable<ConflictCopy> {
  final int id;
  final String originKind;
  final int originLocalId;
  final String winnerValueJson;
  final String loserPayloadJson;
  final int lostAt;
  final int? deletedAt;
  const ConflictCopy({
    required this.id,
    required this.originKind,
    required this.originLocalId,
    required this.winnerValueJson,
    required this.loserPayloadJson,
    required this.lostAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['origin_kind'] = Variable<String>(originKind);
    map['origin_local_id'] = Variable<int>(originLocalId);
    map['winner_value_json'] = Variable<String>(winnerValueJson);
    map['loser_payload_json'] = Variable<String>(loserPayloadJson);
    map['lost_at'] = Variable<int>(lostAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  ConflictCopiesCompanion toCompanion(bool nullToAbsent) {
    return ConflictCopiesCompanion(
      id: Value(id),
      originKind: Value(originKind),
      originLocalId: Value(originLocalId),
      winnerValueJson: Value(winnerValueJson),
      loserPayloadJson: Value(loserPayloadJson),
      lostAt: Value(lostAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ConflictCopy.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConflictCopy(
      id: serializer.fromJson<int>(json['id']),
      originKind: serializer.fromJson<String>(json['originKind']),
      originLocalId: serializer.fromJson<int>(json['originLocalId']),
      winnerValueJson: serializer.fromJson<String>(json['winnerValueJson']),
      loserPayloadJson: serializer.fromJson<String>(json['loserPayloadJson']),
      lostAt: serializer.fromJson<int>(json['lostAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'originKind': serializer.toJson<String>(originKind),
      'originLocalId': serializer.toJson<int>(originLocalId),
      'winnerValueJson': serializer.toJson<String>(winnerValueJson),
      'loserPayloadJson': serializer.toJson<String>(loserPayloadJson),
      'lostAt': serializer.toJson<int>(lostAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  ConflictCopy copyWith({
    int? id,
    String? originKind,
    int? originLocalId,
    String? winnerValueJson,
    String? loserPayloadJson,
    int? lostAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => ConflictCopy(
    id: id ?? this.id,
    originKind: originKind ?? this.originKind,
    originLocalId: originLocalId ?? this.originLocalId,
    winnerValueJson: winnerValueJson ?? this.winnerValueJson,
    loserPayloadJson: loserPayloadJson ?? this.loserPayloadJson,
    lostAt: lostAt ?? this.lostAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ConflictCopy copyWithCompanion(ConflictCopiesCompanion data) {
    return ConflictCopy(
      id: data.id.present ? data.id.value : this.id,
      originKind: data.originKind.present
          ? data.originKind.value
          : this.originKind,
      originLocalId: data.originLocalId.present
          ? data.originLocalId.value
          : this.originLocalId,
      winnerValueJson: data.winnerValueJson.present
          ? data.winnerValueJson.value
          : this.winnerValueJson,
      loserPayloadJson: data.loserPayloadJson.present
          ? data.loserPayloadJson.value
          : this.loserPayloadJson,
      lostAt: data.lostAt.present ? data.lostAt.value : this.lostAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConflictCopy(')
          ..write('id: $id, ')
          ..write('originKind: $originKind, ')
          ..write('originLocalId: $originLocalId, ')
          ..write('winnerValueJson: $winnerValueJson, ')
          ..write('loserPayloadJson: $loserPayloadJson, ')
          ..write('lostAt: $lostAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    originKind,
    originLocalId,
    winnerValueJson,
    loserPayloadJson,
    lostAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictCopy &&
          other.id == this.id &&
          other.originKind == this.originKind &&
          other.originLocalId == this.originLocalId &&
          other.winnerValueJson == this.winnerValueJson &&
          other.loserPayloadJson == this.loserPayloadJson &&
          other.lostAt == this.lostAt &&
          other.deletedAt == this.deletedAt);
}

class ConflictCopiesCompanion extends UpdateCompanion<ConflictCopy> {
  final Value<int> id;
  final Value<String> originKind;
  final Value<int> originLocalId;
  final Value<String> winnerValueJson;
  final Value<String> loserPayloadJson;
  final Value<int> lostAt;
  final Value<int?> deletedAt;
  const ConflictCopiesCompanion({
    this.id = const Value.absent(),
    this.originKind = const Value.absent(),
    this.originLocalId = const Value.absent(),
    this.winnerValueJson = const Value.absent(),
    this.loserPayloadJson = const Value.absent(),
    this.lostAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  ConflictCopiesCompanion.insert({
    this.id = const Value.absent(),
    required String originKind,
    required int originLocalId,
    required String winnerValueJson,
    required String loserPayloadJson,
    required int lostAt,
    this.deletedAt = const Value.absent(),
  }) : originKind = Value(originKind),
       originLocalId = Value(originLocalId),
       winnerValueJson = Value(winnerValueJson),
       loserPayloadJson = Value(loserPayloadJson),
       lostAt = Value(lostAt);
  static Insertable<ConflictCopy> custom({
    Expression<int>? id,
    Expression<String>? originKind,
    Expression<int>? originLocalId,
    Expression<String>? winnerValueJson,
    Expression<String>? loserPayloadJson,
    Expression<int>? lostAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (originKind != null) 'origin_kind': originKind,
      if (originLocalId != null) 'origin_local_id': originLocalId,
      if (winnerValueJson != null) 'winner_value_json': winnerValueJson,
      if (loserPayloadJson != null) 'loser_payload_json': loserPayloadJson,
      if (lostAt != null) 'lost_at': lostAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  ConflictCopiesCompanion copyWith({
    Value<int>? id,
    Value<String>? originKind,
    Value<int>? originLocalId,
    Value<String>? winnerValueJson,
    Value<String>? loserPayloadJson,
    Value<int>? lostAt,
    Value<int?>? deletedAt,
  }) {
    return ConflictCopiesCompanion(
      id: id ?? this.id,
      originKind: originKind ?? this.originKind,
      originLocalId: originLocalId ?? this.originLocalId,
      winnerValueJson: winnerValueJson ?? this.winnerValueJson,
      loserPayloadJson: loserPayloadJson ?? this.loserPayloadJson,
      lostAt: lostAt ?? this.lostAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (originKind.present) {
      map['origin_kind'] = Variable<String>(originKind.value);
    }
    if (originLocalId.present) {
      map['origin_local_id'] = Variable<int>(originLocalId.value);
    }
    if (winnerValueJson.present) {
      map['winner_value_json'] = Variable<String>(winnerValueJson.value);
    }
    if (loserPayloadJson.present) {
      map['loser_payload_json'] = Variable<String>(loserPayloadJson.value);
    }
    if (lostAt.present) {
      map['lost_at'] = Variable<int>(lostAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictCopiesCompanion(')
          ..write('id: $id, ')
          ..write('originKind: $originKind, ')
          ..write('originLocalId: $originLocalId, ')
          ..write('winnerValueJson: $winnerValueJson, ')
          ..write('loserPayloadJson: $loserPayloadJson, ')
          ..write('lostAt: $lostAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  final int updatedAt;
  const Setting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Setting copyWith({String? key, String? value, int? updatedAt}) => Setting(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$IaDatabase extends GeneratedDatabase {
  _$IaDatabase(QueryExecutor e) : super(e);
  $IaDatabaseManager get managers => $IaDatabaseManager(this);
  late final $RepositoryRootsTable repositoryRoots = $RepositoryRootsTable(
    this,
  );
  late final $ArtistsTable artists = $ArtistsTable(this);
  late final $AlbumsTable albums = $AlbumsTable(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  late final $PlayHistoryTable playHistory = $PlayHistoryTable(this);
  late final $FewWatchListTable fewWatchList = $FewWatchListTable(this);
  late final $LyricsMetaTable lyricsMeta = $LyricsMetaTable(this);
  late final $ModelRegistryTable modelRegistry = $ModelRegistryTable(this);
  late final $LyricsGenJobsTable lyricsGenJobs = $LyricsGenJobsTable(this);
  late final $ExtractTasksTable extractTasks = $ExtractTasksTable(this);
  late final $SyncChannelTable syncChannel = $SyncChannelTable(this);
  late final $LastSyncStateTable lastSyncState = $LastSyncStateTable(this);
  late final $TombstonesTable tombstones = $TombstonesTable(this);
  late final $ConflictCopiesTable conflictCopies = $ConflictCopiesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index idxRootPath = Index(
    'idx_root_path',
    'CREATE INDEX idx_root_path ON repository_roots (path)',
  );
  late final Index idxTrackAlbum = Index(
    'idx_track_album',
    'CREATE INDEX idx_track_album ON tracks (album_id)',
  );
  late final Index idxTrackArtist = Index(
    'idx_track_artist',
    'CREATE INDEX idx_track_artist ON tracks (artist_id)',
  );
  late final Index idxTrackSource = Index(
    'idx_track_source',
    'CREATE INDEX idx_track_source ON tracks (source_type, source_id)',
  );
  late final Index idxPtPos = Index(
    'idx_pt_pos',
    'CREATE INDEX idx_pt_pos ON playlist_tracks (playlist_id, position)',
  );
  late final Index idxTombKindTime = Index(
    'idx_tomb_kind_time',
    'CREATE INDEX idx_tomb_kind_time ON tombstones (entity_kind, deleted_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    repositoryRoots,
    artists,
    albums,
    tracks,
    playlists,
    playlistTracks,
    playHistory,
    fewWatchList,
    lyricsMeta,
    modelRegistry,
    lyricsGenJobs,
    extractTasks,
    syncChannel,
    lastSyncState,
    tombstones,
    conflictCopies,
    settings,
    idxRootPath,
    idxTrackAlbum,
    idxTrackArtist,
    idxTrackSource,
    idxPtPos,
    idxTombKindTime,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('lyrics_gen_jobs', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RepositoryRootsTableCreateCompanionBuilder =
    RepositoryRootsCompanion Function({
      Value<int> id,
      required String path,
      Value<String?> label,
      required RepositoryMode mode,
      required int addedAt,
    });
typedef $$RepositoryRootsTableUpdateCompanionBuilder =
    RepositoryRootsCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<String?> label,
      Value<RepositoryMode> mode,
      Value<int> addedAt,
    });

final class $$RepositoryRootsTableReferences
    extends
        BaseReferences<_$IaDatabase, $RepositoryRootsTable, RepositoryRoot> {
  $$RepositoryRootsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TracksTable, List<Track>> _tracksRefsTable(
    _$IaDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: 'repository_roots__id__tracks__root_id',
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.rootId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RepositoryRootsTableFilterComposer
    extends Composer<_$IaDatabase, $RepositoryRootsTable> {
  $$RepositoryRootsTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RepositoryMode, RepositoryMode, String>
  get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.rootId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepositoryRootsTableOrderingComposer
    extends Composer<_$IaDatabase, $RepositoryRootsTable> {
  $$RepositoryRootsTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepositoryRootsTableAnnotationComposer
    extends Composer<_$IaDatabase, $RepositoryRootsTable> {
  $$RepositoryRootsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RepositoryMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.rootId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepositoryRootsTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $RepositoryRootsTable,
          RepositoryRoot,
          $$RepositoryRootsTableFilterComposer,
          $$RepositoryRootsTableOrderingComposer,
          $$RepositoryRootsTableAnnotationComposer,
          $$RepositoryRootsTableCreateCompanionBuilder,
          $$RepositoryRootsTableUpdateCompanionBuilder,
          (RepositoryRoot, $$RepositoryRootsTableReferences),
          RepositoryRoot,
          PrefetchHooks Function({bool tracksRefs})
        > {
  $$RepositoryRootsTableTableManager(
    _$IaDatabase db,
    $RepositoryRootsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepositoryRootsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepositoryRootsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepositoryRootsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<RepositoryMode> mode = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
              }) => RepositoryRootsCompanion(
                id: id,
                path: path,
                label: label,
                mode: mode,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                Value<String?> label = const Value.absent(),
                required RepositoryMode mode,
                required int addedAt,
              }) => RepositoryRootsCompanion.insert(
                id: id,
                path: path,
                label: label,
                mode: mode,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RepositoryRootsTable, RepositoryRoot>(table),
                  $$RepositoryRootsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tracksRefs) db.tracks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tracksRefs)
                    await $_getPrefetchedData<
                      RepositoryRoot,
                      $RepositoryRootsTable,
                      Track
                    >(
                      currentTable: table,
                      referencedTable: $$RepositoryRootsTableReferences
                          ._tracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RepositoryRootsTableReferences(
                            db,
                            table,
                            p0,
                          ).tracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.rootId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RepositoryRootsTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $RepositoryRootsTable,
      RepositoryRoot,
      $$RepositoryRootsTableFilterComposer,
      $$RepositoryRootsTableOrderingComposer,
      $$RepositoryRootsTableAnnotationComposer,
      $$RepositoryRootsTableCreateCompanionBuilder,
      $$RepositoryRootsTableUpdateCompanionBuilder,
      (RepositoryRoot, $$RepositoryRootsTableReferences),
      RepositoryRoot,
      PrefetchHooks Function({bool tracksRefs})
    >;
typedef $$ArtistsTableCreateCompanionBuilder = ArtistsCompanion Function({
  Value<int> id,
  required String name,
  required String nameNorm,
  Value<String?> sortKey,
  required int updatedAt,
});
typedef $$ArtistsTableUpdateCompanionBuilder = ArtistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> nameNorm,
  Value<String?> sortKey,
  Value<int> updatedAt,
});

final class $$ArtistsTableReferences
    extends BaseReferences<_$IaDatabase, $ArtistsTable, Artist> {
  $$ArtistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TracksTable, List<Track>> _tracksRefsTable(
    _$IaDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: 'artists__id__tracks__artist_id',
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArtistsTableFilterComposer
    extends Composer<_$IaDatabase, $ArtistsTable> {
  $$ArtistsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameNorm => $composableBuilder(
    column: $table.nameNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArtistsTableOrderingComposer
    extends Composer<_$IaDatabase, $ArtistsTable> {
  $$ArtistsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameNorm => $composableBuilder(
    column: $table.nameNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistsTableAnnotationComposer
    extends Composer<_$IaDatabase, $ArtistsTable> {
  $$ArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameNorm =>
      $composableBuilder(column: $table.nameNorm, builder: (column) => column);

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArtistsTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $ArtistsTable,
          Artist,
          $$ArtistsTableFilterComposer,
          $$ArtistsTableOrderingComposer,
          $$ArtistsTableAnnotationComposer,
          $$ArtistsTableCreateCompanionBuilder,
          $$ArtistsTableUpdateCompanionBuilder,
          (Artist, $$ArtistsTableReferences),
          Artist,
          PrefetchHooks Function({bool tracksRefs})
        > {
  $$ArtistsTableTableManager(_$IaDatabase db, $ArtistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameNorm = const Value.absent(),
                Value<String?> sortKey = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => ArtistsCompanion(
                id: id,
                name: name,
                nameNorm: nameNorm,
                sortKey: sortKey,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String nameNorm,
                Value<String?> sortKey = const Value.absent(),
                required int updatedAt,
              }) => ArtistsCompanion.insert(
                id: id,
                name: name,
                nameNorm: nameNorm,
                sortKey: sortKey,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtistsTable, Artist>(table),
                  $$ArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tracksRefs) db.tracks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tracksRefs)
                    await $_getPrefetchedData<Artist, $ArtistsTable, Track>(
                      currentTable: table,
                      referencedTable: $$ArtistsTableReferences
                          ._tracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ArtistsTableReferences(db, table, p0).tracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.artistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $ArtistsTable,
      Artist,
      $$ArtistsTableFilterComposer,
      $$ArtistsTableOrderingComposer,
      $$ArtistsTableAnnotationComposer,
      $$ArtistsTableCreateCompanionBuilder,
      $$ArtistsTableUpdateCompanionBuilder,
      (Artist, $$ArtistsTableReferences),
      Artist,
      PrefetchHooks Function({bool tracksRefs})
    >;
typedef $$AlbumsTableCreateCompanionBuilder = AlbumsCompanion Function({
  Value<int> id,
  required String name,
  required String nameNorm,
  Value<String?> sortKey,
  required int updatedAt,
});
typedef $$AlbumsTableUpdateCompanionBuilder = AlbumsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> nameNorm,
  Value<String?> sortKey,
  Value<int> updatedAt,
});

final class $$AlbumsTableReferences
    extends BaseReferences<_$IaDatabase, $AlbumsTable, Album> {
  $$AlbumsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TracksTable, List<Track>> _tracksRefsTable(
    _$IaDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: 'albums__id__tracks__album_id',
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.albumId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlbumsTableFilterComposer extends Composer<_$IaDatabase, $AlbumsTable> {
  $$AlbumsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameNorm => $composableBuilder(
    column: $table.nameNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableOrderingComposer
    extends Composer<_$IaDatabase, $AlbumsTable> {
  $$AlbumsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameNorm => $composableBuilder(
    column: $table.nameNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlbumsTableAnnotationComposer
    extends Composer<_$IaDatabase, $AlbumsTable> {
  $$AlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameNorm =>
      $composableBuilder(column: $table.nameNorm, builder: (column) => column);

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $AlbumsTable,
          Album,
          $$AlbumsTableFilterComposer,
          $$AlbumsTableOrderingComposer,
          $$AlbumsTableAnnotationComposer,
          $$AlbumsTableCreateCompanionBuilder,
          $$AlbumsTableUpdateCompanionBuilder,
          (Album, $$AlbumsTableReferences),
          Album,
          PrefetchHooks Function({bool tracksRefs})
        > {
  $$AlbumsTableTableManager(_$IaDatabase db, $AlbumsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameNorm = const Value.absent(),
                Value<String?> sortKey = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => AlbumsCompanion(
                id: id,
                name: name,
                nameNorm: nameNorm,
                sortKey: sortKey,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String nameNorm,
                Value<String?> sortKey = const Value.absent(),
                required int updatedAt,
              }) => AlbumsCompanion.insert(
                id: id,
                name: name,
                nameNorm: nameNorm,
                sortKey: sortKey,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AlbumsTable, Album>(table),
                  $$AlbumsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tracksRefs) db.tracks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tracksRefs)
                    await $_getPrefetchedData<Album, $AlbumsTable, Track>(
                      currentTable: table,
                      referencedTable: $$AlbumsTableReferences._tracksRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$AlbumsTableReferences(db, table, p0).tracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.albumId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $AlbumsTable,
      Album,
      $$AlbumsTableFilterComposer,
      $$AlbumsTableOrderingComposer,
      $$AlbumsTableAnnotationComposer,
      $$AlbumsTableCreateCompanionBuilder,
      $$AlbumsTableUpdateCompanionBuilder,
      (Album, $$AlbumsTableReferences),
      Album,
      PrefetchHooks Function({bool tracksRefs})
    >;
typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  required int rootId,
  required String relPath,
  Value<String?> title,
  Value<String?> artistDisplay,
  Value<String?> albumDisplay,
  Value<int?> artistId,
  Value<int?> albumId,
  Value<int?> durationMs,
  required AudioFormatSpec audioFormat,
  required int fileSize,
  required int mtime,
  required String contentHash,
  Value<String?> sourceType,
  Value<String?> sourceId,
  Value<int?> sampleRate,
  Value<int?> channels,
  required int addedAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int?> missingAt,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<int> rootId,
  Value<String> relPath,
  Value<String?> title,
  Value<String?> artistDisplay,
  Value<String?> albumDisplay,
  Value<int?> artistId,
  Value<int?> albumId,
  Value<int?> durationMs,
  Value<AudioFormatSpec> audioFormat,
  Value<int> fileSize,
  Value<int> mtime,
  Value<String> contentHash,
  Value<String?> sourceType,
  Value<String?> sourceId,
  Value<int?> sampleRate,
  Value<int?> channels,
  Value<int> addedAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int?> missingAt,
});

final class $$TracksTableReferences
    extends BaseReferences<_$IaDatabase, $TracksTable, Track> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RepositoryRootsTable _rootIdTable(_$IaDatabase db) =>
      db.repositoryRoots.createAlias('tracks__root_id__repository_roots__id');

  $$RepositoryRootsTableProcessedTableManager get rootId {
    final $_column = $_itemColumn<int>('root_id')!;

    final manager = $$RepositoryRootsTableTableManager(
      $_db,
      $_db.repositoryRoots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rootIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ArtistsTable _artistIdTable(_$IaDatabase db) =>
      db.artists.createAlias('tracks__artist_id__artists__id');

  $$ArtistsTableProcessedTableManager? get artistId {
    final $_column = $_itemColumn<int>('artist_id');
    if ($_column == null) return null;
    final manager = $$ArtistsTableTableManager(
      $_db,
      $_db.artists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AlbumsTable _albumIdTable(_$IaDatabase db) =>
      db.albums.createAlias('tracks__album_id__albums__id');

  $$AlbumsTableProcessedTableManager? get albumId {
    final $_column = $_itemColumn<int>('album_id');
    if ($_column == null) return null;
    final manager = $$AlbumsTableTableManager(
      $_db,
      $_db.albums,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_albumIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrack>>
  _playlistTracksRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistTracks,
    aliasName: 'tracks__id__playlist_tracks__track_id',
  );

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager(
      $_db,
      $_db.playlistTracks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlayHistoryTable, List<PlayHistoryData>>
  _playHistoryRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.playHistory,
    aliasName: 'tracks__id__play_history__track_id',
  );

  $$PlayHistoryTableProcessedTableManager get playHistoryRefs {
    final manager = $$PlayHistoryTableTableManager(
      $_db,
      $_db.playHistory,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playHistoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FewWatchListTable, List<FewWatchListData>>
  _fewWatchListRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.fewWatchList,
    aliasName: 'tracks__id__few_watch_list__track_id',
  );

  $$FewWatchListTableProcessedTableManager get fewWatchListRefs {
    final manager = $$FewWatchListTableTableManager(
      $_db,
      $_db.fewWatchList,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_fewWatchListRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LyricsMetaTable, List<LyricsMetaData>>
  _lyricsMetaRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.lyricsMeta,
    aliasName: 'tracks__id__lyrics_meta__track_id',
  );

  $$LyricsMetaTableProcessedTableManager get lyricsMetaRefs {
    final manager = $$LyricsMetaTableTableManager(
      $_db,
      $_db.lyricsMeta,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lyricsMetaRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LyricsGenJobsTable, List<LyricsGenJob>>
  _lyricsGenJobsRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.lyricsGenJobs,
    aliasName: 'tracks__id__lyrics_gen_jobs__track_id',
  );

  $$LyricsGenJobsTableProcessedTableManager get lyricsGenJobsRefs {
    final manager = $$LyricsGenJobsTableTableManager(
      $_db,
      $_db.lyricsGenJobs,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lyricsGenJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TracksTableFilterComposer extends Composer<_$IaDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
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

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistDisplay => $composableBuilder(
    column: $table.artistDisplay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumDisplay => $composableBuilder(
    column: $table.albumDisplay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AudioFormatSpec, AudioFormatSpec, String>
  get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get missingAt => $composableBuilder(
    column: $table.missingAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RepositoryRootsTableFilterComposer get rootId {
    final $$RepositoryRootsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootId,
      referencedTable: $db.repositoryRoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepositoryRootsTableFilterComposer(
            $db: $db,
            $table: $db.repositoryRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableFilterComposer get artistId {
    final $$ArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableFilterComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableFilterComposer get albumId {
    final $$AlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableFilterComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> playlistTracksRefs(
    Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f,
  ) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playHistoryRefs(
    Expression<bool> Function($$PlayHistoryTableFilterComposer f) f,
  ) {
    final $$PlayHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playHistory,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayHistoryTableFilterComposer(
            $db: $db,
            $table: $db.playHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> fewWatchListRefs(
    Expression<bool> Function($$FewWatchListTableFilterComposer f) f,
  ) {
    final $$FewWatchListTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fewWatchList,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FewWatchListTableFilterComposer(
            $db: $db,
            $table: $db.fewWatchList,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lyricsMetaRefs(
    Expression<bool> Function($$LyricsMetaTableFilterComposer f) f,
  ) {
    final $$LyricsMetaTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyricsMeta,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsMetaTableFilterComposer(
            $db: $db,
            $table: $db.lyricsMeta,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lyricsGenJobsRefs(
    Expression<bool> Function($$LyricsGenJobsTableFilterComposer f) f,
  ) {
    final $$LyricsGenJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyricsGenJobs,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsGenJobsTableFilterComposer(
            $db: $db,
            $table: $db.lyricsGenJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$IaDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
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

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistDisplay => $composableBuilder(
    column: $table.artistDisplay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumDisplay => $composableBuilder(
    column: $table.albumDisplay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get missingAt => $composableBuilder(
    column: $table.missingAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RepositoryRootsTableOrderingComposer get rootId {
    final $$RepositoryRootsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootId,
      referencedTable: $db.repositoryRoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepositoryRootsTableOrderingComposer(
            $db: $db,
            $table: $db.repositoryRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableOrderingComposer get artistId {
    final $$ArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableOrderingComposer get albumId {
    final $$AlbumsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableOrderingComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TracksTableAnnotationComposer
    extends Composer<_$IaDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistDisplay => $composableBuilder(
    column: $table.artistDisplay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumDisplay => $composableBuilder(
    column: $table.albumDisplay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AudioFormatSpec, String> get audioFormat =>
      $composableBuilder(
        column: $table.audioFormat,
        builder: (column) => column,
      );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get missingAt =>
      $composableBuilder(column: $table.missingAt, builder: (column) => column);

  $$RepositoryRootsTableAnnotationComposer get rootId {
    final $$RepositoryRootsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootId,
      referencedTable: $db.repositoryRoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepositoryRootsTableAnnotationComposer(
            $db: $db,
            $table: $db.repositoryRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableAnnotationComposer get artistId {
    final $$ArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableAnnotationComposer get albumId {
    final $$AlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> playlistTracksRefs<T extends Object>(
    Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playHistoryRefs<T extends Object>(
    Expression<T> Function($$PlayHistoryTableAnnotationComposer a) f,
  ) {
    final $$PlayHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playHistory,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.playHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> fewWatchListRefs<T extends Object>(
    Expression<T> Function($$FewWatchListTableAnnotationComposer a) f,
  ) {
    final $$FewWatchListTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fewWatchList,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FewWatchListTableAnnotationComposer(
            $db: $db,
            $table: $db.fewWatchList,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lyricsMetaRefs<T extends Object>(
    Expression<T> Function($$LyricsMetaTableAnnotationComposer a) f,
  ) {
    final $$LyricsMetaTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyricsMeta,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsMetaTableAnnotationComposer(
            $db: $db,
            $table: $db.lyricsMeta,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lyricsGenJobsRefs<T extends Object>(
    Expression<T> Function($$LyricsGenJobsTableAnnotationComposer a) f,
  ) {
    final $$LyricsGenJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyricsGenJobs,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsGenJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.lyricsGenJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $TracksTable,
          Track,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (Track, $$TracksTableReferences),
          Track,
          PrefetchHooks Function({
            bool rootId,
            bool artistId,
            bool albumId,
            bool playlistTracksRefs,
            bool playHistoryRefs,
            bool fewWatchListRefs,
            bool lyricsMetaRefs,
            bool lyricsGenJobsRefs,
          })
        > {
  $$TracksTableTableManager(_$IaDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> rootId = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> artistDisplay = const Value.absent(),
                Value<String?> albumDisplay = const Value.absent(),
                Value<int?> artistId = const Value.absent(),
                Value<int?> albumId = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<AudioFormatSpec> audioFormat = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String?> sourceType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> channels = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int?> missingAt = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                rootId: rootId,
                relPath: relPath,
                title: title,
                artistDisplay: artistDisplay,
                albumDisplay: albumDisplay,
                artistId: artistId,
                albumId: albumId,
                durationMs: durationMs,
                audioFormat: audioFormat,
                fileSize: fileSize,
                mtime: mtime,
                contentHash: contentHash,
                sourceType: sourceType,
                sourceId: sourceId,
                sampleRate: sampleRate,
                channels: channels,
                addedAt: addedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                missingAt: missingAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int rootId,
                required String relPath,
                Value<String?> title = const Value.absent(),
                Value<String?> artistDisplay = const Value.absent(),
                Value<String?> albumDisplay = const Value.absent(),
                Value<int?> artistId = const Value.absent(),
                Value<int?> albumId = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required AudioFormatSpec audioFormat,
                required int fileSize,
                required int mtime,
                required String contentHash,
                Value<String?> sourceType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> channels = const Value.absent(),
                required int addedAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int?> missingAt = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                rootId: rootId,
                relPath: relPath,
                title: title,
                artistDisplay: artistDisplay,
                albumDisplay: albumDisplay,
                artistId: artistId,
                albumId: albumId,
                durationMs: durationMs,
                audioFormat: audioFormat,
                fileSize: fileSize,
                mtime: mtime,
                contentHash: contentHash,
                sourceType: sourceType,
                sourceId: sourceId,
                sampleRate: sampleRate,
                channels: channels,
                addedAt: addedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                missingAt: missingAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, Track>(table),
                  $$TracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                rootId = false,
                artistId = false,
                albumId = false,
                playlistTracksRefs = false,
                playHistoryRefs = false,
                fewWatchListRefs = false,
                lyricsMetaRefs = false,
                lyricsGenJobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistTracksRefs) db.playlistTracks,
                    if (playHistoryRefs) db.playHistory,
                    if (fewWatchListRefs) db.fewWatchList,
                    if (lyricsMetaRefs) db.lyricsMeta,
                    if (lyricsGenJobsRefs) db.lyricsGenJobs,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (rootId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.rootId,
                            referencedTable: $$TracksTableReferences
                                ._rootIdTable(db),
                            referencedColumn: $$TracksTableReferences
                                ._rootIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (artistId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.artistId,
                            referencedTable: $$TracksTableReferences
                                ._artistIdTable(db),
                            referencedColumn: $$TracksTableReferences
                                ._artistIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (albumId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.albumId,
                            referencedTable: $$TracksTableReferences
                                ._albumIdTable(db),
                            referencedColumn: $$TracksTableReferences
                                ._albumIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistTracksRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          PlaylistTrack
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playlistTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playHistoryRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          PlayHistoryData
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (fewWatchListRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          FewWatchListData
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._fewWatchListRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).fewWatchListRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (lyricsMetaRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          LyricsMetaData
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._lyricsMetaRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).lyricsMetaRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (lyricsGenJobsRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          LyricsGenJob
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._lyricsGenJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).lyricsGenJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $TracksTable,
      Track,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (Track, $$TracksTableReferences),
      Track,
      PrefetchHooks Function({
        bool rootId,
        bool artistId,
        bool albumId,
        bool playlistTracksRefs,
        bool playHistoryRefs,
        bool fewWatchListRefs,
        bool lyricsMetaRefs,
        bool lyricsGenJobsRefs,
      })
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  required PlaylistKind kind,
  Value<int> sortOrder,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<PlaylistKind> kind,
  Value<int> sortOrder,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$IaDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrack>>
  _playlistTracksRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistTracks,
    aliasName: 'playlists__id__playlist_tracks__playlist_id',
  );

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager(
      $_db,
      $_db.playlistTracks,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$IaDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PlaylistKind, PlaylistKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistTracksRefs(
    Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f,
  ) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$IaDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$IaDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlaylistKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> playlistTracksRefs<T extends Object>(
    Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({bool playlistTracksRefs})
        > {
  $$PlaylistsTableTableManager(_$IaDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<PlaylistKind> kind = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                kind: kind,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required PlaylistKind kind,
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, Playlist>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistTracksRefs) db.playlistTracks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistTracksRefs)
                    await $_getPrefetchedData<
                      Playlist,
                      $PlaylistsTable,
                      PlaylistTrack
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistTracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistTracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({bool playlistTracksRefs})
    >;
typedef $$PlaylistTracksTableCreateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> id,
      required int playlistId,
      required int trackId,
      required int position,
      required int addedAt,
    });
typedef $$PlaylistTracksTableUpdateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<int> trackId,
      Value<int> position,
      Value<int> addedAt,
    });

final class $$PlaylistTracksTableReferences
    extends BaseReferences<_$IaDatabase, $PlaylistTracksTable, PlaylistTrack> {
  $$PlaylistTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$IaDatabase db) =>
      db.playlists.createAlias('playlist_tracks__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TracksTable _trackIdTable(_$IaDatabase db) =>
      db.tracks.createAlias('playlist_tracks__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistTracksTableFilterComposer
    extends Composer<_$IaDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableOrderingComposer
    extends Composer<_$IaDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableAnnotationComposer
    extends Composer<_$IaDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $PlaylistTracksTable,
          PlaylistTrack,
          $$PlaylistTracksTableFilterComposer,
          $$PlaylistTracksTableOrderingComposer,
          $$PlaylistTracksTableAnnotationComposer,
          $$PlaylistTracksTableCreateCompanionBuilder,
          $$PlaylistTracksTableUpdateCompanionBuilder,
          (PlaylistTrack, $$PlaylistTracksTableReferences),
          PlaylistTrack,
          PrefetchHooks Function({bool playlistId, bool trackId})
        > {
  $$PlaylistTracksTableTableManager(_$IaDatabase db, $PlaylistTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
              }) => PlaylistTracksCompanion(
                id: id,
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required int trackId,
                required int position,
                required int addedAt,
              }) => PlaylistTracksCompanion.insert(
                id: id,
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistTracksTable, PlaylistTrack>(table),
                  $$PlaylistTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistTracksTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistTracksTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlaylistTracksTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlaylistTracksTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $PlaylistTracksTable,
      PlaylistTrack,
      $$PlaylistTracksTableFilterComposer,
      $$PlaylistTracksTableOrderingComposer,
      $$PlaylistTracksTableAnnotationComposer,
      $$PlaylistTracksTableCreateCompanionBuilder,
      $$PlaylistTracksTableUpdateCompanionBuilder,
      (PlaylistTrack, $$PlaylistTracksTableReferences),
      PlaylistTrack,
      PrefetchHooks Function({bool playlistId, bool trackId})
    >;
typedef $$PlayHistoryTableCreateCompanionBuilder =
    PlayHistoryCompanion Function({
      Value<int> id,
      required int trackId,
      required int playedAt,
      required bool completed,
      required String deviceId,
    });
typedef $$PlayHistoryTableUpdateCompanionBuilder =
    PlayHistoryCompanion Function({
      Value<int> id,
      Value<int> trackId,
      Value<int> playedAt,
      Value<bool> completed,
      Value<String> deviceId,
    });

final class $$PlayHistoryTableReferences
    extends BaseReferences<_$IaDatabase, $PlayHistoryTable, PlayHistoryData> {
  $$PlayHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$IaDatabase db) =>
      db.tracks.createAlias('play_history__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlayHistoryTableFilterComposer
    extends Composer<_$IaDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableFilterComposer({
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

  ColumnFilters<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayHistoryTableOrderingComposer
    extends Composer<_$IaDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableOrderingComposer({
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

  ColumnOrderings<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayHistoryTableAnnotationComposer
    extends Composer<_$IaDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayHistoryTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $PlayHistoryTable,
          PlayHistoryData,
          $$PlayHistoryTableFilterComposer,
          $$PlayHistoryTableOrderingComposer,
          $$PlayHistoryTableAnnotationComposer,
          $$PlayHistoryTableCreateCompanionBuilder,
          $$PlayHistoryTableUpdateCompanionBuilder,
          (PlayHistoryData, $$PlayHistoryTableReferences),
          PlayHistoryData,
          PrefetchHooks Function({bool trackId})
        > {
  $$PlayHistoryTableTableManager(_$IaDatabase db, $PlayHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<int> playedAt = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
              }) => PlayHistoryCompanion(
                id: id,
                trackId: trackId,
                playedAt: playedAt,
                completed: completed,
                deviceId: deviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                required int playedAt,
                required bool completed,
                required String deviceId,
              }) => PlayHistoryCompanion.insert(
                id: id,
                trackId: trackId,
                playedAt: playedAt,
                completed: completed,
                deviceId: deviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayHistoryTable, PlayHistoryData>(table),
                  $$PlayHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlayHistoryTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlayHistoryTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlayHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $PlayHistoryTable,
      PlayHistoryData,
      $$PlayHistoryTableFilterComposer,
      $$PlayHistoryTableOrderingComposer,
      $$PlayHistoryTableAnnotationComposer,
      $$PlayHistoryTableCreateCompanionBuilder,
      $$PlayHistoryTableUpdateCompanionBuilder,
      (PlayHistoryData, $$PlayHistoryTableReferences),
      PlayHistoryData,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$FewWatchListTableCreateCompanionBuilder =
    FewWatchListCompanion Function({Value<int> trackId, required int addedAt});
typedef $$FewWatchListTableUpdateCompanionBuilder =
    FewWatchListCompanion Function({Value<int> trackId, Value<int> addedAt});

final class $$FewWatchListTableReferences
    extends BaseReferences<_$IaDatabase, $FewWatchListTable, FewWatchListData> {
  $$FewWatchListTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$IaDatabase db) =>
      db.tracks.createAlias('few_watch_list__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FewWatchListTableFilterComposer
    extends Composer<_$IaDatabase, $FewWatchListTable> {
  $$FewWatchListTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FewWatchListTableOrderingComposer
    extends Composer<_$IaDatabase, $FewWatchListTable> {
  $$FewWatchListTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FewWatchListTableAnnotationComposer
    extends Composer<_$IaDatabase, $FewWatchListTable> {
  $$FewWatchListTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FewWatchListTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $FewWatchListTable,
          FewWatchListData,
          $$FewWatchListTableFilterComposer,
          $$FewWatchListTableOrderingComposer,
          $$FewWatchListTableAnnotationComposer,
          $$FewWatchListTableCreateCompanionBuilder,
          $$FewWatchListTableUpdateCompanionBuilder,
          (FewWatchListData, $$FewWatchListTableReferences),
          FewWatchListData,
          PrefetchHooks Function({bool trackId})
        > {
  $$FewWatchListTableTableManager(_$IaDatabase db, $FewWatchListTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FewWatchListTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FewWatchListTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FewWatchListTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> trackId = const Value.absent(),
            Value<int> addedAt = const Value.absent(),
          }) => FewWatchListCompanion(trackId: trackId, addedAt: addedAt),
          createCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                required int addedAt,
              }) => FewWatchListCompanion.insert(
                trackId: trackId,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FewWatchListTable, FewWatchListData>(table),
                  $$FewWatchListTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$FewWatchListTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$FewWatchListTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FewWatchListTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $FewWatchListTable,
      FewWatchListData,
      $$FewWatchListTableFilterComposer,
      $$FewWatchListTableOrderingComposer,
      $$FewWatchListTableAnnotationComposer,
      $$FewWatchListTableCreateCompanionBuilder,
      $$FewWatchListTableUpdateCompanionBuilder,
      (FewWatchListData, $$FewWatchListTableReferences),
      FewWatchListData,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$LyricsMetaTableCreateCompanionBuilder = LyricsMetaCompanion Function({
  Value<int> trackId,
  required LyricsSourceType type,
  Value<String?> lrcPath,
  Value<String?> sourceText,
  Value<int> offsetMs,
  required int updatedAt,
  Value<bool> edited,
});
typedef $$LyricsMetaTableUpdateCompanionBuilder = LyricsMetaCompanion Function({
  Value<int> trackId,
  Value<LyricsSourceType> type,
  Value<String?> lrcPath,
  Value<String?> sourceText,
  Value<int> offsetMs,
  Value<int> updatedAt,
  Value<bool> edited,
});

final class $$LyricsMetaTableReferences
    extends BaseReferences<_$IaDatabase, $LyricsMetaTable, LyricsMetaData> {
  $$LyricsMetaTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$IaDatabase db) =>
      db.tracks.createAlias('lyrics_meta__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LyricsMetaTableFilterComposer
    extends Composer<_$IaDatabase, $LyricsMetaTable> {
  $$LyricsMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<LyricsSourceType, LyricsSourceType, String>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get lrcPath => $composableBuilder(
    column: $table.lrcPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsMetaTableOrderingComposer
    extends Composer<_$IaDatabase, $LyricsMetaTable> {
  $$LyricsMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lrcPath => $composableBuilder(
    column: $table.lrcPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsMetaTableAnnotationComposer
    extends Composer<_$IaDatabase, $LyricsMetaTable> {
  $$LyricsMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<LyricsSourceType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get lrcPath =>
      $composableBuilder(column: $table.lrcPath, builder: (column) => column);

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offsetMs =>
      $composableBuilder(column: $table.offsetMs, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsMetaTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $LyricsMetaTable,
          LyricsMetaData,
          $$LyricsMetaTableFilterComposer,
          $$LyricsMetaTableOrderingComposer,
          $$LyricsMetaTableAnnotationComposer,
          $$LyricsMetaTableCreateCompanionBuilder,
          $$LyricsMetaTableUpdateCompanionBuilder,
          (LyricsMetaData, $$LyricsMetaTableReferences),
          LyricsMetaData,
          PrefetchHooks Function({bool trackId})
        > {
  $$LyricsMetaTableTableManager(_$IaDatabase db, $LyricsMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<LyricsSourceType> type = const Value.absent(),
                Value<String?> lrcPath = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> edited = const Value.absent(),
              }) => LyricsMetaCompanion(
                trackId: trackId,
                type: type,
                lrcPath: lrcPath,
                sourceText: sourceText,
                offsetMs: offsetMs,
                updatedAt: updatedAt,
                edited: edited,
              ),
          createCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                required LyricsSourceType type,
                Value<String?> lrcPath = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                required int updatedAt,
                Value<bool> edited = const Value.absent(),
              }) => LyricsMetaCompanion.insert(
                trackId: trackId,
                type: type,
                lrcPath: lrcPath,
                sourceText: sourceText,
                offsetMs: offsetMs,
                updatedAt: updatedAt,
                edited: edited,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricsMetaTable, LyricsMetaData>(table),
                  $$LyricsMetaTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$LyricsMetaTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$LyricsMetaTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LyricsMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $LyricsMetaTable,
      LyricsMetaData,
      $$LyricsMetaTableFilterComposer,
      $$LyricsMetaTableOrderingComposer,
      $$LyricsMetaTableAnnotationComposer,
      $$LyricsMetaTableCreateCompanionBuilder,
      $$LyricsMetaTableUpdateCompanionBuilder,
      (LyricsMetaData, $$LyricsMetaTableReferences),
      LyricsMetaData,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$ModelRegistryTableCreateCompanionBuilder =
    ModelRegistryCompanion Function({
      required String modelId,
      Value<int?> sizeBytes,
      Value<String?> sha256,
      required ModelStatus status,
      Value<String?> localPath,
      Value<int?> downloadedAt,
      Value<int> rowid,
    });
typedef $$ModelRegistryTableUpdateCompanionBuilder =
    ModelRegistryCompanion Function({
      Value<String> modelId,
      Value<int?> sizeBytes,
      Value<String?> sha256,
      Value<ModelStatus> status,
      Value<String?> localPath,
      Value<int?> downloadedAt,
      Value<int> rowid,
    });

final class $$ModelRegistryTableReferences
    extends
        BaseReferences<_$IaDatabase, $ModelRegistryTable, ModelRegistryData> {
  $$ModelRegistryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LyricsGenJobsTable, List<LyricsGenJob>>
  _lyricsGenJobsRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.lyricsGenJobs,
    aliasName: 'model_registry__model_id__lyrics_gen_jobs__model_id',
  );

  $$LyricsGenJobsTableProcessedTableManager get lyricsGenJobsRefs {
    final manager = $$LyricsGenJobsTableTableManager($_db, $_db.lyricsGenJobs)
        .filter(
          (f) => f.modelId.modelId.sqlEquals($_itemColumn<String>('model_id')!),
        );

    final cache = $_typedResult.readTableOrNull(_lyricsGenJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ModelRegistryTableFilterComposer
    extends Composer<_$IaDatabase, $ModelRegistryTable> {
  $$ModelRegistryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ModelStatus, ModelStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> lyricsGenJobsRefs(
    Expression<bool> Function($$LyricsGenJobsTableFilterComposer f) f,
  ) {
    final $$LyricsGenJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.lyricsGenJobs,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsGenJobsTableFilterComposer(
            $db: $db,
            $table: $db.lyricsGenJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ModelRegistryTableOrderingComposer
    extends Composer<_$IaDatabase, $ModelRegistryTable> {
  $$ModelRegistryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelRegistryTableAnnotationComposer
    extends Composer<_$IaDatabase, $ModelRegistryTable> {
  $$ModelRegistryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ModelStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  Expression<T> lyricsGenJobsRefs<T extends Object>(
    Expression<T> Function($$LyricsGenJobsTableAnnotationComposer a) f,
  ) {
    final $$LyricsGenJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.lyricsGenJobs,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsGenJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.lyricsGenJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ModelRegistryTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $ModelRegistryTable,
          ModelRegistryData,
          $$ModelRegistryTableFilterComposer,
          $$ModelRegistryTableOrderingComposer,
          $$ModelRegistryTableAnnotationComposer,
          $$ModelRegistryTableCreateCompanionBuilder,
          $$ModelRegistryTableUpdateCompanionBuilder,
          (ModelRegistryData, $$ModelRegistryTableReferences),
          ModelRegistryData,
          PrefetchHooks Function({bool lyricsGenJobsRefs})
        > {
  $$ModelRegistryTableTableManager(_$IaDatabase db, $ModelRegistryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelRegistryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelRegistryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelRegistryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> modelId = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<ModelStatus> status = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelRegistryCompanion(
                modelId: modelId,
                sizeBytes: sizeBytes,
                sha256: sha256,
                status: status,
                localPath: localPath,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String modelId,
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                required ModelStatus status,
                Value<String?> localPath = const Value.absent(),
                Value<int?> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelRegistryCompanion.insert(
                modelId: modelId,
                sizeBytes: sizeBytes,
                sha256: sha256,
                status: status,
                localPath: localPath,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelRegistryTable, ModelRegistryData>(table),
                  $$ModelRegistryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lyricsGenJobsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (lyricsGenJobsRefs) db.lyricsGenJobs,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lyricsGenJobsRefs)
                    await $_getPrefetchedData<
                      ModelRegistryData,
                      $ModelRegistryTable,
                      LyricsGenJob
                    >(
                      currentTable: table,
                      referencedTable: $$ModelRegistryTableReferences
                          ._lyricsGenJobsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ModelRegistryTableReferences(
                            db,
                            table,
                            p0,
                          ).lyricsGenJobsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.modelId == item.modelId,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ModelRegistryTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $ModelRegistryTable,
      ModelRegistryData,
      $$ModelRegistryTableFilterComposer,
      $$ModelRegistryTableOrderingComposer,
      $$ModelRegistryTableAnnotationComposer,
      $$ModelRegistryTableCreateCompanionBuilder,
      $$ModelRegistryTableUpdateCompanionBuilder,
      (ModelRegistryData, $$ModelRegistryTableReferences),
      ModelRegistryData,
      PrefetchHooks Function({bool lyricsGenJobsRefs})
    >;
typedef $$LyricsGenJobsTableCreateCompanionBuilder =
    LyricsGenJobsCompanion Function({
      Value<int> id,
      required int trackId,
      required LyricsJobStatus status,
      Value<double> progress,
      Value<String?> modelId,
      required int createdAt,
      required int updatedAt,
      Value<int?> startedAt,
      Value<int?> finishedAt,
      Value<String?> errorCode,
    });
typedef $$LyricsGenJobsTableUpdateCompanionBuilder =
    LyricsGenJobsCompanion Function({
      Value<int> id,
      Value<int> trackId,
      Value<LyricsJobStatus> status,
      Value<double> progress,
      Value<String?> modelId,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> startedAt,
      Value<int?> finishedAt,
      Value<String?> errorCode,
    });

final class $$LyricsGenJobsTableReferences
    extends BaseReferences<_$IaDatabase, $LyricsGenJobsTable, LyricsGenJob> {
  $$LyricsGenJobsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TracksTable _trackIdTable(_$IaDatabase db) =>
      db.tracks.createAlias('lyrics_gen_jobs__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ModelRegistryTable _modelIdTable(_$IaDatabase db) => db.modelRegistry
      .createAlias('lyrics_gen_jobs__model_id__model_registry__model_id');

  $$ModelRegistryTableProcessedTableManager? get modelId {
    final $_column = $_itemColumn<String>('model_id');
    if ($_column == null) return null;
    final manager = $$ModelRegistryTableTableManager(
      $_db,
      $_db.modelRegistry,
    ).filter((f) => f.modelId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LyricsGenJobsTableFilterComposer
    extends Composer<_$IaDatabase, $LyricsGenJobsTable> {
  $$LyricsGenJobsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<LyricsJobStatus, LyricsJobStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelRegistryTableFilterComposer get modelId {
    final $$ModelRegistryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelRegistry,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelRegistryTableFilterComposer(
            $db: $db,
            $table: $db.modelRegistry,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsGenJobsTableOrderingComposer
    extends Composer<_$IaDatabase, $LyricsGenJobsTable> {
  $$LyricsGenJobsTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelRegistryTableOrderingComposer get modelId {
    final $$ModelRegistryTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelRegistry,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelRegistryTableOrderingComposer(
            $db: $db,
            $table: $db.modelRegistry,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsGenJobsTableAnnotationComposer
    extends Composer<_$IaDatabase, $LyricsGenJobsTable> {
  $$LyricsGenJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LyricsJobStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelRegistryTableAnnotationComposer get modelId {
    final $$ModelRegistryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelRegistry,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelRegistryTableAnnotationComposer(
            $db: $db,
            $table: $db.modelRegistry,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsGenJobsTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $LyricsGenJobsTable,
          LyricsGenJob,
          $$LyricsGenJobsTableFilterComposer,
          $$LyricsGenJobsTableOrderingComposer,
          $$LyricsGenJobsTableAnnotationComposer,
          $$LyricsGenJobsTableCreateCompanionBuilder,
          $$LyricsGenJobsTableUpdateCompanionBuilder,
          (LyricsGenJob, $$LyricsGenJobsTableReferences),
          LyricsGenJob,
          PrefetchHooks Function({bool trackId, bool modelId})
        > {
  $$LyricsGenJobsTableTableManager(_$IaDatabase db, $LyricsGenJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsGenJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsGenJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsGenJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<LyricsJobStatus> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
              }) => LyricsGenJobsCompanion(
                id: id,
                trackId: trackId,
                status: status,
                progress: progress,
                modelId: modelId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                errorCode: errorCode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                required LyricsJobStatus status,
                Value<double> progress = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> startedAt = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
              }) => LyricsGenJobsCompanion.insert(
                id: id,
                trackId: trackId,
                status: status,
                progress: progress,
                modelId: modelId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                errorCode: errorCode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricsGenJobsTable, LyricsGenJob>(table),
                  $$LyricsGenJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false, modelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$LyricsGenJobsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$LyricsGenJobsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (modelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.modelId,
                        referencedTable: $$LyricsGenJobsTableReferences
                            ._modelIdTable(db),
                        referencedColumn: $$LyricsGenJobsTableReferences
                            ._modelIdTable(db)
                            .modelId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LyricsGenJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $LyricsGenJobsTable,
      LyricsGenJob,
      $$LyricsGenJobsTableFilterComposer,
      $$LyricsGenJobsTableOrderingComposer,
      $$LyricsGenJobsTableAnnotationComposer,
      $$LyricsGenJobsTableCreateCompanionBuilder,
      $$LyricsGenJobsTableUpdateCompanionBuilder,
      (LyricsGenJob, $$LyricsGenJobsTableReferences),
      LyricsGenJob,
      PrefetchHooks Function({bool trackId, bool modelId})
    >;
typedef $$ExtractTasksTableCreateCompanionBuilder =
    ExtractTasksCompanion Function({
      Value<int> id,
      required String sourceType,
      required String sourceId,
      required String url,
      Value<String?> title,
      Value<String?> uploader,
      Value<int?> durationMs,
      required TaskQuality quality,
      Value<double> progressPct,
      required ExtractTaskStatus status,
      Value<ExtractErrorCode?> errorCode,
      Value<String?> outputRelPath,
      Value<bool> cookiesUsed,
      Value<int> retryCount,
      required int createdAt,
      required int updatedAt,
    });
typedef $$ExtractTasksTableUpdateCompanionBuilder =
    ExtractTasksCompanion Function({
      Value<int> id,
      Value<String> sourceType,
      Value<String> sourceId,
      Value<String> url,
      Value<String?> title,
      Value<String?> uploader,
      Value<int?> durationMs,
      Value<TaskQuality> quality,
      Value<double> progressPct,
      Value<ExtractTaskStatus> status,
      Value<ExtractErrorCode?> errorCode,
      Value<String?> outputRelPath,
      Value<bool> cookiesUsed,
      Value<int> retryCount,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

class $$ExtractTasksTableFilterComposer
    extends Composer<_$IaDatabase, $ExtractTasksTable> {
  $$ExtractTasksTableFilterComposer({
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

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploader => $composableBuilder(
    column: $table.uploader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskQuality, TaskQuality, String>
  get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get progressPct => $composableBuilder(
    column: $table.progressPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExtractTaskStatus, ExtractTaskStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ExtractErrorCode?, ExtractErrorCode, String>
  get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get outputRelPath => $composableBuilder(
    column: $table.outputRelPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cookiesUsed => $composableBuilder(
    column: $table.cookiesUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExtractTasksTableOrderingComposer
    extends Composer<_$IaDatabase, $ExtractTasksTable> {
  $$ExtractTasksTableOrderingComposer({
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

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploader => $composableBuilder(
    column: $table.uploader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressPct => $composableBuilder(
    column: $table.progressPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputRelPath => $composableBuilder(
    column: $table.outputRelPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cookiesUsed => $composableBuilder(
    column: $table.cookiesUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExtractTasksTableAnnotationComposer
    extends Composer<_$IaDatabase, $ExtractTasksTable> {
  $$ExtractTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get uploader =>
      $composableBuilder(column: $table.uploader, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TaskQuality, String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<double> get progressPct => $composableBuilder(
    column: $table.progressPct,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ExtractTaskStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExtractErrorCode?, String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get outputRelPath => $composableBuilder(
    column: $table.outputRelPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get cookiesUsed => $composableBuilder(
    column: $table.cookiesUsed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExtractTasksTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $ExtractTasksTable,
          ExtractTask,
          $$ExtractTasksTableFilterComposer,
          $$ExtractTasksTableOrderingComposer,
          $$ExtractTasksTableAnnotationComposer,
          $$ExtractTasksTableCreateCompanionBuilder,
          $$ExtractTasksTableUpdateCompanionBuilder,
          (
            ExtractTask,
            BaseReferences<_$IaDatabase, $ExtractTasksTable, ExtractTask>,
          ),
          ExtractTask,
          PrefetchHooks Function()
        > {
  $$ExtractTasksTableTableManager(_$IaDatabase db, $ExtractTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtractTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtractTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtractTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> uploader = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<TaskQuality> quality = const Value.absent(),
                Value<double> progressPct = const Value.absent(),
                Value<ExtractTaskStatus> status = const Value.absent(),
                Value<ExtractErrorCode?> errorCode = const Value.absent(),
                Value<String?> outputRelPath = const Value.absent(),
                Value<bool> cookiesUsed = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => ExtractTasksCompanion(
                id: id,
                sourceType: sourceType,
                sourceId: sourceId,
                url: url,
                title: title,
                uploader: uploader,
                durationMs: durationMs,
                quality: quality,
                progressPct: progressPct,
                status: status,
                errorCode: errorCode,
                outputRelPath: outputRelPath,
                cookiesUsed: cookiesUsed,
                retryCount: retryCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceType,
                required String sourceId,
                required String url,
                Value<String?> title = const Value.absent(),
                Value<String?> uploader = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required TaskQuality quality,
                Value<double> progressPct = const Value.absent(),
                required ExtractTaskStatus status,
                Value<ExtractErrorCode?> errorCode = const Value.absent(),
                Value<String?> outputRelPath = const Value.absent(),
                Value<bool> cookiesUsed = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => ExtractTasksCompanion.insert(
                id: id,
                sourceType: sourceType,
                sourceId: sourceId,
                url: url,
                title: title,
                uploader: uploader,
                durationMs: durationMs,
                quality: quality,
                progressPct: progressPct,
                status: status,
                errorCode: errorCode,
                outputRelPath: outputRelPath,
                cookiesUsed: cookiesUsed,
                retryCount: retryCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExtractTasksTable, ExtractTask>(table),
                  BaseReferences<_$IaDatabase, $ExtractTasksTable, ExtractTask>(
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

typedef $$ExtractTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $ExtractTasksTable,
      ExtractTask,
      $$ExtractTasksTableFilterComposer,
      $$ExtractTasksTableOrderingComposer,
      $$ExtractTasksTableAnnotationComposer,
      $$ExtractTasksTableCreateCompanionBuilder,
      $$ExtractTasksTableUpdateCompanionBuilder,
      (
        ExtractTask,
        BaseReferences<_$IaDatabase, $ExtractTasksTable, ExtractTask>,
      ),
      ExtractTask,
      PrefetchHooks Function()
    >;
typedef $$SyncChannelTableCreateCompanionBuilder =
    SyncChannelCompanion Function({
      Value<int> id,
      required SyncChannelType type,
      required String baseUrl,
      Value<String> remoteDir,
      Value<String?> username,
      Value<String?> credentialsRef,
      Value<bool> isActive,
      Value<int?> lastTestAt,
      Value<bool?> lastTestOk,
    });
typedef $$SyncChannelTableUpdateCompanionBuilder =
    SyncChannelCompanion Function({
      Value<int> id,
      Value<SyncChannelType> type,
      Value<String> baseUrl,
      Value<String> remoteDir,
      Value<String?> username,
      Value<String?> credentialsRef,
      Value<bool> isActive,
      Value<int?> lastTestAt,
      Value<bool?> lastTestOk,
    });

final class $$SyncChannelTableReferences
    extends BaseReferences<_$IaDatabase, $SyncChannelTable, SyncChannelData> {
  $$SyncChannelTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LastSyncStateTable, List<LastSyncStateData>>
  _lastSyncStateRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.lastSyncState,
    aliasName: 'sync_channel__id__last_sync_state__channel_id',
  );

  $$LastSyncStateTableProcessedTableManager get lastSyncStateRefs {
    final manager = $$LastSyncStateTableTableManager(
      $_db,
      $_db.lastSyncState,
    ).filter((f) => f.channelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lastSyncStateRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SyncChannelTableFilterComposer
    extends Composer<_$IaDatabase, $SyncChannelTable> {
  $$SyncChannelTableFilterComposer({
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

  ColumnWithTypeConverterFilters<SyncChannelType, SyncChannelType, String>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteDir => $composableBuilder(
    column: $table.remoteDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialsRef => $composableBuilder(
    column: $table.credentialsRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTestAt => $composableBuilder(
    column: $table.lastTestAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lastTestOk => $composableBuilder(
    column: $table.lastTestOk,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> lastSyncStateRefs(
    Expression<bool> Function($$LastSyncStateTableFilterComposer f) f,
  ) {
    final $$LastSyncStateTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lastSyncState,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LastSyncStateTableFilterComposer(
            $db: $db,
            $table: $db.lastSyncState,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyncChannelTableOrderingComposer
    extends Composer<_$IaDatabase, $SyncChannelTable> {
  $$SyncChannelTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteDir => $composableBuilder(
    column: $table.remoteDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialsRef => $composableBuilder(
    column: $table.credentialsRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTestAt => $composableBuilder(
    column: $table.lastTestAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lastTestOk => $composableBuilder(
    column: $table.lastTestOk,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncChannelTableAnnotationComposer
    extends Composer<_$IaDatabase, $SyncChannelTable> {
  $$SyncChannelTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncChannelType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get remoteDir =>
      $composableBuilder(column: $table.remoteDir, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get credentialsRef => $composableBuilder(
    column: $table.credentialsRef,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get lastTestAt => $composableBuilder(
    column: $table.lastTestAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lastTestOk => $composableBuilder(
    column: $table.lastTestOk,
    builder: (column) => column,
  );

  Expression<T> lastSyncStateRefs<T extends Object>(
    Expression<T> Function($$LastSyncStateTableAnnotationComposer a) f,
  ) {
    final $$LastSyncStateTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lastSyncState,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LastSyncStateTableAnnotationComposer(
            $db: $db,
            $table: $db.lastSyncState,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyncChannelTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $SyncChannelTable,
          SyncChannelData,
          $$SyncChannelTableFilterComposer,
          $$SyncChannelTableOrderingComposer,
          $$SyncChannelTableAnnotationComposer,
          $$SyncChannelTableCreateCompanionBuilder,
          $$SyncChannelTableUpdateCompanionBuilder,
          (SyncChannelData, $$SyncChannelTableReferences),
          SyncChannelData,
          PrefetchHooks Function({bool lastSyncStateRefs})
        > {
  $$SyncChannelTableTableManager(_$IaDatabase db, $SyncChannelTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncChannelTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncChannelTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncChannelTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<SyncChannelType> type = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> remoteDir = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> credentialsRef = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int?> lastTestAt = const Value.absent(),
                Value<bool?> lastTestOk = const Value.absent(),
              }) => SyncChannelCompanion(
                id: id,
                type: type,
                baseUrl: baseUrl,
                remoteDir: remoteDir,
                username: username,
                credentialsRef: credentialsRef,
                isActive: isActive,
                lastTestAt: lastTestAt,
                lastTestOk: lastTestOk,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required SyncChannelType type,
                required String baseUrl,
                Value<String> remoteDir = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> credentialsRef = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int?> lastTestAt = const Value.absent(),
                Value<bool?> lastTestOk = const Value.absent(),
              }) => SyncChannelCompanion.insert(
                id: id,
                type: type,
                baseUrl: baseUrl,
                remoteDir: remoteDir,
                username: username,
                credentialsRef: credentialsRef,
                isActive: isActive,
                lastTestAt: lastTestAt,
                lastTestOk: lastTestOk,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncChannelTable, SyncChannelData>(table),
                  $$SyncChannelTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lastSyncStateRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (lastSyncStateRefs) db.lastSyncState,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lastSyncStateRefs)
                    await $_getPrefetchedData<
                      SyncChannelData,
                      $SyncChannelTable,
                      LastSyncStateData
                    >(
                      currentTable: table,
                      referencedTable: $$SyncChannelTableReferences
                          ._lastSyncStateRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SyncChannelTableReferences(
                            db,
                            table,
                            p0,
                          ).lastSyncStateRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.channelId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SyncChannelTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $SyncChannelTable,
      SyncChannelData,
      $$SyncChannelTableFilterComposer,
      $$SyncChannelTableOrderingComposer,
      $$SyncChannelTableAnnotationComposer,
      $$SyncChannelTableCreateCompanionBuilder,
      $$SyncChannelTableUpdateCompanionBuilder,
      (SyncChannelData, $$SyncChannelTableReferences),
      SyncChannelData,
      PrefetchHooks Function({bool lastSyncStateRefs})
    >;
typedef $$LastSyncStateTableCreateCompanionBuilder =
    LastSyncStateCompanion Function({
      Value<int> channelId,
      Value<int?> lastStartedAt,
      Value<int?> lastCompletedAt,
      Value<int?> pendingUp,
      Value<int?> pendingDown,
      Value<String?> summaryJson,
    });
typedef $$LastSyncStateTableUpdateCompanionBuilder =
    LastSyncStateCompanion Function({
      Value<int> channelId,
      Value<int?> lastStartedAt,
      Value<int?> lastCompletedAt,
      Value<int?> pendingUp,
      Value<int?> pendingDown,
      Value<String?> summaryJson,
    });

final class $$LastSyncStateTableReferences
    extends
        BaseReferences<_$IaDatabase, $LastSyncStateTable, LastSyncStateData> {
  $$LastSyncStateTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SyncChannelTable _channelIdTable(_$IaDatabase db) => db.syncChannel
      .createAlias('last_sync_state__channel_id__sync_channel__id');

  $$SyncChannelTableProcessedTableManager get channelId {
    final $_column = $_itemColumn<int>('channel_id')!;

    final manager = $$SyncChannelTableTableManager(
      $_db,
      $_db.syncChannel,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_channelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LastSyncStateTableFilterComposer
    extends Composer<_$IaDatabase, $LastSyncStateTable> {
  $$LastSyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get lastStartedAt => $composableBuilder(
    column: $table.lastStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pendingUp => $composableBuilder(
    column: $table.pendingUp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pendingDown => $composableBuilder(
    column: $table.pendingDown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  $$SyncChannelTableFilterComposer get channelId {
    final $$SyncChannelTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.syncChannel,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncChannelTableFilterComposer(
            $db: $db,
            $table: $db.syncChannel,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LastSyncStateTableOrderingComposer
    extends Composer<_$IaDatabase, $LastSyncStateTable> {
  $$LastSyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get lastStartedAt => $composableBuilder(
    column: $table.lastStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pendingUp => $composableBuilder(
    column: $table.pendingUp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pendingDown => $composableBuilder(
    column: $table.pendingDown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$SyncChannelTableOrderingComposer get channelId {
    final $$SyncChannelTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.syncChannel,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncChannelTableOrderingComposer(
            $db: $db,
            $table: $db.syncChannel,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LastSyncStateTableAnnotationComposer
    extends Composer<_$IaDatabase, $LastSyncStateTable> {
  $$LastSyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get lastStartedAt => $composableBuilder(
    column: $table.lastStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pendingUp =>
      $composableBuilder(column: $table.pendingUp, builder: (column) => column);

  GeneratedColumn<int> get pendingDown => $composableBuilder(
    column: $table.pendingDown,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  $$SyncChannelTableAnnotationComposer get channelId {
    final $$SyncChannelTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.syncChannel,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncChannelTableAnnotationComposer(
            $db: $db,
            $table: $db.syncChannel,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LastSyncStateTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $LastSyncStateTable,
          LastSyncStateData,
          $$LastSyncStateTableFilterComposer,
          $$LastSyncStateTableOrderingComposer,
          $$LastSyncStateTableAnnotationComposer,
          $$LastSyncStateTableCreateCompanionBuilder,
          $$LastSyncStateTableUpdateCompanionBuilder,
          (LastSyncStateData, $$LastSyncStateTableReferences),
          LastSyncStateData,
          PrefetchHooks Function({bool channelId})
        > {
  $$LastSyncStateTableTableManager(_$IaDatabase db, $LastSyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LastSyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LastSyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LastSyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> channelId = const Value.absent(),
                Value<int?> lastStartedAt = const Value.absent(),
                Value<int?> lastCompletedAt = const Value.absent(),
                Value<int?> pendingUp = const Value.absent(),
                Value<int?> pendingDown = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
              }) => LastSyncStateCompanion(
                channelId: channelId,
                lastStartedAt: lastStartedAt,
                lastCompletedAt: lastCompletedAt,
                pendingUp: pendingUp,
                pendingDown: pendingDown,
                summaryJson: summaryJson,
              ),
          createCompanionCallback:
              ({
                Value<int> channelId = const Value.absent(),
                Value<int?> lastStartedAt = const Value.absent(),
                Value<int?> lastCompletedAt = const Value.absent(),
                Value<int?> pendingUp = const Value.absent(),
                Value<int?> pendingDown = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
              }) => LastSyncStateCompanion.insert(
                channelId: channelId,
                lastStartedAt: lastStartedAt,
                lastCompletedAt: lastCompletedAt,
                pendingUp: pendingUp,
                pendingDown: pendingDown,
                summaryJson: summaryJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LastSyncStateTable, LastSyncStateData>(table),
                  $$LastSyncStateTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({channelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (channelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.channelId,
                        referencedTable: $$LastSyncStateTableReferences
                            ._channelIdTable(db),
                        referencedColumn: $$LastSyncStateTableReferences
                            ._channelIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LastSyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $LastSyncStateTable,
      LastSyncStateData,
      $$LastSyncStateTableFilterComposer,
      $$LastSyncStateTableOrderingComposer,
      $$LastSyncStateTableAnnotationComposer,
      $$LastSyncStateTableCreateCompanionBuilder,
      $$LastSyncStateTableUpdateCompanionBuilder,
      (LastSyncStateData, $$LastSyncStateTableReferences),
      LastSyncStateData,
      PrefetchHooks Function({bool channelId})
    >;
typedef $$TombstonesTableCreateCompanionBuilder = TombstonesCompanion Function({
  Value<int> id,
  required TombstoneKind entityKind,
  required int entityLocalId,
  required int deletedAt,
  required String deletedByDevice,
  Value<int?> remoteClearedAt,
});
typedef $$TombstonesTableUpdateCompanionBuilder = TombstonesCompanion Function({
  Value<int> id,
  Value<TombstoneKind> entityKind,
  Value<int> entityLocalId,
  Value<int> deletedAt,
  Value<String> deletedByDevice,
  Value<int?> remoteClearedAt,
});

class $$TombstonesTableFilterComposer
    extends Composer<_$IaDatabase, $TombstonesTable> {
  $$TombstonesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<TombstoneKind, TombstoneKind, String>
  get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedByDevice => $composableBuilder(
    column: $table.deletedByDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteClearedAt => $composableBuilder(
    column: $table.remoteClearedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TombstonesTableOrderingComposer
    extends Composer<_$IaDatabase, $TombstonesTable> {
  $$TombstonesTableOrderingComposer({
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

  ColumnOrderings<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedByDevice => $composableBuilder(
    column: $table.deletedByDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteClearedAt => $composableBuilder(
    column: $table.remoteClearedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TombstonesTableAnnotationComposer
    extends Composer<_$IaDatabase, $TombstonesTable> {
  $$TombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TombstoneKind, String> get entityKind =>
      $composableBuilder(
        column: $table.entityKind,
        builder: (column) => column,
      );

  GeneratedColumn<int> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedByDevice => $composableBuilder(
    column: $table.deletedByDevice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteClearedAt => $composableBuilder(
    column: $table.remoteClearedAt,
    builder: (column) => column,
  );
}

class $$TombstonesTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $TombstonesTable,
          Tombstone,
          $$TombstonesTableFilterComposer,
          $$TombstonesTableOrderingComposer,
          $$TombstonesTableAnnotationComposer,
          $$TombstonesTableCreateCompanionBuilder,
          $$TombstonesTableUpdateCompanionBuilder,
          (
            Tombstone,
            BaseReferences<_$IaDatabase, $TombstonesTable, Tombstone>,
          ),
          Tombstone,
          PrefetchHooks Function()
        > {
  $$TombstonesTableTableManager(_$IaDatabase db, $TombstonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TombstonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TombstonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<TombstoneKind> entityKind = const Value.absent(),
                Value<int> entityLocalId = const Value.absent(),
                Value<int> deletedAt = const Value.absent(),
                Value<String> deletedByDevice = const Value.absent(),
                Value<int?> remoteClearedAt = const Value.absent(),
              }) => TombstonesCompanion(
                id: id,
                entityKind: entityKind,
                entityLocalId: entityLocalId,
                deletedAt: deletedAt,
                deletedByDevice: deletedByDevice,
                remoteClearedAt: remoteClearedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required TombstoneKind entityKind,
                required int entityLocalId,
                required int deletedAt,
                required String deletedByDevice,
                Value<int?> remoteClearedAt = const Value.absent(),
              }) => TombstonesCompanion.insert(
                id: id,
                entityKind: entityKind,
                entityLocalId: entityLocalId,
                deletedAt: deletedAt,
                deletedByDevice: deletedByDevice,
                remoteClearedAt: remoteClearedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TombstonesTable, Tombstone>(table),
                  BaseReferences<_$IaDatabase, $TombstonesTable, Tombstone>(
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

typedef $$TombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $TombstonesTable,
      Tombstone,
      $$TombstonesTableFilterComposer,
      $$TombstonesTableOrderingComposer,
      $$TombstonesTableAnnotationComposer,
      $$TombstonesTableCreateCompanionBuilder,
      $$TombstonesTableUpdateCompanionBuilder,
      (Tombstone, BaseReferences<_$IaDatabase, $TombstonesTable, Tombstone>),
      Tombstone,
      PrefetchHooks Function()
    >;
typedef $$ConflictCopiesTableCreateCompanionBuilder =
    ConflictCopiesCompanion Function({
      Value<int> id,
      required String originKind,
      required int originLocalId,
      required String winnerValueJson,
      required String loserPayloadJson,
      required int lostAt,
      Value<int?> deletedAt,
    });
typedef $$ConflictCopiesTableUpdateCompanionBuilder =
    ConflictCopiesCompanion Function({
      Value<int> id,
      Value<String> originKind,
      Value<int> originLocalId,
      Value<String> winnerValueJson,
      Value<String> loserPayloadJson,
      Value<int> lostAt,
      Value<int?> deletedAt,
    });

class $$ConflictCopiesTableFilterComposer
    extends Composer<_$IaDatabase, $ConflictCopiesTable> {
  $$ConflictCopiesTableFilterComposer({
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

  ColumnFilters<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originLocalId => $composableBuilder(
    column: $table.originLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get winnerValueJson => $composableBuilder(
    column: $table.winnerValueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loserPayloadJson => $composableBuilder(
    column: $table.loserPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lostAt => $composableBuilder(
    column: $table.lostAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConflictCopiesTableOrderingComposer
    extends Composer<_$IaDatabase, $ConflictCopiesTable> {
  $$ConflictCopiesTableOrderingComposer({
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

  ColumnOrderings<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originLocalId => $composableBuilder(
    column: $table.originLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winnerValueJson => $composableBuilder(
    column: $table.winnerValueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loserPayloadJson => $composableBuilder(
    column: $table.loserPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lostAt => $composableBuilder(
    column: $table.lostAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConflictCopiesTableAnnotationComposer
    extends Composer<_$IaDatabase, $ConflictCopiesTable> {
  $$ConflictCopiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originLocalId => $composableBuilder(
    column: $table.originLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get winnerValueJson => $composableBuilder(
    column: $table.winnerValueJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loserPayloadJson => $composableBuilder(
    column: $table.loserPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lostAt =>
      $composableBuilder(column: $table.lostAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ConflictCopiesTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $ConflictCopiesTable,
          ConflictCopy,
          $$ConflictCopiesTableFilterComposer,
          $$ConflictCopiesTableOrderingComposer,
          $$ConflictCopiesTableAnnotationComposer,
          $$ConflictCopiesTableCreateCompanionBuilder,
          $$ConflictCopiesTableUpdateCompanionBuilder,
          (
            ConflictCopy,
            BaseReferences<_$IaDatabase, $ConflictCopiesTable, ConflictCopy>,
          ),
          ConflictCopy,
          PrefetchHooks Function()
        > {
  $$ConflictCopiesTableTableManager(_$IaDatabase db, $ConflictCopiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictCopiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictCopiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictCopiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> originKind = const Value.absent(),
                Value<int> originLocalId = const Value.absent(),
                Value<String> winnerValueJson = const Value.absent(),
                Value<String> loserPayloadJson = const Value.absent(),
                Value<int> lostAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => ConflictCopiesCompanion(
                id: id,
                originKind: originKind,
                originLocalId: originLocalId,
                winnerValueJson: winnerValueJson,
                loserPayloadJson: loserPayloadJson,
                lostAt: lostAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String originKind,
                required int originLocalId,
                required String winnerValueJson,
                required String loserPayloadJson,
                required int lostAt,
                Value<int?> deletedAt = const Value.absent(),
              }) => ConflictCopiesCompanion.insert(
                id: id,
                originKind: originKind,
                originLocalId: originLocalId,
                winnerValueJson: winnerValueJson,
                loserPayloadJson: loserPayloadJson,
                lostAt: lostAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConflictCopiesTable, ConflictCopy>(table),
                  BaseReferences<
                    _$IaDatabase,
                    $ConflictCopiesTable,
                    ConflictCopy
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConflictCopiesTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $ConflictCopiesTable,
      ConflictCopy,
      $$ConflictCopiesTableFilterComposer,
      $$ConflictCopiesTableOrderingComposer,
      $$ConflictCopiesTableAnnotationComposer,
      $$ConflictCopiesTableCreateCompanionBuilder,
      $$ConflictCopiesTableUpdateCompanionBuilder,
      (
        ConflictCopy,
        BaseReferences<_$IaDatabase, $ConflictCopiesTable, ConflictCopy>,
      ),
      ConflictCopy,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$IaDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$IaDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$IaDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$IaDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$IaDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$IaDatabase, $SettingsTable, Setting>(
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

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$IaDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $IaDatabaseManager {
  final _$IaDatabase _db;
  $IaDatabaseManager(this._db);
  $$RepositoryRootsTableTableManager get repositoryRoots =>
      $$RepositoryRootsTableTableManager(_db, _db.repositoryRoots);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db, _db.artists);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db, _db.albums);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db, _db.playHistory);
  $$FewWatchListTableTableManager get fewWatchList =>
      $$FewWatchListTableTableManager(_db, _db.fewWatchList);
  $$LyricsMetaTableTableManager get lyricsMeta =>
      $$LyricsMetaTableTableManager(_db, _db.lyricsMeta);
  $$ModelRegistryTableTableManager get modelRegistry =>
      $$ModelRegistryTableTableManager(_db, _db.modelRegistry);
  $$LyricsGenJobsTableTableManager get lyricsGenJobs =>
      $$LyricsGenJobsTableTableManager(_db, _db.lyricsGenJobs);
  $$ExtractTasksTableTableManager get extractTasks =>
      $$ExtractTasksTableTableManager(_db, _db.extractTasks);
  $$SyncChannelTableTableManager get syncChannel =>
      $$SyncChannelTableTableManager(_db, _db.syncChannel);
  $$LastSyncStateTableTableManager get lastSyncState =>
      $$LastSyncStateTableTableManager(_db, _db.lastSyncState);
  $$TombstonesTableTableManager get tombstones =>
      $$TombstonesTableTableManager(_db, _db.tombstones);
  $$ConflictCopiesTableTableManager get conflictCopies =>
      $$ConflictCopiesTableTableManager(_db, _db.conflictCopies);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
