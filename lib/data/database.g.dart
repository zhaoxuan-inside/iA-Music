// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

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
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, addedAt];
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
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
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
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $RepositoryRootsTable createAlias(String alias) {
    return $RepositoryRootsTable(attachedDatabase, alias);
  }
}

class RepositoryRoot extends DataClass implements Insertable<RepositoryRoot> {
  final int id;
  final String path;
  final DateTime addedAt;
  const RepositoryRoot({
    required this.id,
    required this.path,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  RepositoryRootsCompanion toCompanion(bool nullToAbsent) {
    return RepositoryRootsCompanion(
      id: Value(id),
      path: Value(path),
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
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  RepositoryRoot copyWith({int? id, String? path, DateTime? addedAt}) =>
      RepositoryRoot(
        id: id ?? this.id,
        path: path ?? this.path,
        addedAt: addedAt ?? this.addedAt,
      );
  RepositoryRoot copyWithCompanion(RepositoryRootsCompanion data) {
    return RepositoryRoot(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepositoryRoot(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepositoryRoot &&
          other.id == this.id &&
          other.path == this.path &&
          other.addedAt == this.addedAt);
}

class RepositoryRootsCompanion extends UpdateCompanion<RepositoryRoot> {
  final Value<int> id;
  final Value<String> path;
  final Value<DateTime> addedAt;
  const RepositoryRootsCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  RepositoryRootsCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    this.addedAt = const Value.absent(),
  }) : path = Value(path);
  static Insertable<RepositoryRoot> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  RepositoryRootsCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<DateTime>? addedAt,
  }) {
    return RepositoryRootsCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
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
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepositoryRootsCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, TrackRow> {
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleNormMeta = const VerificationMeta(
    'titleNorm',
  );
  @override
  late final GeneratedColumn<String> titleNorm = GeneratedColumn<String>(
    'title_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNormMeta = const VerificationMeta(
    'artistNorm',
  );
  @override
  late final GeneratedColumn<String> artistNorm = GeneratedColumn<String>(
    'artist_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumNormMeta = const VerificationMeta(
    'albumNorm',
  );
  @override
  late final GeneratedColumn<String> albumNorm = GeneratedColumn<String>(
    'album_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _trackNoMeta = const VerificationMeta(
    'trackNo',
  );
  @override
  late final GeneratedColumn<int> trackNo = GeneratedColumn<int>(
    'track_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playsMeta = const VerificationMeta('plays');
  @override
  late final GeneratedColumn<int> plays = GeneratedColumn<int>(
    'plays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _audioFormatMeta = const VerificationMeta(
    'audioFormat',
  );
  @override
  late final GeneratedColumn<String> audioFormat = GeneratedColumn<String>(
    'audio_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverCheckedAtMeta = const VerificationMeta(
    'coverCheckedAt',
  );
  @override
  late final GeneratedColumn<DateTime> coverCheckedAt =
      GeneratedColumn<DateTime>(
        'cover_checked_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _missingAtMeta = const VerificationMeta(
    'missingAt',
  );
  @override
  late final GeneratedColumn<DateTime> missingAt = GeneratedColumn<DateTime>(
    'missing_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _needsMetaMeta = const VerificationMeta(
    'needsMeta',
  );
  @override
  late final GeneratedColumn<bool> needsMeta = GeneratedColumn<bool>(
    'needs_meta',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_meta" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _enrichedAtMeta = const VerificationMeta(
    'enrichedAt',
  );
  @override
  late final GeneratedColumn<DateTime> enrichedAt = GeneratedColumn<DateTime>(
    'enriched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMatchedAtMeta = const VerificationMeta(
    'titleMatchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> titleMatchedAt =
      GeneratedColumn<DateTime>(
        'title_matched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _artistMatchedAtMeta = const VerificationMeta(
    'artistMatchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> artistMatchedAt =
      GeneratedColumn<DateTime>(
        'artist_matched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lyricsAtMeta = const VerificationMeta(
    'lyricsAt',
  );
  @override
  late final GeneratedColumn<DateTime> lyricsAt = GeneratedColumn<DateTime>(
    'lyrics_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMatchedAtMeta = const VerificationMeta(
    'albumMatchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> albumMatchedAt =
      GeneratedColumn<DateTime>(
        'album_matched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _trackMatchedAtMeta = const VerificationMeta(
    'trackMatchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> trackMatchedAt =
      GeneratedColumn<DateTime>(
        'track_matched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _enrichAttemptsMeta = const VerificationMeta(
    'enrichAttempts',
  );
  @override
  late final GeneratedColumn<int> enrichAttempts = GeneratedColumn<int>(
    'enrich_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rootId,
    relPath,
    path,
    title,
    titleNorm,
    artist,
    artistNorm,
    album,
    albumNorm,
    genre,
    trackNo,
    plays,
    durationMs,
    sizeBytes,
    contentHash,
    audioFormat,
    coverPath,
    coverCheckedAt,
    missingAt,
    addedAt,
    needsMeta,
    enrichedAt,
    titleMatchedAt,
    artistMatchedAt,
    lyricsAt,
    albumMatchedAt,
    trackMatchedAt,
    enrichAttempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackRow> instance, {
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
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_norm')) {
      context.handle(
        _titleNormMeta,
        titleNorm.isAcceptableOrUnknown(data['title_norm']!, _titleNormMeta),
      );
    } else if (isInserting) {
      context.missing(_titleNormMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('artist_norm')) {
      context.handle(
        _artistNormMeta,
        artistNorm.isAcceptableOrUnknown(data['artist_norm']!, _artistNormMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNormMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('album_norm')) {
      context.handle(
        _albumNormMeta,
        albumNorm.isAcceptableOrUnknown(data['album_norm']!, _albumNormMeta),
      );
    } else if (isInserting) {
      context.missing(_albumNormMeta);
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('track_no')) {
      context.handle(
        _trackNoMeta,
        trackNo.isAcceptableOrUnknown(data['track_no']!, _trackNoMeta),
      );
    }
    if (data.containsKey('plays')) {
      context.handle(
        _playsMeta,
        plays.isAcceptableOrUnknown(data['plays']!, _playsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('audio_format')) {
      context.handle(
        _audioFormatMeta,
        audioFormat.isAcceptableOrUnknown(
          data['audio_format']!,
          _audioFormatMeta,
        ),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('cover_checked_at')) {
      context.handle(
        _coverCheckedAtMeta,
        coverCheckedAt.isAcceptableOrUnknown(
          data['cover_checked_at']!,
          _coverCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('missing_at')) {
      context.handle(
        _missingAtMeta,
        missingAt.isAcceptableOrUnknown(data['missing_at']!, _missingAtMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('needs_meta')) {
      context.handle(
        _needsMetaMeta,
        needsMeta.isAcceptableOrUnknown(data['needs_meta']!, _needsMetaMeta),
      );
    }
    if (data.containsKey('enriched_at')) {
      context.handle(
        _enrichedAtMeta,
        enrichedAt.isAcceptableOrUnknown(data['enriched_at']!, _enrichedAtMeta),
      );
    }
    if (data.containsKey('title_matched_at')) {
      context.handle(
        _titleMatchedAtMeta,
        titleMatchedAt.isAcceptableOrUnknown(
          data['title_matched_at']!,
          _titleMatchedAtMeta,
        ),
      );
    }
    if (data.containsKey('artist_matched_at')) {
      context.handle(
        _artistMatchedAtMeta,
        artistMatchedAt.isAcceptableOrUnknown(
          data['artist_matched_at']!,
          _artistMatchedAtMeta,
        ),
      );
    }
    if (data.containsKey('lyrics_at')) {
      context.handle(
        _lyricsAtMeta,
        lyricsAt.isAcceptableOrUnknown(data['lyrics_at']!, _lyricsAtMeta),
      );
    }
    if (data.containsKey('album_matched_at')) {
      context.handle(
        _albumMatchedAtMeta,
        albumMatchedAt.isAcceptableOrUnknown(
          data['album_matched_at']!,
          _albumMatchedAtMeta,
        ),
      );
    }
    if (data.containsKey('track_matched_at')) {
      context.handle(
        _trackMatchedAtMeta,
        trackMatchedAt.isAcceptableOrUnknown(
          data['track_matched_at']!,
          _trackMatchedAtMeta,
        ),
      );
    }
    if (data.containsKey('enrich_attempts')) {
      context.handle(
        _enrichAttemptsMeta,
        enrichAttempts.isAcceptableOrUnknown(
          data['enrich_attempts']!,
          _enrichAttemptsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
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
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_norm'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      artistNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_norm'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      albumNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_norm'],
      )!,
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      )!,
      trackNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_no'],
      )!,
      plays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plays'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      audioFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_format'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      coverCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cover_checked_at'],
      ),
      missingAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}missing_at'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      needsMeta: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_meta'],
      )!,
      enrichedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}enriched_at'],
      ),
      titleMatchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}title_matched_at'],
      ),
      artistMatchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}artist_matched_at'],
      ),
      lyricsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lyrics_at'],
      ),
      albumMatchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}album_matched_at'],
      ),
      trackMatchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}track_matched_at'],
      ),
      enrichAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enrich_attempts'],
      )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final int id;
  final int rootId;
  final String relPath;
  final String path;
  final String title;
  final String titleNorm;
  final String artist;
  final String artistNorm;
  final String album;
  final String albumNorm;
  final String genre;
  final int trackNo;

  /// 累计播放次数（record 历史时物化递增；常听面直读本列，
  /// 不再对 play_history 全表 GROUP BY——历史表随播放无限增长）。
  final int plays;
  final int durationMs;
  final int sizeBytes;
  final String contentHash;
  final String audioFormat;
  final String? coverPath;
  final DateTime? coverCheckedAt;
  final DateTime? missingAt;
  final DateTime addedAt;

  /// 元数据补全：true=歌手/歌名待反向重建；enrichedAt=补全完成时刻。
  final bool needsMeta;
  final DateTime? enrichedAt;

  /// 补全阶段完成时刻（结论性：匹配成功或确认无匹配都算已处理；
  /// 网络失败不打时刻——留待重试）。UI 阶段进度条据此直读，跨重启不丢。
  /// 专辑/音轨的来源只有 AcoustID releases（文字链无源，匹配成功也置
  /// 确认无——有值填值、无值结案，避免无限重试）。
  final DateTime? titleMatchedAt;
  final DateTime? artistMatchedAt;
  final DateTime? lyricsAt;
  final DateTime? albumMatchedAt;
  final DateTime? trackMatchedAt;

  /// 连续硬失败次数（≥3 跳出待补全池；手动「开始补全」清零重试）。
  final int enrichAttempts;
  const TrackRow({
    required this.id,
    required this.rootId,
    required this.relPath,
    required this.path,
    required this.title,
    required this.titleNorm,
    required this.artist,
    required this.artistNorm,
    required this.album,
    required this.albumNorm,
    required this.genre,
    required this.trackNo,
    required this.plays,
    required this.durationMs,
    required this.sizeBytes,
    required this.contentHash,
    required this.audioFormat,
    this.coverPath,
    this.coverCheckedAt,
    this.missingAt,
    required this.addedAt,
    required this.needsMeta,
    this.enrichedAt,
    this.titleMatchedAt,
    this.artistMatchedAt,
    this.lyricsAt,
    this.albumMatchedAt,
    this.trackMatchedAt,
    required this.enrichAttempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['root_id'] = Variable<int>(rootId);
    map['rel_path'] = Variable<String>(relPath);
    map['path'] = Variable<String>(path);
    map['title'] = Variable<String>(title);
    map['title_norm'] = Variable<String>(titleNorm);
    map['artist'] = Variable<String>(artist);
    map['artist_norm'] = Variable<String>(artistNorm);
    map['album'] = Variable<String>(album);
    map['album_norm'] = Variable<String>(albumNorm);
    map['genre'] = Variable<String>(genre);
    map['track_no'] = Variable<int>(trackNo);
    map['plays'] = Variable<int>(plays);
    map['duration_ms'] = Variable<int>(durationMs);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['content_hash'] = Variable<String>(contentHash);
    map['audio_format'] = Variable<String>(audioFormat);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || coverCheckedAt != null) {
      map['cover_checked_at'] = Variable<DateTime>(coverCheckedAt);
    }
    if (!nullToAbsent || missingAt != null) {
      map['missing_at'] = Variable<DateTime>(missingAt);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    map['needs_meta'] = Variable<bool>(needsMeta);
    if (!nullToAbsent || enrichedAt != null) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt);
    }
    if (!nullToAbsent || titleMatchedAt != null) {
      map['title_matched_at'] = Variable<DateTime>(titleMatchedAt);
    }
    if (!nullToAbsent || artistMatchedAt != null) {
      map['artist_matched_at'] = Variable<DateTime>(artistMatchedAt);
    }
    if (!nullToAbsent || lyricsAt != null) {
      map['lyrics_at'] = Variable<DateTime>(lyricsAt);
    }
    if (!nullToAbsent || albumMatchedAt != null) {
      map['album_matched_at'] = Variable<DateTime>(albumMatchedAt);
    }
    if (!nullToAbsent || trackMatchedAt != null) {
      map['track_matched_at'] = Variable<DateTime>(trackMatchedAt);
    }
    map['enrich_attempts'] = Variable<int>(enrichAttempts);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      rootId: Value(rootId),
      relPath: Value(relPath),
      path: Value(path),
      title: Value(title),
      titleNorm: Value(titleNorm),
      artist: Value(artist),
      artistNorm: Value(artistNorm),
      album: Value(album),
      albumNorm: Value(albumNorm),
      genre: Value(genre),
      trackNo: Value(trackNo),
      plays: Value(plays),
      durationMs: Value(durationMs),
      sizeBytes: Value(sizeBytes),
      contentHash: Value(contentHash),
      audioFormat: Value(audioFormat),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      coverCheckedAt: coverCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(coverCheckedAt),
      missingAt: missingAt == null && nullToAbsent
          ? const Value.absent()
          : Value(missingAt),
      addedAt: Value(addedAt),
      needsMeta: Value(needsMeta),
      enrichedAt: enrichedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(enrichedAt),
      titleMatchedAt: titleMatchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(titleMatchedAt),
      artistMatchedAt: artistMatchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(artistMatchedAt),
      lyricsAt: lyricsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lyricsAt),
      albumMatchedAt: albumMatchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(albumMatchedAt),
      trackMatchedAt: trackMatchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(trackMatchedAt),
      enrichAttempts: Value(enrichAttempts),
    );
  }

  factory TrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<int>(json['id']),
      rootId: serializer.fromJson<int>(json['rootId']),
      relPath: serializer.fromJson<String>(json['relPath']),
      path: serializer.fromJson<String>(json['path']),
      title: serializer.fromJson<String>(json['title']),
      titleNorm: serializer.fromJson<String>(json['titleNorm']),
      artist: serializer.fromJson<String>(json['artist']),
      artistNorm: serializer.fromJson<String>(json['artistNorm']),
      album: serializer.fromJson<String>(json['album']),
      albumNorm: serializer.fromJson<String>(json['albumNorm']),
      genre: serializer.fromJson<String>(json['genre']),
      trackNo: serializer.fromJson<int>(json['trackNo']),
      plays: serializer.fromJson<int>(json['plays']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      audioFormat: serializer.fromJson<String>(json['audioFormat']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      coverCheckedAt: serializer.fromJson<DateTime?>(json['coverCheckedAt']),
      missingAt: serializer.fromJson<DateTime?>(json['missingAt']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      needsMeta: serializer.fromJson<bool>(json['needsMeta']),
      enrichedAt: serializer.fromJson<DateTime?>(json['enrichedAt']),
      titleMatchedAt: serializer.fromJson<DateTime?>(json['titleMatchedAt']),
      artistMatchedAt: serializer.fromJson<DateTime?>(json['artistMatchedAt']),
      lyricsAt: serializer.fromJson<DateTime?>(json['lyricsAt']),
      albumMatchedAt: serializer.fromJson<DateTime?>(json['albumMatchedAt']),
      trackMatchedAt: serializer.fromJson<DateTime?>(json['trackMatchedAt']),
      enrichAttempts: serializer.fromJson<int>(json['enrichAttempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rootId': serializer.toJson<int>(rootId),
      'relPath': serializer.toJson<String>(relPath),
      'path': serializer.toJson<String>(path),
      'title': serializer.toJson<String>(title),
      'titleNorm': serializer.toJson<String>(titleNorm),
      'artist': serializer.toJson<String>(artist),
      'artistNorm': serializer.toJson<String>(artistNorm),
      'album': serializer.toJson<String>(album),
      'albumNorm': serializer.toJson<String>(albumNorm),
      'genre': serializer.toJson<String>(genre),
      'trackNo': serializer.toJson<int>(trackNo),
      'plays': serializer.toJson<int>(plays),
      'durationMs': serializer.toJson<int>(durationMs),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'contentHash': serializer.toJson<String>(contentHash),
      'audioFormat': serializer.toJson<String>(audioFormat),
      'coverPath': serializer.toJson<String?>(coverPath),
      'coverCheckedAt': serializer.toJson<DateTime?>(coverCheckedAt),
      'missingAt': serializer.toJson<DateTime?>(missingAt),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'needsMeta': serializer.toJson<bool>(needsMeta),
      'enrichedAt': serializer.toJson<DateTime?>(enrichedAt),
      'titleMatchedAt': serializer.toJson<DateTime?>(titleMatchedAt),
      'artistMatchedAt': serializer.toJson<DateTime?>(artistMatchedAt),
      'lyricsAt': serializer.toJson<DateTime?>(lyricsAt),
      'albumMatchedAt': serializer.toJson<DateTime?>(albumMatchedAt),
      'trackMatchedAt': serializer.toJson<DateTime?>(trackMatchedAt),
      'enrichAttempts': serializer.toJson<int>(enrichAttempts),
    };
  }

  TrackRow copyWith({
    int? id,
    int? rootId,
    String? relPath,
    String? path,
    String? title,
    String? titleNorm,
    String? artist,
    String? artistNorm,
    String? album,
    String? albumNorm,
    String? genre,
    int? trackNo,
    int? plays,
    int? durationMs,
    int? sizeBytes,
    String? contentHash,
    String? audioFormat,
    Value<String?> coverPath = const Value.absent(),
    Value<DateTime?> coverCheckedAt = const Value.absent(),
    Value<DateTime?> missingAt = const Value.absent(),
    DateTime? addedAt,
    bool? needsMeta,
    Value<DateTime?> enrichedAt = const Value.absent(),
    Value<DateTime?> titleMatchedAt = const Value.absent(),
    Value<DateTime?> artistMatchedAt = const Value.absent(),
    Value<DateTime?> lyricsAt = const Value.absent(),
    Value<DateTime?> albumMatchedAt = const Value.absent(),
    Value<DateTime?> trackMatchedAt = const Value.absent(),
    int? enrichAttempts,
  }) => TrackRow(
    id: id ?? this.id,
    rootId: rootId ?? this.rootId,
    relPath: relPath ?? this.relPath,
    path: path ?? this.path,
    title: title ?? this.title,
    titleNorm: titleNorm ?? this.titleNorm,
    artist: artist ?? this.artist,
    artistNorm: artistNorm ?? this.artistNorm,
    album: album ?? this.album,
    albumNorm: albumNorm ?? this.albumNorm,
    genre: genre ?? this.genre,
    trackNo: trackNo ?? this.trackNo,
    plays: plays ?? this.plays,
    durationMs: durationMs ?? this.durationMs,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    contentHash: contentHash ?? this.contentHash,
    audioFormat: audioFormat ?? this.audioFormat,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    coverCheckedAt: coverCheckedAt.present
        ? coverCheckedAt.value
        : this.coverCheckedAt,
    missingAt: missingAt.present ? missingAt.value : this.missingAt,
    addedAt: addedAt ?? this.addedAt,
    needsMeta: needsMeta ?? this.needsMeta,
    enrichedAt: enrichedAt.present ? enrichedAt.value : this.enrichedAt,
    titleMatchedAt: titleMatchedAt.present
        ? titleMatchedAt.value
        : this.titleMatchedAt,
    artistMatchedAt: artistMatchedAt.present
        ? artistMatchedAt.value
        : this.artistMatchedAt,
    lyricsAt: lyricsAt.present ? lyricsAt.value : this.lyricsAt,
    albumMatchedAt: albumMatchedAt.present
        ? albumMatchedAt.value
        : this.albumMatchedAt,
    trackMatchedAt: trackMatchedAt.present
        ? trackMatchedAt.value
        : this.trackMatchedAt,
    enrichAttempts: enrichAttempts ?? this.enrichAttempts,
  );
  TrackRow copyWithCompanion(TracksCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      rootId: data.rootId.present ? data.rootId.value : this.rootId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      path: data.path.present ? data.path.value : this.path,
      title: data.title.present ? data.title.value : this.title,
      titleNorm: data.titleNorm.present ? data.titleNorm.value : this.titleNorm,
      artist: data.artist.present ? data.artist.value : this.artist,
      artistNorm: data.artistNorm.present
          ? data.artistNorm.value
          : this.artistNorm,
      album: data.album.present ? data.album.value : this.album,
      albumNorm: data.albumNorm.present ? data.albumNorm.value : this.albumNorm,
      genre: data.genre.present ? data.genre.value : this.genre,
      trackNo: data.trackNo.present ? data.trackNo.value : this.trackNo,
      plays: data.plays.present ? data.plays.value : this.plays,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      audioFormat: data.audioFormat.present
          ? data.audioFormat.value
          : this.audioFormat,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      coverCheckedAt: data.coverCheckedAt.present
          ? data.coverCheckedAt.value
          : this.coverCheckedAt,
      missingAt: data.missingAt.present ? data.missingAt.value : this.missingAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      needsMeta: data.needsMeta.present ? data.needsMeta.value : this.needsMeta,
      enrichedAt: data.enrichedAt.present
          ? data.enrichedAt.value
          : this.enrichedAt,
      titleMatchedAt: data.titleMatchedAt.present
          ? data.titleMatchedAt.value
          : this.titleMatchedAt,
      artistMatchedAt: data.artistMatchedAt.present
          ? data.artistMatchedAt.value
          : this.artistMatchedAt,
      lyricsAt: data.lyricsAt.present ? data.lyricsAt.value : this.lyricsAt,
      albumMatchedAt: data.albumMatchedAt.present
          ? data.albumMatchedAt.value
          : this.albumMatchedAt,
      trackMatchedAt: data.trackMatchedAt.present
          ? data.trackMatchedAt.value
          : this.trackMatchedAt,
      enrichAttempts: data.enrichAttempts.present
          ? data.enrichAttempts.value
          : this.enrichAttempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('rootId: $rootId, ')
          ..write('relPath: $relPath, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('titleNorm: $titleNorm, ')
          ..write('artist: $artist, ')
          ..write('artistNorm: $artistNorm, ')
          ..write('album: $album, ')
          ..write('albumNorm: $albumNorm, ')
          ..write('genre: $genre, ')
          ..write('trackNo: $trackNo, ')
          ..write('plays: $plays, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('contentHash: $contentHash, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverCheckedAt: $coverCheckedAt, ')
          ..write('missingAt: $missingAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('needsMeta: $needsMeta, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('titleMatchedAt: $titleMatchedAt, ')
          ..write('artistMatchedAt: $artistMatchedAt, ')
          ..write('lyricsAt: $lyricsAt, ')
          ..write('albumMatchedAt: $albumMatchedAt, ')
          ..write('trackMatchedAt: $trackMatchedAt, ')
          ..write('enrichAttempts: $enrichAttempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    rootId,
    relPath,
    path,
    title,
    titleNorm,
    artist,
    artistNorm,
    album,
    albumNorm,
    genre,
    trackNo,
    plays,
    durationMs,
    sizeBytes,
    contentHash,
    audioFormat,
    coverPath,
    coverCheckedAt,
    missingAt,
    addedAt,
    needsMeta,
    enrichedAt,
    titleMatchedAt,
    artistMatchedAt,
    lyricsAt,
    albumMatchedAt,
    trackMatchedAt,
    enrichAttempts,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.rootId == this.rootId &&
          other.relPath == this.relPath &&
          other.path == this.path &&
          other.title == this.title &&
          other.titleNorm == this.titleNorm &&
          other.artist == this.artist &&
          other.artistNorm == this.artistNorm &&
          other.album == this.album &&
          other.albumNorm == this.albumNorm &&
          other.genre == this.genre &&
          other.trackNo == this.trackNo &&
          other.plays == this.plays &&
          other.durationMs == this.durationMs &&
          other.sizeBytes == this.sizeBytes &&
          other.contentHash == this.contentHash &&
          other.audioFormat == this.audioFormat &&
          other.coverPath == this.coverPath &&
          other.coverCheckedAt == this.coverCheckedAt &&
          other.missingAt == this.missingAt &&
          other.addedAt == this.addedAt &&
          other.needsMeta == this.needsMeta &&
          other.enrichedAt == this.enrichedAt &&
          other.titleMatchedAt == this.titleMatchedAt &&
          other.artistMatchedAt == this.artistMatchedAt &&
          other.lyricsAt == this.lyricsAt &&
          other.albumMatchedAt == this.albumMatchedAt &&
          other.trackMatchedAt == this.trackMatchedAt &&
          other.enrichAttempts == this.enrichAttempts);
}

class TracksCompanion extends UpdateCompanion<TrackRow> {
  final Value<int> id;
  final Value<int> rootId;
  final Value<String> relPath;
  final Value<String> path;
  final Value<String> title;
  final Value<String> titleNorm;
  final Value<String> artist;
  final Value<String> artistNorm;
  final Value<String> album;
  final Value<String> albumNorm;
  final Value<String> genre;
  final Value<int> trackNo;
  final Value<int> plays;
  final Value<int> durationMs;
  final Value<int> sizeBytes;
  final Value<String> contentHash;
  final Value<String> audioFormat;
  final Value<String?> coverPath;
  final Value<DateTime?> coverCheckedAt;
  final Value<DateTime?> missingAt;
  final Value<DateTime> addedAt;
  final Value<bool> needsMeta;
  final Value<DateTime?> enrichedAt;
  final Value<DateTime?> titleMatchedAt;
  final Value<DateTime?> artistMatchedAt;
  final Value<DateTime?> lyricsAt;
  final Value<DateTime?> albumMatchedAt;
  final Value<DateTime?> trackMatchedAt;
  final Value<int> enrichAttempts;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.rootId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.path = const Value.absent(),
    this.title = const Value.absent(),
    this.titleNorm = const Value.absent(),
    this.artist = const Value.absent(),
    this.artistNorm = const Value.absent(),
    this.album = const Value.absent(),
    this.albumNorm = const Value.absent(),
    this.genre = const Value.absent(),
    this.trackNo = const Value.absent(),
    this.plays = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverCheckedAt = const Value.absent(),
    this.missingAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.needsMeta = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.titleMatchedAt = const Value.absent(),
    this.artistMatchedAt = const Value.absent(),
    this.lyricsAt = const Value.absent(),
    this.albumMatchedAt = const Value.absent(),
    this.trackMatchedAt = const Value.absent(),
    this.enrichAttempts = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required int rootId,
    required String relPath,
    required String path,
    required String title,
    required String titleNorm,
    required String artist,
    required String artistNorm,
    required String album,
    required String albumNorm,
    this.genre = const Value.absent(),
    this.trackNo = const Value.absent(),
    this.plays = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverCheckedAt = const Value.absent(),
    this.missingAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.needsMeta = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.titleMatchedAt = const Value.absent(),
    this.artistMatchedAt = const Value.absent(),
    this.lyricsAt = const Value.absent(),
    this.albumMatchedAt = const Value.absent(),
    this.trackMatchedAt = const Value.absent(),
    this.enrichAttempts = const Value.absent(),
  }) : rootId = Value(rootId),
       relPath = Value(relPath),
       path = Value(path),
       title = Value(title),
       titleNorm = Value(titleNorm),
       artist = Value(artist),
       artistNorm = Value(artistNorm),
       album = Value(album),
       albumNorm = Value(albumNorm);
  static Insertable<TrackRow> custom({
    Expression<int>? id,
    Expression<int>? rootId,
    Expression<String>? relPath,
    Expression<String>? path,
    Expression<String>? title,
    Expression<String>? titleNorm,
    Expression<String>? artist,
    Expression<String>? artistNorm,
    Expression<String>? album,
    Expression<String>? albumNorm,
    Expression<String>? genre,
    Expression<int>? trackNo,
    Expression<int>? plays,
    Expression<int>? durationMs,
    Expression<int>? sizeBytes,
    Expression<String>? contentHash,
    Expression<String>? audioFormat,
    Expression<String>? coverPath,
    Expression<DateTime>? coverCheckedAt,
    Expression<DateTime>? missingAt,
    Expression<DateTime>? addedAt,
    Expression<bool>? needsMeta,
    Expression<DateTime>? enrichedAt,
    Expression<DateTime>? titleMatchedAt,
    Expression<DateTime>? artistMatchedAt,
    Expression<DateTime>? lyricsAt,
    Expression<DateTime>? albumMatchedAt,
    Expression<DateTime>? trackMatchedAt,
    Expression<int>? enrichAttempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rootId != null) 'root_id': rootId,
      if (relPath != null) 'rel_path': relPath,
      if (path != null) 'path': path,
      if (title != null) 'title': title,
      if (titleNorm != null) 'title_norm': titleNorm,
      if (artist != null) 'artist': artist,
      if (artistNorm != null) 'artist_norm': artistNorm,
      if (album != null) 'album': album,
      if (albumNorm != null) 'album_norm': albumNorm,
      if (genre != null) 'genre': genre,
      if (trackNo != null) 'track_no': trackNo,
      if (plays != null) 'plays': plays,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (contentHash != null) 'content_hash': contentHash,
      if (audioFormat != null) 'audio_format': audioFormat,
      if (coverPath != null) 'cover_path': coverPath,
      if (coverCheckedAt != null) 'cover_checked_at': coverCheckedAt,
      if (missingAt != null) 'missing_at': missingAt,
      if (addedAt != null) 'added_at': addedAt,
      if (needsMeta != null) 'needs_meta': needsMeta,
      if (enrichedAt != null) 'enriched_at': enrichedAt,
      if (titleMatchedAt != null) 'title_matched_at': titleMatchedAt,
      if (artistMatchedAt != null) 'artist_matched_at': artistMatchedAt,
      if (lyricsAt != null) 'lyrics_at': lyricsAt,
      if (albumMatchedAt != null) 'album_matched_at': albumMatchedAt,
      if (trackMatchedAt != null) 'track_matched_at': trackMatchedAt,
      if (enrichAttempts != null) 'enrich_attempts': enrichAttempts,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<int>? rootId,
    Value<String>? relPath,
    Value<String>? path,
    Value<String>? title,
    Value<String>? titleNorm,
    Value<String>? artist,
    Value<String>? artistNorm,
    Value<String>? album,
    Value<String>? albumNorm,
    Value<String>? genre,
    Value<int>? trackNo,
    Value<int>? plays,
    Value<int>? durationMs,
    Value<int>? sizeBytes,
    Value<String>? contentHash,
    Value<String>? audioFormat,
    Value<String?>? coverPath,
    Value<DateTime?>? coverCheckedAt,
    Value<DateTime?>? missingAt,
    Value<DateTime>? addedAt,
    Value<bool>? needsMeta,
    Value<DateTime?>? enrichedAt,
    Value<DateTime?>? titleMatchedAt,
    Value<DateTime?>? artistMatchedAt,
    Value<DateTime?>? lyricsAt,
    Value<DateTime?>? albumMatchedAt,
    Value<DateTime?>? trackMatchedAt,
    Value<int>? enrichAttempts,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      rootId: rootId ?? this.rootId,
      relPath: relPath ?? this.relPath,
      path: path ?? this.path,
      title: title ?? this.title,
      titleNorm: titleNorm ?? this.titleNorm,
      artist: artist ?? this.artist,
      artistNorm: artistNorm ?? this.artistNorm,
      album: album ?? this.album,
      albumNorm: albumNorm ?? this.albumNorm,
      genre: genre ?? this.genre,
      trackNo: trackNo ?? this.trackNo,
      plays: plays ?? this.plays,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      contentHash: contentHash ?? this.contentHash,
      audioFormat: audioFormat ?? this.audioFormat,
      coverPath: coverPath ?? this.coverPath,
      coverCheckedAt: coverCheckedAt ?? this.coverCheckedAt,
      missingAt: missingAt ?? this.missingAt,
      addedAt: addedAt ?? this.addedAt,
      needsMeta: needsMeta ?? this.needsMeta,
      enrichedAt: enrichedAt ?? this.enrichedAt,
      titleMatchedAt: titleMatchedAt ?? this.titleMatchedAt,
      artistMatchedAt: artistMatchedAt ?? this.artistMatchedAt,
      lyricsAt: lyricsAt ?? this.lyricsAt,
      albumMatchedAt: albumMatchedAt ?? this.albumMatchedAt,
      trackMatchedAt: trackMatchedAt ?? this.trackMatchedAt,
      enrichAttempts: enrichAttempts ?? this.enrichAttempts,
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
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleNorm.present) {
      map['title_norm'] = Variable<String>(titleNorm.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (artistNorm.present) {
      map['artist_norm'] = Variable<String>(artistNorm.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumNorm.present) {
      map['album_norm'] = Variable<String>(albumNorm.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (trackNo.present) {
      map['track_no'] = Variable<int>(trackNo.value);
    }
    if (plays.present) {
      map['plays'] = Variable<int>(plays.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (audioFormat.present) {
      map['audio_format'] = Variable<String>(audioFormat.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (coverCheckedAt.present) {
      map['cover_checked_at'] = Variable<DateTime>(coverCheckedAt.value);
    }
    if (missingAt.present) {
      map['missing_at'] = Variable<DateTime>(missingAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (needsMeta.present) {
      map['needs_meta'] = Variable<bool>(needsMeta.value);
    }
    if (enrichedAt.present) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt.value);
    }
    if (titleMatchedAt.present) {
      map['title_matched_at'] = Variable<DateTime>(titleMatchedAt.value);
    }
    if (artistMatchedAt.present) {
      map['artist_matched_at'] = Variable<DateTime>(artistMatchedAt.value);
    }
    if (lyricsAt.present) {
      map['lyrics_at'] = Variable<DateTime>(lyricsAt.value);
    }
    if (albumMatchedAt.present) {
      map['album_matched_at'] = Variable<DateTime>(albumMatchedAt.value);
    }
    if (trackMatchedAt.present) {
      map['track_matched_at'] = Variable<DateTime>(trackMatchedAt.value);
    }
    if (enrichAttempts.present) {
      map['enrich_attempts'] = Variable<int>(enrichAttempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('rootId: $rootId, ')
          ..write('relPath: $relPath, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('titleNorm: $titleNorm, ')
          ..write('artist: $artist, ')
          ..write('artistNorm: $artistNorm, ')
          ..write('album: $album, ')
          ..write('albumNorm: $albumNorm, ')
          ..write('genre: $genre, ')
          ..write('trackNo: $trackNo, ')
          ..write('plays: $plays, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('contentHash: $contentHash, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverCheckedAt: $coverCheckedAt, ')
          ..write('missingAt: $missingAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('needsMeta: $needsMeta, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('titleMatchedAt: $titleMatchedAt, ')
          ..write('artistMatchedAt: $artistMatchedAt, ')
          ..write('lyricsAt: $lyricsAt, ')
          ..write('albumMatchedAt: $albumMatchedAt, ')
          ..write('trackMatchedAt: $trackMatchedAt, ')
          ..write('enrichAttempts: $enrichAttempts')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
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
  late final GeneratedColumnWithTypeConverter<PlaylistKindCol, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PlaylistKindCol>($PlaylistsTable.$converterkind);
  static const VerificationMeta _pendingMeta = const VerificationMeta(
    'pending',
  );
  @override
  late final GeneratedColumn<int> pending = GeneratedColumn<int>(
    'pending',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    pending,
    coverPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
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
    if (data.containsKey('pending')) {
      context.handle(
        _pendingMeta,
        pending.isAcceptableOrUnknown(data['pending']!, _pendingMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, kind},
  ];
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
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
      pending: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PlaylistKindCol, String, String> $converterkind =
      const EnumNameConverter<PlaylistKindCol>(PlaylistKindCol.values);
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final int id;
  final String name;
  final PlaylistKindCol kind;

  /// GitHub 拉取歌单：待提取曲目数（0=无待提取）。
  final int pending;

  /// 自定义歌单封面图片（应用沙箱内路径；null=用首曲封面/字块）。
  final String? coverPath;
  final DateTime createdAt;
  const PlaylistRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.pending,
    this.coverPath,
    required this.createdAt,
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
    map['pending'] = Variable<int>(pending);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      pending: Value(pending),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      createdAt: Value(createdAt),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: $PlaylistsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      pending: serializer.fromJson<int>(json['pending']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
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
      'pending': serializer.toJson<int>(pending),
      'coverPath': serializer.toJson<String?>(coverPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PlaylistRow copyWith({
    int? id,
    String? name,
    PlaylistKindCol? kind,
    int? pending,
    Value<String?> coverPath = const Value.absent(),
    DateTime? createdAt,
  }) => PlaylistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    pending: pending ?? this.pending,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    createdAt: createdAt ?? this.createdAt,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      pending: data.pending.present ? data.pending.value : this.pending,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('pending: $pending, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, kind, pending, coverPath, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.pending == this.pending &&
          other.coverPath == this.coverPath &&
          other.createdAt == this.createdAt);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<PlaylistKindCol> kind;
  final Value<int> pending;
  final Value<String?> coverPath;
  final Value<DateTime> createdAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.pending = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required PlaylistKindCol kind,
    this.pending = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       kind = Value(kind);
  static Insertable<PlaylistRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? pending,
    Expression<String>? coverPath,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (pending != null) 'pending': pending,
      if (coverPath != null) 'cover_path': coverPath,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<PlaylistKindCol>? kind,
    Value<int>? pending,
    Value<String?>? coverPath,
    Value<DateTime>? createdAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      pending: pending ?? this.pending,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt ?? this.createdAt,
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
    if (pending.present) {
      map['pending'] = Variable<int>(pending.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('pending: $pending, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt')
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
      'REFERENCES playlists (id)',
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
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
        DriftSqlType.dateTime,
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
  final DateTime addedAt;
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
    map['added_at'] = Variable<DateTime>(addedAt);
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
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
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
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  PlaylistTrack copyWith({
    int? id,
    int? playlistId,
    int? trackId,
    int? position,
    DateTime? addedAt,
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
  final Value<DateTime> addedAt;
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
    this.addedAt = const Value.absent(),
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId),
       position = Value(position);
  static Insertable<PlaylistTrack> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<int>? trackId,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
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
    Value<DateTime>? addedAt,
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
      map['added_at'] = Variable<DateTime>(addedAt.value);
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
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, trackId, playedAt, completed];
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
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
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
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
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
  final DateTime playedAt;
  final bool completed;
  const PlayHistoryData({
    required this.id,
    required this.trackId,
    required this.playedAt,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['played_at'] = Variable<DateTime>(playedAt);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  PlayHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoryCompanion(
      id: Value(id),
      trackId: Value(trackId),
      playedAt: Value(playedAt),
      completed: Value(completed),
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
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'playedAt': serializer.toJson<DateTime>(playedAt),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  PlayHistoryData copyWith({
    int? id,
    int? trackId,
    DateTime? playedAt,
    bool? completed,
  }) => PlayHistoryData(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    playedAt: playedAt ?? this.playedAt,
    completed: completed ?? this.completed,
  );
  PlayHistoryData copyWithCompanion(PlayHistoryCompanion data) {
    return PlayHistoryData(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryData(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackId, playedAt, completed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryData &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.playedAt == this.playedAt &&
          other.completed == this.completed);
}

class PlayHistoryCompanion extends UpdateCompanion<PlayHistoryData> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<DateTime> playedAt;
  final Value<bool> completed;
  const PlayHistoryCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.completed = const Value.absent(),
  });
  PlayHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    this.playedAt = const Value.absent(),
    this.completed = const Value.absent(),
  }) : trackId = Value(trackId);
  static Insertable<PlayHistoryData> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<DateTime>? playedAt,
    Expression<bool>? completed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (playedAt != null) 'played_at': playedAt,
      if (completed != null) 'completed': completed,
    });
  }

  PlayHistoryCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<DateTime>? playedAt,
    Value<bool>? completed,
  }) {
    return PlayHistoryCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      playedAt: playedAt ?? this.playedAt,
      completed: completed ?? this.completed,
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
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }
}

class $LyricsMetaTable extends LyricsMeta
    with TableInfo<$LyricsMetaTable, LyricsMetaRow> {
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
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
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    kind,
    lrcPath,
    offsetMs,
    edited,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricsMetaRow> instance, {
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
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('lrc_path')) {
      context.handle(
        _lrcPathMeta,
        lrcPath.isAcceptableOrUnknown(data['lrc_path']!, _lrcPathMeta),
      );
    }
    if (data.containsKey('offset_ms')) {
      context.handle(
        _offsetMsMeta,
        offsetMs.isAcceptableOrUnknown(data['offset_ms']!, _offsetMsMeta),
      );
    }
    if (data.containsKey('edited')) {
      context.handle(
        _editedMeta,
        edited.isAcceptableOrUnknown(data['edited']!, _editedMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  LyricsMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsMetaRow(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      lrcPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lrc_path'],
      ),
      offsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_ms'],
      )!,
      edited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}edited'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      ),
    );
  }

  @override
  $LyricsMetaTable createAlias(String alias) {
    return $LyricsMetaTable(attachedDatabase, alias);
  }
}

class LyricsMetaRow extends DataClass implements Insertable<LyricsMetaRow> {
  final int trackId;

  /// none/sidecar/embedded/online/pasted
  final String kind;
  final String? lrcPath;
  final int offsetMs;
  final bool edited;
  final DateTime? fetchedAt;
  const LyricsMetaRow({
    required this.trackId,
    required this.kind,
    this.lrcPath,
    required this.offsetMs,
    required this.edited,
    this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || lrcPath != null) {
      map['lrc_path'] = Variable<String>(lrcPath);
    }
    map['offset_ms'] = Variable<int>(offsetMs);
    map['edited'] = Variable<bool>(edited);
    if (!nullToAbsent || fetchedAt != null) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt);
    }
    return map;
  }

  LyricsMetaCompanion toCompanion(bool nullToAbsent) {
    return LyricsMetaCompanion(
      trackId: Value(trackId),
      kind: Value(kind),
      lrcPath: lrcPath == null && nullToAbsent
          ? const Value.absent()
          : Value(lrcPath),
      offsetMs: Value(offsetMs),
      edited: Value(edited),
      fetchedAt: fetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fetchedAt),
    );
  }

  factory LyricsMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsMetaRow(
      trackId: serializer.fromJson<int>(json['trackId']),
      kind: serializer.fromJson<String>(json['kind']),
      lrcPath: serializer.fromJson<String?>(json['lrcPath']),
      offsetMs: serializer.fromJson<int>(json['offsetMs']),
      edited: serializer.fromJson<bool>(json['edited']),
      fetchedAt: serializer.fromJson<DateTime?>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'kind': serializer.toJson<String>(kind),
      'lrcPath': serializer.toJson<String?>(lrcPath),
      'offsetMs': serializer.toJson<int>(offsetMs),
      'edited': serializer.toJson<bool>(edited),
      'fetchedAt': serializer.toJson<DateTime?>(fetchedAt),
    };
  }

  LyricsMetaRow copyWith({
    int? trackId,
    String? kind,
    Value<String?> lrcPath = const Value.absent(),
    int? offsetMs,
    bool? edited,
    Value<DateTime?> fetchedAt = const Value.absent(),
  }) => LyricsMetaRow(
    trackId: trackId ?? this.trackId,
    kind: kind ?? this.kind,
    lrcPath: lrcPath.present ? lrcPath.value : this.lrcPath,
    offsetMs: offsetMs ?? this.offsetMs,
    edited: edited ?? this.edited,
    fetchedAt: fetchedAt.present ? fetchedAt.value : this.fetchedAt,
  );
  LyricsMetaRow copyWithCompanion(LyricsMetaCompanion data) {
    return LyricsMetaRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      kind: data.kind.present ? data.kind.value : this.kind,
      lrcPath: data.lrcPath.present ? data.lrcPath.value : this.lrcPath,
      offsetMs: data.offsetMs.present ? data.offsetMs.value : this.offsetMs,
      edited: data.edited.present ? data.edited.value : this.edited,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsMetaRow(')
          ..write('trackId: $trackId, ')
          ..write('kind: $kind, ')
          ..write('lrcPath: $lrcPath, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('edited: $edited, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trackId, kind, lrcPath, offsetMs, edited, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsMetaRow &&
          other.trackId == this.trackId &&
          other.kind == this.kind &&
          other.lrcPath == this.lrcPath &&
          other.offsetMs == this.offsetMs &&
          other.edited == this.edited &&
          other.fetchedAt == this.fetchedAt);
}

class LyricsMetaCompanion extends UpdateCompanion<LyricsMetaRow> {
  final Value<int> trackId;
  final Value<String> kind;
  final Value<String?> lrcPath;
  final Value<int> offsetMs;
  final Value<bool> edited;
  final Value<DateTime?> fetchedAt;
  const LyricsMetaCompanion({
    this.trackId = const Value.absent(),
    this.kind = const Value.absent(),
    this.lrcPath = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.edited = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  LyricsMetaCompanion.insert({
    this.trackId = const Value.absent(),
    this.kind = const Value.absent(),
    this.lrcPath = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.edited = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  static Insertable<LyricsMetaRow> custom({
    Expression<int>? trackId,
    Expression<String>? kind,
    Expression<String>? lrcPath,
    Expression<int>? offsetMs,
    Expression<bool>? edited,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (kind != null) 'kind': kind,
      if (lrcPath != null) 'lrc_path': lrcPath,
      if (offsetMs != null) 'offset_ms': offsetMs,
      if (edited != null) 'edited': edited,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  LyricsMetaCompanion copyWith({
    Value<int>? trackId,
    Value<String>? kind,
    Value<String?>? lrcPath,
    Value<int>? offsetMs,
    Value<bool>? edited,
    Value<DateTime?>? fetchedAt,
  }) {
    return LyricsMetaCompanion(
      trackId: trackId ?? this.trackId,
      kind: kind ?? this.kind,
      lrcPath: lrcPath ?? this.lrcPath,
      offsetMs: offsetMs ?? this.offsetMs,
      edited: edited ?? this.edited,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (lrcPath.present) {
      map['lrc_path'] = Variable<String>(lrcPath.value);
    }
    if (offsetMs.present) {
      map['offset_ms'] = Variable<int>(offsetMs.value);
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsMetaCompanion(')
          ..write('trackId: $trackId, ')
          ..write('kind: $kind, ')
          ..write('lrcPath: $lrcPath, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('edited: $edited, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

class $TrackVectorsTable extends TrackVectors
    with TableInfo<$TrackVectorsTable, TrackVectorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackVectorsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimMeta = const VerificationMeta('dim');
  @override
  late final GeneratedColumn<int> dim = GeneratedColumn<int>(
    'dim',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vecMeta = const VerificationMeta('vec');
  @override
  late final GeneratedColumn<Uint8List> vec = GeneratedColumn<Uint8List>(
    'vec',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vectorAtMeta = const VerificationMeta(
    'vectorAt',
  );
  @override
  late final GeneratedColumn<DateTime> vectorAt = GeneratedColumn<DateTime>(
    'vector_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, model, dim, vec, vectorAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_vectors';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackVectorRow> instance, {
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
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('dim')) {
      context.handle(
        _dimMeta,
        dim.isAcceptableOrUnknown(data['dim']!, _dimMeta),
      );
    } else if (isInserting) {
      context.missing(_dimMeta);
    }
    if (data.containsKey('vec')) {
      context.handle(
        _vecMeta,
        vec.isAcceptableOrUnknown(data['vec']!, _vecMeta),
      );
    } else if (isInserting) {
      context.missing(_vecMeta);
    }
    if (data.containsKey('vector_at')) {
      context.handle(
        _vectorAtMeta,
        vectorAt.isAcceptableOrUnknown(data['vector_at']!, _vectorAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  TrackVectorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackVectorRow(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      dim: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dim'],
      )!,
      vec: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}vec'],
      )!,
      vectorAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}vector_at'],
      )!,
    );
  }

  @override
  $TrackVectorsTable createAlias(String alias) {
    return $TrackVectorsTable(attachedDatabase, alias);
  }
}

class TrackVectorRow extends DataClass implements Insertable<TrackVectorRow> {
  final int trackId;

  /// 嵌入模型标识（yamnet-1024-v1…）——向量没有模型版本就是死字节；
  /// 换模型按本列过滤重算，upsert 覆盖旧向量不混用。
  final String model;
  final int dim;

  /// float32 LE 紧凑存（1024 维 = 4KB/首）——JSON 文本会膨胀 8-10 倍。
  final Uint8List vec;
  final DateTime vectorAt;
  const TrackVectorRow({
    required this.trackId,
    required this.model,
    required this.dim,
    required this.vec,
    required this.vectorAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['model'] = Variable<String>(model);
    map['dim'] = Variable<int>(dim);
    map['vec'] = Variable<Uint8List>(vec);
    map['vector_at'] = Variable<DateTime>(vectorAt);
    return map;
  }

  TrackVectorsCompanion toCompanion(bool nullToAbsent) {
    return TrackVectorsCompanion(
      trackId: Value(trackId),
      model: Value(model),
      dim: Value(dim),
      vec: Value(vec),
      vectorAt: Value(vectorAt),
    );
  }

  factory TrackVectorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackVectorRow(
      trackId: serializer.fromJson<int>(json['trackId']),
      model: serializer.fromJson<String>(json['model']),
      dim: serializer.fromJson<int>(json['dim']),
      vec: serializer.fromJson<Uint8List>(json['vec']),
      vectorAt: serializer.fromJson<DateTime>(json['vectorAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'model': serializer.toJson<String>(model),
      'dim': serializer.toJson<int>(dim),
      'vec': serializer.toJson<Uint8List>(vec),
      'vectorAt': serializer.toJson<DateTime>(vectorAt),
    };
  }

  TrackVectorRow copyWith({
    int? trackId,
    String? model,
    int? dim,
    Uint8List? vec,
    DateTime? vectorAt,
  }) => TrackVectorRow(
    trackId: trackId ?? this.trackId,
    model: model ?? this.model,
    dim: dim ?? this.dim,
    vec: vec ?? this.vec,
    vectorAt: vectorAt ?? this.vectorAt,
  );
  TrackVectorRow copyWithCompanion(TrackVectorsCompanion data) {
    return TrackVectorRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      model: data.model.present ? data.model.value : this.model,
      dim: data.dim.present ? data.dim.value : this.dim,
      vec: data.vec.present ? data.vec.value : this.vec,
      vectorAt: data.vectorAt.present ? data.vectorAt.value : this.vectorAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackVectorRow(')
          ..write('trackId: $trackId, ')
          ..write('model: $model, ')
          ..write('dim: $dim, ')
          ..write('vec: $vec, ')
          ..write('vectorAt: $vectorAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trackId, model, dim, $driftBlobEquality.hash(vec), vectorAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackVectorRow &&
          other.trackId == this.trackId &&
          other.model == this.model &&
          other.dim == this.dim &&
          $driftBlobEquality.equals(other.vec, this.vec) &&
          other.vectorAt == this.vectorAt);
}

class TrackVectorsCompanion extends UpdateCompanion<TrackVectorRow> {
  final Value<int> trackId;
  final Value<String> model;
  final Value<int> dim;
  final Value<Uint8List> vec;
  final Value<DateTime> vectorAt;
  const TrackVectorsCompanion({
    this.trackId = const Value.absent(),
    this.model = const Value.absent(),
    this.dim = const Value.absent(),
    this.vec = const Value.absent(),
    this.vectorAt = const Value.absent(),
  });
  TrackVectorsCompanion.insert({
    this.trackId = const Value.absent(),
    required String model,
    required int dim,
    required Uint8List vec,
    this.vectorAt = const Value.absent(),
  }) : model = Value(model),
       dim = Value(dim),
       vec = Value(vec);
  static Insertable<TrackVectorRow> custom({
    Expression<int>? trackId,
    Expression<String>? model,
    Expression<int>? dim,
    Expression<Uint8List>? vec,
    Expression<DateTime>? vectorAt,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (model != null) 'model': model,
      if (dim != null) 'dim': dim,
      if (vec != null) 'vec': vec,
      if (vectorAt != null) 'vector_at': vectorAt,
    });
  }

  TrackVectorsCompanion copyWith({
    Value<int>? trackId,
    Value<String>? model,
    Value<int>? dim,
    Value<Uint8List>? vec,
    Value<DateTime>? vectorAt,
  }) {
    return TrackVectorsCompanion(
      trackId: trackId ?? this.trackId,
      model: model ?? this.model,
      dim: dim ?? this.dim,
      vec: vec ?? this.vec,
      vectorAt: vectorAt ?? this.vectorAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (dim.present) {
      map['dim'] = Variable<int>(dim.value);
    }
    if (vec.present) {
      map['vec'] = Variable<Uint8List>(vec.value);
    }
    if (vectorAt.present) {
      map['vector_at'] = Variable<DateTime>(vectorAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackVectorsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('model: $model, ')
          ..write('dim: $dim, ')
          ..write('vec: $vec, ')
          ..write('vectorAt: $vectorAt')
          ..write(')'))
        .toString();
  }
}

class $ModelFilesTable extends ModelFiles
    with TableInfo<$ModelFilesTable, ModelFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
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
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readyAtMeta = const VerificationMeta(
    'readyAt',
  );
  @override
  late final GeneratedColumn<DateTime> readyAt = GeneratedColumn<DateTime>(
    'ready_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    sha256,
    filePath,
    sizeBytes,
    readyAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('ready_at')) {
      context.handle(
        _readyAtMeta,
        readyAt.isAcceptableOrUnknown(data['ready_at']!, _readyAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelFileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      readyAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ready_at'],
      )!,
    );
  }

  @override
  $ModelFilesTable createAlias(String alias) {
    return $ModelFilesTable(attachedDatabase, alias);
  }
}

class ModelFileRow extends DataClass implements Insertable<ModelFileRow> {
  final String id;
  final String url;
  final String sha256;
  final String filePath;
  final int sizeBytes;
  final DateTime readyAt;
  const ModelFileRow({
    required this.id,
    required this.url,
    required this.sha256,
    required this.filePath,
    required this.sizeBytes,
    required this.readyAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    map['sha256'] = Variable<String>(sha256);
    map['file_path'] = Variable<String>(filePath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['ready_at'] = Variable<DateTime>(readyAt);
    return map;
  }

  ModelFilesCompanion toCompanion(bool nullToAbsent) {
    return ModelFilesCompanion(
      id: Value(id),
      url: Value(url),
      sha256: Value(sha256),
      filePath: Value(filePath),
      sizeBytes: Value(sizeBytes),
      readyAt: Value(readyAt),
    );
  }

  factory ModelFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelFileRow(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      sha256: serializer.fromJson<String>(json['sha256']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      readyAt: serializer.fromJson<DateTime>(json['readyAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'sha256': serializer.toJson<String>(sha256),
      'filePath': serializer.toJson<String>(filePath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'readyAt': serializer.toJson<DateTime>(readyAt),
    };
  }

  ModelFileRow copyWith({
    String? id,
    String? url,
    String? sha256,
    String? filePath,
    int? sizeBytes,
    DateTime? readyAt,
  }) => ModelFileRow(
    id: id ?? this.id,
    url: url ?? this.url,
    sha256: sha256 ?? this.sha256,
    filePath: filePath ?? this.filePath,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    readyAt: readyAt ?? this.readyAt,
  );
  ModelFileRow copyWithCompanion(ModelFilesCompanion data) {
    return ModelFileRow(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      readyAt: data.readyAt.present ? data.readyAt.value : this.readyAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelFileRow(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('sha256: $sha256, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('readyAt: $readyAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, url, sha256, filePath, sizeBytes, readyAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelFileRow &&
          other.id == this.id &&
          other.url == this.url &&
          other.sha256 == this.sha256 &&
          other.filePath == this.filePath &&
          other.sizeBytes == this.sizeBytes &&
          other.readyAt == this.readyAt);
}

class ModelFilesCompanion extends UpdateCompanion<ModelFileRow> {
  final Value<String> id;
  final Value<String> url;
  final Value<String> sha256;
  final Value<String> filePath;
  final Value<int> sizeBytes;
  final Value<DateTime> readyAt;
  final Value<int> rowid;
  const ModelFilesCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.readyAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelFilesCompanion.insert({
    required String id,
    required String url,
    required String sha256,
    required String filePath,
    this.sizeBytes = const Value.absent(),
    this.readyAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       sha256 = Value(sha256),
       filePath = Value(filePath);
  static Insertable<ModelFileRow> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? sha256,
    Expression<String>? filePath,
    Expression<int>? sizeBytes,
    Expression<DateTime>? readyAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (sha256 != null) 'sha256': sha256,
      if (filePath != null) 'file_path': filePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (readyAt != null) 'ready_at': readyAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelFilesCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String>? sha256,
    Value<String>? filePath,
    Value<int>? sizeBytes,
    Value<DateTime>? readyAt,
    Value<int>? rowid,
  }) {
    return ModelFilesCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      sha256: sha256 ?? this.sha256,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      readyAt: readyAt ?? this.readyAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (readyAt.present) {
      map['ready_at'] = Variable<DateTime>(readyAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelFilesCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('sha256: $sha256, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('readyAt: $readyAt, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson];
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
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
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
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
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
  final String valueJson;
  const Setting({required this.key, required this.valueJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), valueJson: Value(valueJson));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
    };
  }

  Setting copyWith({String? key, String? valueJson}) =>
      Setting(key: key ?? this.key, valueJson: valueJson ?? this.valueJson);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.key == this.key &&
          other.valueJson == this.valueJson);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String valueJson,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
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
          ..write('valueJson: $valueJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectTasksTable extends CollectTasks
    with TableInfo<$CollectTasksTable, CollectTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectTasksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CollectStatusCol, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      ).withConverter<CollectStatusCol>($CollectTasksTable.$converterstatus);
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricsPathMeta = const VerificationMeta(
    'lyricsPath',
  );
  @override
  late final GeneratedColumn<String> lyricsPath = GeneratedColumn<String>(
    'lyrics_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorTextMeta = const VerificationMeta(
    'errorText',
  );
  @override
  late final GeneratedColumn<String> errorText = GeneratedColumn<String>(
    'error_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    query,
    url,
    title,
    artist,
    status,
    progress,
    filePath,
    lyricsPath,
    errorText,
    playlistId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collect_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
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
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('lyrics_path')) {
      context.handle(
        _lyricsPathMeta,
        lyricsPath.isAcceptableOrUnknown(data['lyrics_path']!, _lyricsPathMeta),
      );
    }
    if (data.containsKey('error_text')) {
      context.handle(
        _errorTextMeta,
        errorText.isAcceptableOrUnknown(data['error_text']!, _errorTextMeta),
      );
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {url, title, artist},
  ];
  @override
  CollectTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectTaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      status: $CollectTasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      lyricsPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics_path'],
      ),
      errorText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_text'],
      ),
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CollectTasksTable createAlias(String alias) {
    return $CollectTasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CollectStatusCol, String, String> $converterstatus =
      const EnumNameConverter<CollectStatusCol>(CollectStatusCol.values);
}

class CollectTaskRow extends DataClass implements Insertable<CollectTaskRow> {
  final int id;
  final String source;
  final String query;
  final String url;
  final String title;
  final String artist;
  final CollectStatusCol status;
  final int progress;
  final String? filePath;
  final String? lyricsPath;
  final String? errorText;
  final int? playlistId;
  final DateTime createdAt;
  const CollectTaskRow({
    required this.id,
    required this.source,
    required this.query,
    required this.url,
    required this.title,
    required this.artist,
    required this.status,
    required this.progress,
    this.filePath,
    this.lyricsPath,
    this.errorText,
    this.playlistId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['query'] = Variable<String>(query);
    map['url'] = Variable<String>(url);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    {
      map['status'] = Variable<String>(
        $CollectTasksTable.$converterstatus.toSql(status),
      );
    }
    map['progress'] = Variable<int>(progress);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || lyricsPath != null) {
      map['lyrics_path'] = Variable<String>(lyricsPath);
    }
    if (!nullToAbsent || errorText != null) {
      map['error_text'] = Variable<String>(errorText);
    }
    if (!nullToAbsent || playlistId != null) {
      map['playlist_id'] = Variable<int>(playlistId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CollectTasksCompanion toCompanion(bool nullToAbsent) {
    return CollectTasksCompanion(
      id: Value(id),
      source: Value(source),
      query: Value(query),
      url: Value(url),
      title: Value(title),
      artist: Value(artist),
      status: Value(status),
      progress: Value(progress),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      lyricsPath: lyricsPath == null && nullToAbsent
          ? const Value.absent()
          : Value(lyricsPath),
      errorText: errorText == null && nullToAbsent
          ? const Value.absent()
          : Value(errorText),
      playlistId: playlistId == null && nullToAbsent
          ? const Value.absent()
          : Value(playlistId),
      createdAt: Value(createdAt),
    );
  }

  factory CollectTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectTaskRow(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      query: serializer.fromJson<String>(json['query']),
      url: serializer.fromJson<String>(json['url']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      status: $CollectTasksTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      progress: serializer.fromJson<int>(json['progress']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      lyricsPath: serializer.fromJson<String?>(json['lyricsPath']),
      errorText: serializer.fromJson<String?>(json['errorText']),
      playlistId: serializer.fromJson<int?>(json['playlistId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'query': serializer.toJson<String>(query),
      'url': serializer.toJson<String>(url),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'status': serializer.toJson<String>(
        $CollectTasksTable.$converterstatus.toJson(status),
      ),
      'progress': serializer.toJson<int>(progress),
      'filePath': serializer.toJson<String?>(filePath),
      'lyricsPath': serializer.toJson<String?>(lyricsPath),
      'errorText': serializer.toJson<String?>(errorText),
      'playlistId': serializer.toJson<int?>(playlistId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CollectTaskRow copyWith({
    int? id,
    String? source,
    String? query,
    String? url,
    String? title,
    String? artist,
    CollectStatusCol? status,
    int? progress,
    Value<String?> filePath = const Value.absent(),
    Value<String?> lyricsPath = const Value.absent(),
    Value<String?> errorText = const Value.absent(),
    Value<int?> playlistId = const Value.absent(),
    DateTime? createdAt,
  }) => CollectTaskRow(
    id: id ?? this.id,
    source: source ?? this.source,
    query: query ?? this.query,
    url: url ?? this.url,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    filePath: filePath.present ? filePath.value : this.filePath,
    lyricsPath: lyricsPath.present ? lyricsPath.value : this.lyricsPath,
    errorText: errorText.present ? errorText.value : this.errorText,
    playlistId: playlistId.present ? playlistId.value : this.playlistId,
    createdAt: createdAt ?? this.createdAt,
  );
  CollectTaskRow copyWithCompanion(CollectTasksCompanion data) {
    return CollectTaskRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      query: data.query.present ? data.query.value : this.query,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      lyricsPath: data.lyricsPath.present
          ? data.lyricsPath.value
          : this.lyricsPath,
      errorText: data.errorText.present ? data.errorText.value : this.errorText,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectTaskRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('query: $query, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('filePath: $filePath, ')
          ..write('lyricsPath: $lyricsPath, ')
          ..write('errorText: $errorText, ')
          ..write('playlistId: $playlistId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    query,
    url,
    title,
    artist,
    status,
    progress,
    filePath,
    lyricsPath,
    errorText,
    playlistId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectTaskRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.query == this.query &&
          other.url == this.url &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.filePath == this.filePath &&
          other.lyricsPath == this.lyricsPath &&
          other.errorText == this.errorText &&
          other.playlistId == this.playlistId &&
          other.createdAt == this.createdAt);
}

class CollectTasksCompanion extends UpdateCompanion<CollectTaskRow> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> query;
  final Value<String> url;
  final Value<String> title;
  final Value<String> artist;
  final Value<CollectStatusCol> status;
  final Value<int> progress;
  final Value<String?> filePath;
  final Value<String?> lyricsPath;
  final Value<String?> errorText;
  final Value<int?> playlistId;
  final Value<DateTime> createdAt;
  const CollectTasksCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.query = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.filePath = const Value.absent(),
    this.lyricsPath = const Value.absent(),
    this.errorText = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CollectTasksCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    this.query = const Value.absent(),
    required String url,
    required String title,
    required String artist,
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.filePath = const Value.absent(),
    this.lyricsPath = const Value.absent(),
    this.errorText = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : source = Value(source),
       url = Value(url),
       title = Value(title),
       artist = Value(artist);
  static Insertable<CollectTaskRow> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? query,
    Expression<String>? url,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? status,
    Expression<int>? progress,
    Expression<String>? filePath,
    Expression<String>? lyricsPath,
    Expression<String>? errorText,
    Expression<int>? playlistId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (query != null) 'query': query,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (filePath != null) 'file_path': filePath,
      if (lyricsPath != null) 'lyrics_path': lyricsPath,
      if (errorText != null) 'error_text': errorText,
      if (playlistId != null) 'playlist_id': playlistId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CollectTasksCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? query,
    Value<String>? url,
    Value<String>? title,
    Value<String>? artist,
    Value<CollectStatusCol>? status,
    Value<int>? progress,
    Value<String?>? filePath,
    Value<String?>? lyricsPath,
    Value<String?>? errorText,
    Value<int?>? playlistId,
    Value<DateTime>? createdAt,
  }) {
    return CollectTasksCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      query: query ?? this.query,
      url: url ?? this.url,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      lyricsPath: lyricsPath ?? this.lyricsPath,
      errorText: errorText ?? this.errorText,
      playlistId: playlistId ?? this.playlistId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $CollectTasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (lyricsPath.present) {
      map['lyrics_path'] = Variable<String>(lyricsPath.value);
    }
    if (errorText.present) {
      map['error_text'] = Variable<String>(errorText.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectTasksCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('query: $query, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('filePath: $filePath, ')
          ..write('lyricsPath: $lyricsPath, ')
          ..write('errorText: $errorText, ')
          ..write('playlistId: $playlistId, ')
          ..write('createdAt: $createdAt')
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
  late final $TracksTable tracks = $TracksTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  late final $PlayHistoryTable playHistory = $PlayHistoryTable(this);
  late final $LyricsMetaTable lyricsMeta = $LyricsMetaTable(this);
  late final $TrackVectorsTable trackVectors = $TrackVectorsTable(this);
  late final $ModelFilesTable modelFiles = $ModelFilesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $CollectTasksTable collectTasks = $CollectTasksTable(this);
  late final LibraryDao libraryDao = LibraryDao(this as IaDatabase);
  late final PlaylistDao playlistDao = PlaylistDao(this as IaDatabase);
  late final HistoryDao historyDao = HistoryDao(this as IaDatabase);
  late final CollectDao collectDao = CollectDao(this as IaDatabase);
  late final LyricsDao lyricsDao = LyricsDao(this as IaDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as IaDatabase);
  late final VectorDao vectorDao = VectorDao(this as IaDatabase);
  late final ModelDao modelDao = ModelDao(this as IaDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    repositoryRoots,
    tracks,
    playlists,
    playlistTracks,
    playHistory,
    lyricsMeta,
    trackVectors,
    modelFiles,
    settings,
    collectTasks,
  ];
}

typedef $$RepositoryRootsTableCreateCompanionBuilder =
    RepositoryRootsCompanion Function({
      Value<int> id,
      required String path,
      Value<DateTime> addedAt,
    });
typedef $$RepositoryRootsTableUpdateCompanionBuilder =
    RepositoryRootsCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<DateTime> addedAt,
    });

final class $$RepositoryRootsTableReferences
    extends
        BaseReferences<_$IaDatabase, $RepositoryRootsTable, RepositoryRoot> {
  $$RepositoryRootsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TracksTable, List<TrackRow>> _tracksRefsTable(
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

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
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

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
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

  GeneratedColumn<DateTime> get addedAt =>
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
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> path = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
          }) => RepositoryRootsCompanion(id: id, path: path, addedAt: addedAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                Value<DateTime> addedAt = const Value.absent(),
              }) => RepositoryRootsCompanion.insert(
                id: id,
                path: path,
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
                    await $_getPrefetchedDataByColumns<
                      RepositoryRoot,
                      $RepositoryRootsTable,
                      TrackRow,
                      $TracksTable
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
                      currentColumn: 'id',
                      referencedColumn: 'root_id',
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
typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  required int rootId,
  required String relPath,
  required String path,
  required String title,
  required String titleNorm,
  required String artist,
  required String artistNorm,
  required String album,
  required String albumNorm,
  Value<String> genre,
  Value<int> trackNo,
  Value<int> plays,
  Value<int> durationMs,
  Value<int> sizeBytes,
  Value<String> contentHash,
  Value<String> audioFormat,
  Value<String?> coverPath,
  Value<DateTime?> coverCheckedAt,
  Value<DateTime?> missingAt,
  Value<DateTime> addedAt,
  Value<bool> needsMeta,
  Value<DateTime?> enrichedAt,
  Value<DateTime?> titleMatchedAt,
  Value<DateTime?> artistMatchedAt,
  Value<DateTime?> lyricsAt,
  Value<DateTime?> albumMatchedAt,
  Value<DateTime?> trackMatchedAt,
  Value<int> enrichAttempts,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<int> rootId,
  Value<String> relPath,
  Value<String> path,
  Value<String> title,
  Value<String> titleNorm,
  Value<String> artist,
  Value<String> artistNorm,
  Value<String> album,
  Value<String> albumNorm,
  Value<String> genre,
  Value<int> trackNo,
  Value<int> plays,
  Value<int> durationMs,
  Value<int> sizeBytes,
  Value<String> contentHash,
  Value<String> audioFormat,
  Value<String?> coverPath,
  Value<DateTime?> coverCheckedAt,
  Value<DateTime?> missingAt,
  Value<DateTime> addedAt,
  Value<bool> needsMeta,
  Value<DateTime?> enrichedAt,
  Value<DateTime?> titleMatchedAt,
  Value<DateTime?> artistMatchedAt,
  Value<DateTime?> lyricsAt,
  Value<DateTime?> albumMatchedAt,
  Value<DateTime?> trackMatchedAt,
  Value<int> enrichAttempts,
});

final class $$TracksTableReferences
    extends BaseReferences<_$IaDatabase, $TracksTable, TrackRow> {
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

  static MultiTypedResultKey<$LyricsMetaTable, List<LyricsMetaRow>>
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

  static MultiTypedResultKey<$TrackVectorsTable, List<TrackVectorRow>>
  _trackVectorsRefsTable(_$IaDatabase db) => MultiTypedResultKey.fromTable(
    db.trackVectors,
    aliasName: 'tracks__id__track_vectors__track_id',
  );

  $$TrackVectorsTableProcessedTableManager get trackVectorsRefs {
    final manager = $$TrackVectorsTableTableManager(
      $_db,
      $_db.trackVectors,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackVectorsRefsTable($_db));
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleNorm => $composableBuilder(
    column: $table.titleNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistNorm => $composableBuilder(
    column: $table.artistNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumNorm => $composableBuilder(
    column: $table.albumNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNo => $composableBuilder(
    column: $table.trackNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plays => $composableBuilder(
    column: $table.plays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get coverCheckedAt => $composableBuilder(
    column: $table.coverCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get missingAt => $composableBuilder(
    column: $table.missingAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsMeta => $composableBuilder(
    column: $table.needsMeta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get titleMatchedAt => $composableBuilder(
    column: $table.titleMatchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get artistMatchedAt => $composableBuilder(
    column: $table.artistMatchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lyricsAt => $composableBuilder(
    column: $table.lyricsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get albumMatchedAt => $composableBuilder(
    column: $table.albumMatchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get trackMatchedAt => $composableBuilder(
    column: $table.trackMatchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enrichAttempts => $composableBuilder(
    column: $table.enrichAttempts,
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

  Expression<bool> trackVectorsRefs(
    Expression<bool> Function($$TrackVectorsTableFilterComposer f) f,
  ) {
    final $$TrackVectorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackVectors,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackVectorsTableFilterComposer(
            $db: $db,
            $table: $db.trackVectors,
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleNorm => $composableBuilder(
    column: $table.titleNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistNorm => $composableBuilder(
    column: $table.artistNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumNorm => $composableBuilder(
    column: $table.albumNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNo => $composableBuilder(
    column: $table.trackNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plays => $composableBuilder(
    column: $table.plays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get coverCheckedAt => $composableBuilder(
    column: $table.coverCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get missingAt => $composableBuilder(
    column: $table.missingAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsMeta => $composableBuilder(
    column: $table.needsMeta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get titleMatchedAt => $composableBuilder(
    column: $table.titleMatchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get artistMatchedAt => $composableBuilder(
    column: $table.artistMatchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lyricsAt => $composableBuilder(
    column: $table.lyricsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get albumMatchedAt => $composableBuilder(
    column: $table.albumMatchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get trackMatchedAt => $composableBuilder(
    column: $table.trackMatchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enrichAttempts => $composableBuilder(
    column: $table.enrichAttempts,
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

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleNorm =>
      $composableBuilder(column: $table.titleNorm, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get artistNorm => $composableBuilder(
    column: $table.artistNorm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumNorm =>
      $composableBuilder(column: $table.albumNorm, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get trackNo =>
      $composableBuilder(column: $table.trackNo, builder: (column) => column);

  GeneratedColumn<int> get plays =>
      $composableBuilder(column: $table.plays, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<DateTime> get coverCheckedAt => $composableBuilder(
    column: $table.coverCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get missingAt =>
      $composableBuilder(column: $table.missingAt, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<bool> get needsMeta =>
      $composableBuilder(column: $table.needsMeta, builder: (column) => column);

  GeneratedColumn<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get titleMatchedAt => $composableBuilder(
    column: $table.titleMatchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get artistMatchedAt => $composableBuilder(
    column: $table.artistMatchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lyricsAt =>
      $composableBuilder(column: $table.lyricsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get albumMatchedAt => $composableBuilder(
    column: $table.albumMatchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get trackMatchedAt => $composableBuilder(
    column: $table.trackMatchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get enrichAttempts => $composableBuilder(
    column: $table.enrichAttempts,
    builder: (column) => column,
  );

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

  Expression<T> trackVectorsRefs<T extends Object>(
    Expression<T> Function($$TrackVectorsTableAnnotationComposer a) f,
  ) {
    final $$TrackVectorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackVectors,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackVectorsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackVectors,
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
          TrackRow,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (TrackRow, $$TracksTableReferences),
          TrackRow,
          PrefetchHooks Function({
            bool rootId,
            bool playlistTracksRefs,
            bool playHistoryRefs,
            bool lyricsMetaRefs,
            bool trackVectorsRefs,
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
                Value<String> path = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> titleNorm = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> artistNorm = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<String> albumNorm = const Value.absent(),
                Value<String> genre = const Value.absent(),
                Value<int> trackNo = const Value.absent(),
                Value<int> plays = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> audioFormat = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime?> coverCheckedAt = const Value.absent(),
                Value<DateTime?> missingAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<bool> needsMeta = const Value.absent(),
                Value<DateTime?> enrichedAt = const Value.absent(),
                Value<DateTime?> titleMatchedAt = const Value.absent(),
                Value<DateTime?> artistMatchedAt = const Value.absent(),
                Value<DateTime?> lyricsAt = const Value.absent(),
                Value<DateTime?> albumMatchedAt = const Value.absent(),
                Value<DateTime?> trackMatchedAt = const Value.absent(),
                Value<int> enrichAttempts = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                rootId: rootId,
                relPath: relPath,
                path: path,
                title: title,
                titleNorm: titleNorm,
                artist: artist,
                artistNorm: artistNorm,
                album: album,
                albumNorm: albumNorm,
                genre: genre,
                trackNo: trackNo,
                plays: plays,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                contentHash: contentHash,
                audioFormat: audioFormat,
                coverPath: coverPath,
                coverCheckedAt: coverCheckedAt,
                missingAt: missingAt,
                addedAt: addedAt,
                needsMeta: needsMeta,
                enrichedAt: enrichedAt,
                titleMatchedAt: titleMatchedAt,
                artistMatchedAt: artistMatchedAt,
                lyricsAt: lyricsAt,
                albumMatchedAt: albumMatchedAt,
                trackMatchedAt: trackMatchedAt,
                enrichAttempts: enrichAttempts,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int rootId,
                required String relPath,
                required String path,
                required String title,
                required String titleNorm,
                required String artist,
                required String artistNorm,
                required String album,
                required String albumNorm,
                Value<String> genre = const Value.absent(),
                Value<int> trackNo = const Value.absent(),
                Value<int> plays = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> audioFormat = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime?> coverCheckedAt = const Value.absent(),
                Value<DateTime?> missingAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<bool> needsMeta = const Value.absent(),
                Value<DateTime?> enrichedAt = const Value.absent(),
                Value<DateTime?> titleMatchedAt = const Value.absent(),
                Value<DateTime?> artistMatchedAt = const Value.absent(),
                Value<DateTime?> lyricsAt = const Value.absent(),
                Value<DateTime?> albumMatchedAt = const Value.absent(),
                Value<DateTime?> trackMatchedAt = const Value.absent(),
                Value<int> enrichAttempts = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                rootId: rootId,
                relPath: relPath,
                path: path,
                title: title,
                titleNorm: titleNorm,
                artist: artist,
                artistNorm: artistNorm,
                album: album,
                albumNorm: albumNorm,
                genre: genre,
                trackNo: trackNo,
                plays: plays,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                contentHash: contentHash,
                audioFormat: audioFormat,
                coverPath: coverPath,
                coverCheckedAt: coverCheckedAt,
                missingAt: missingAt,
                addedAt: addedAt,
                needsMeta: needsMeta,
                enrichedAt: enrichedAt,
                titleMatchedAt: titleMatchedAt,
                artistMatchedAt: artistMatchedAt,
                lyricsAt: lyricsAt,
                albumMatchedAt: albumMatchedAt,
                trackMatchedAt: trackMatchedAt,
                enrichAttempts: enrichAttempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, TrackRow>(table),
                  $$TracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                rootId = false,
                playlistTracksRefs = false,
                playHistoryRefs = false,
                lyricsMetaRefs = false,
                trackVectorsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistTracksRefs) db.playlistTracks,
                    if (playHistoryRefs) db.playHistory,
                    if (lyricsMetaRefs) db.lyricsMeta,
                    if (trackVectorsRefs) db.trackVectors,
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

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistTracksRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          PlaylistTrack,
                          $PlaylistTracksTable
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
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (playHistoryRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          PlayHistoryData,
                          $PlayHistoryTable
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
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (lyricsMetaRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          LyricsMetaRow,
                          $LyricsMetaTable
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
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (trackVectorsRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          TrackVectorRow,
                          $TrackVectorsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._trackVectorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).trackVectorsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
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
      TrackRow,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (TrackRow, $$TracksTableReferences),
      TrackRow,
      PrefetchHooks Function({
        bool rootId,
        bool playlistTracksRefs,
        bool playHistoryRefs,
        bool lyricsMetaRefs,
        bool trackVectorsRefs,
      })
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  required PlaylistKindCol kind,
  Value<int> pending,
  Value<String?> coverPath,
  Value<DateTime> createdAt,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<PlaylistKindCol> kind,
  Value<int> pending,
  Value<String?> coverPath,
  Value<DateTime> createdAt,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$IaDatabase, $PlaylistsTable, PlaylistRow> {
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

  ColumnWithTypeConverterFilters<PlaylistKindCol, PlaylistKindCol, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

  ColumnOrderings<int> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

  GeneratedColumnWithTypeConverter<PlaylistKindCol, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get pending =>
      $composableBuilder(column: $table.pending, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

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
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (PlaylistRow, $$PlaylistsTableReferences),
          PlaylistRow,
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
                Value<PlaylistKindCol> kind = const Value.absent(),
                Value<int> pending = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                kind: kind,
                pending: pending,
                coverPath: coverPath,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required PlaylistKindCol kind,
                Value<int> pending = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                pending: pending,
                coverPath: coverPath,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, PlaylistRow>(table),
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
                    await $_getPrefetchedDataByColumns<
                      PlaylistRow,
                      $PlaylistsTable,
                      PlaylistTrack,
                      $PlaylistTracksTable
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
                      currentColumn: 'id',
                      referencedColumn: 'playlist_id',
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
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (PlaylistRow, $$PlaylistsTableReferences),
      PlaylistRow,
      PrefetchHooks Function({bool playlistTracksRefs})
    >;
typedef $$PlaylistTracksTableCreateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> id,
      required int playlistId,
      required int trackId,
      required int position,
      Value<DateTime> addedAt,
    });
typedef $$PlaylistTracksTableUpdateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<int> trackId,
      Value<int> position,
      Value<DateTime> addedAt,
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

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
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

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
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

  GeneratedColumn<DateTime> get addedAt =>
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
                Value<DateTime> addedAt = const Value.absent(),
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
                Value<DateTime> addedAt = const Value.absent(),
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
      Value<DateTime> playedAt,
      Value<bool> completed,
    });
typedef $$PlayHistoryTableUpdateCompanionBuilder =
    PlayHistoryCompanion Function({
      Value<int> id,
      Value<int> trackId,
      Value<DateTime> playedAt,
      Value<bool> completed,
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

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
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

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
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

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

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
                Value<DateTime> playedAt = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => PlayHistoryCompanion(
                id: id,
                trackId: trackId,
                playedAt: playedAt,
                completed: completed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                Value<DateTime> playedAt = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => PlayHistoryCompanion.insert(
                id: id,
                trackId: trackId,
                playedAt: playedAt,
                completed: completed,
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
typedef $$LyricsMetaTableCreateCompanionBuilder = LyricsMetaCompanion Function({
  Value<int> trackId,
  Value<String> kind,
  Value<String?> lrcPath,
  Value<int> offsetMs,
  Value<bool> edited,
  Value<DateTime?> fetchedAt,
});
typedef $$LyricsMetaTableUpdateCompanionBuilder = LyricsMetaCompanion Function({
  Value<int> trackId,
  Value<String> kind,
  Value<String?> lrcPath,
  Value<int> offsetMs,
  Value<bool> edited,
  Value<DateTime?> fetchedAt,
});

final class $$LyricsMetaTableReferences
    extends BaseReferences<_$IaDatabase, $LyricsMetaTable, LyricsMetaRow> {
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
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lrcPath => $composableBuilder(
    column: $table.lrcPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
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
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lrcPath => $composableBuilder(
    column: $table.lrcPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
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
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get lrcPath =>
      $composableBuilder(column: $table.lrcPath, builder: (column) => column);

  GeneratedColumn<int> get offsetMs =>
      $composableBuilder(column: $table.offsetMs, builder: (column) => column);

  GeneratedColumn<bool> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

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
          LyricsMetaRow,
          $$LyricsMetaTableFilterComposer,
          $$LyricsMetaTableOrderingComposer,
          $$LyricsMetaTableAnnotationComposer,
          $$LyricsMetaTableCreateCompanionBuilder,
          $$LyricsMetaTableUpdateCompanionBuilder,
          (LyricsMetaRow, $$LyricsMetaTableReferences),
          LyricsMetaRow,
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
                Value<String> kind = const Value.absent(),
                Value<String?> lrcPath = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<bool> edited = const Value.absent(),
                Value<DateTime?> fetchedAt = const Value.absent(),
              }) => LyricsMetaCompanion(
                trackId: trackId,
                kind: kind,
                lrcPath: lrcPath,
                offsetMs: offsetMs,
                edited: edited,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> lrcPath = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<bool> edited = const Value.absent(),
                Value<DateTime?> fetchedAt = const Value.absent(),
              }) => LyricsMetaCompanion.insert(
                trackId: trackId,
                kind: kind,
                lrcPath: lrcPath,
                offsetMs: offsetMs,
                edited: edited,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricsMetaTable, LyricsMetaRow>(table),
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
      LyricsMetaRow,
      $$LyricsMetaTableFilterComposer,
      $$LyricsMetaTableOrderingComposer,
      $$LyricsMetaTableAnnotationComposer,
      $$LyricsMetaTableCreateCompanionBuilder,
      $$LyricsMetaTableUpdateCompanionBuilder,
      (LyricsMetaRow, $$LyricsMetaTableReferences),
      LyricsMetaRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$TrackVectorsTableCreateCompanionBuilder =
    TrackVectorsCompanion Function({
      Value<int> trackId,
      required String model,
      required int dim,
      required Uint8List vec,
      Value<DateTime> vectorAt,
    });
typedef $$TrackVectorsTableUpdateCompanionBuilder =
    TrackVectorsCompanion Function({
      Value<int> trackId,
      Value<String> model,
      Value<int> dim,
      Value<Uint8List> vec,
      Value<DateTime> vectorAt,
    });

final class $$TrackVectorsTableReferences
    extends BaseReferences<_$IaDatabase, $TrackVectorsTable, TrackVectorRow> {
  $$TrackVectorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$IaDatabase db) =>
      db.tracks.createAlias('track_vectors__track_id__tracks__id');

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

class $$TrackVectorsTableFilterComposer
    extends Composer<_$IaDatabase, $TrackVectorsTable> {
  $$TrackVectorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get vec => $composableBuilder(
    column: $table.vec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get vectorAt => $composableBuilder(
    column: $table.vectorAt,
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

class $$TrackVectorsTableOrderingComposer
    extends Composer<_$IaDatabase, $TrackVectorsTable> {
  $$TrackVectorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get vec => $composableBuilder(
    column: $table.vec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get vectorAt => $composableBuilder(
    column: $table.vectorAt,
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

class $$TrackVectorsTableAnnotationComposer
    extends Composer<_$IaDatabase, $TrackVectorsTable> {
  $$TrackVectorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get dim =>
      $composableBuilder(column: $table.dim, builder: (column) => column);

  GeneratedColumn<Uint8List> get vec =>
      $composableBuilder(column: $table.vec, builder: (column) => column);

  GeneratedColumn<DateTime> get vectorAt =>
      $composableBuilder(column: $table.vectorAt, builder: (column) => column);

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

class $$TrackVectorsTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $TrackVectorsTable,
          TrackVectorRow,
          $$TrackVectorsTableFilterComposer,
          $$TrackVectorsTableOrderingComposer,
          $$TrackVectorsTableAnnotationComposer,
          $$TrackVectorsTableCreateCompanionBuilder,
          $$TrackVectorsTableUpdateCompanionBuilder,
          (TrackVectorRow, $$TrackVectorsTableReferences),
          TrackVectorRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$TrackVectorsTableTableManager(_$IaDatabase db, $TrackVectorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackVectorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackVectorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackVectorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> dim = const Value.absent(),
                Value<Uint8List> vec = const Value.absent(),
                Value<DateTime> vectorAt = const Value.absent(),
              }) => TrackVectorsCompanion(
                trackId: trackId,
                model: model,
                dim: dim,
                vec: vec,
                vectorAt: vectorAt,
              ),
          createCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                required String model,
                required int dim,
                required Uint8List vec,
                Value<DateTime> vectorAt = const Value.absent(),
              }) => TrackVectorsCompanion.insert(
                trackId: trackId,
                model: model,
                dim: dim,
                vec: vec,
                vectorAt: vectorAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackVectorsTable, TrackVectorRow>(table),
                  $$TrackVectorsTableReferences(db, table, e),
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
                        referencedTable: $$TrackVectorsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$TrackVectorsTableReferences
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

typedef $$TrackVectorsTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $TrackVectorsTable,
      TrackVectorRow,
      $$TrackVectorsTableFilterComposer,
      $$TrackVectorsTableOrderingComposer,
      $$TrackVectorsTableAnnotationComposer,
      $$TrackVectorsTableCreateCompanionBuilder,
      $$TrackVectorsTableUpdateCompanionBuilder,
      (TrackVectorRow, $$TrackVectorsTableReferences),
      TrackVectorRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$ModelFilesTableCreateCompanionBuilder = ModelFilesCompanion Function({
  required String id,
  required String url,
  required String sha256,
  required String filePath,
  Value<int> sizeBytes,
  Value<DateTime> readyAt,
  Value<int> rowid,
});
typedef $$ModelFilesTableUpdateCompanionBuilder = ModelFilesCompanion Function({
  Value<String> id,
  Value<String> url,
  Value<String> sha256,
  Value<String> filePath,
  Value<int> sizeBytes,
  Value<DateTime> readyAt,
  Value<int> rowid,
});

class $$ModelFilesTableFilterComposer
    extends Composer<_$IaDatabase, $ModelFilesTable> {
  $$ModelFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readyAt => $composableBuilder(
    column: $table.readyAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModelFilesTableOrderingComposer
    extends Composer<_$IaDatabase, $ModelFilesTable> {
  $$ModelFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readyAt => $composableBuilder(
    column: $table.readyAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelFilesTableAnnotationComposer
    extends Composer<_$IaDatabase, $ModelFilesTable> {
  $$ModelFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get readyAt =>
      $composableBuilder(column: $table.readyAt, builder: (column) => column);
}

class $$ModelFilesTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $ModelFilesTable,
          ModelFileRow,
          $$ModelFilesTableFilterComposer,
          $$ModelFilesTableOrderingComposer,
          $$ModelFilesTableAnnotationComposer,
          $$ModelFilesTableCreateCompanionBuilder,
          $$ModelFilesTableUpdateCompanionBuilder,
          (
            ModelFileRow,
            BaseReferences<_$IaDatabase, $ModelFilesTable, ModelFileRow>,
          ),
          ModelFileRow,
          PrefetchHooks Function()
        > {
  $$ModelFilesTableTableManager(_$IaDatabase db, $ModelFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime> readyAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelFilesCompanion(
                id: id,
                url: url,
                sha256: sha256,
                filePath: filePath,
                sizeBytes: sizeBytes,
                readyAt: readyAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                required String sha256,
                required String filePath,
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime> readyAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelFilesCompanion.insert(
                id: id,
                url: url,
                sha256: sha256,
                filePath: filePath,
                sizeBytes: sizeBytes,
                readyAt: readyAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelFilesTable, ModelFileRow>(table),
                  BaseReferences<_$IaDatabase, $ModelFilesTable, ModelFileRow>(
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

typedef $$ModelFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $ModelFilesTable,
      ModelFileRow,
      $$ModelFilesTableFilterComposer,
      $$ModelFilesTableOrderingComposer,
      $$ModelFilesTableAnnotationComposer,
      $$ModelFilesTableCreateCompanionBuilder,
      $$ModelFilesTableUpdateCompanionBuilder,
      (
        ModelFileRow,
        BaseReferences<_$IaDatabase, $ModelFilesTable, ModelFileRow>,
      ),
      ModelFileRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String valueJson,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> valueJson,
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

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
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

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
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

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);
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
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> valueJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, valueJson: valueJson, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
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
typedef $$CollectTasksTableCreateCompanionBuilder =
    CollectTasksCompanion Function({
      Value<int> id,
      required String source,
      Value<String> query,
      required String url,
      required String title,
      required String artist,
      Value<CollectStatusCol> status,
      Value<int> progress,
      Value<String?> filePath,
      Value<String?> lyricsPath,
      Value<String?> errorText,
      Value<int?> playlistId,
      Value<DateTime> createdAt,
    });
typedef $$CollectTasksTableUpdateCompanionBuilder =
    CollectTasksCompanion Function({
      Value<int> id,
      Value<String> source,
      Value<String> query,
      Value<String> url,
      Value<String> title,
      Value<String> artist,
      Value<CollectStatusCol> status,
      Value<int> progress,
      Value<String?> filePath,
      Value<String?> lyricsPath,
      Value<String?> errorText,
      Value<int?> playlistId,
      Value<DateTime> createdAt,
    });

class $$CollectTasksTableFilterComposer
    extends Composer<_$IaDatabase, $CollectTasksTable> {
  $$CollectTasksTableFilterComposer({
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

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
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

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CollectStatusCol, CollectStatusCol, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyricsPath => $composableBuilder(
    column: $table.lyricsPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorText => $composableBuilder(
    column: $table.errorText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectTasksTableOrderingComposer
    extends Composer<_$IaDatabase, $CollectTasksTable> {
  $$CollectTasksTableOrderingComposer({
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

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
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

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyricsPath => $composableBuilder(
    column: $table.lyricsPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorText => $composableBuilder(
    column: $table.errorText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectTasksTableAnnotationComposer
    extends Composer<_$IaDatabase, $CollectTasksTable> {
  $$CollectTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CollectStatusCol, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get lyricsPath => $composableBuilder(
    column: $table.lyricsPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorText =>
      $composableBuilder(column: $table.errorText, builder: (column) => column);

  GeneratedColumn<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CollectTasksTableTableManager
    extends
        RootTableManager<
          _$IaDatabase,
          $CollectTasksTable,
          CollectTaskRow,
          $$CollectTasksTableFilterComposer,
          $$CollectTasksTableOrderingComposer,
          $$CollectTasksTableAnnotationComposer,
          $$CollectTasksTableCreateCompanionBuilder,
          $$CollectTasksTableUpdateCompanionBuilder,
          (
            CollectTaskRow,
            BaseReferences<_$IaDatabase, $CollectTasksTable, CollectTaskRow>,
          ),
          CollectTaskRow,
          PrefetchHooks Function()
        > {
  $$CollectTasksTableTableManager(_$IaDatabase db, $CollectTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<CollectStatusCol> status = const Value.absent(),
                Value<int> progress = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> lyricsPath = const Value.absent(),
                Value<String?> errorText = const Value.absent(),
                Value<int?> playlistId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CollectTasksCompanion(
                id: id,
                source: source,
                query: query,
                url: url,
                title: title,
                artist: artist,
                status: status,
                progress: progress,
                filePath: filePath,
                lyricsPath: lyricsPath,
                errorText: errorText,
                playlistId: playlistId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                Value<String> query = const Value.absent(),
                required String url,
                required String title,
                required String artist,
                Value<CollectStatusCol> status = const Value.absent(),
                Value<int> progress = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> lyricsPath = const Value.absent(),
                Value<String?> errorText = const Value.absent(),
                Value<int?> playlistId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CollectTasksCompanion.insert(
                id: id,
                source: source,
                query: query,
                url: url,
                title: title,
                artist: artist,
                status: status,
                progress: progress,
                filePath: filePath,
                lyricsPath: lyricsPath,
                errorText: errorText,
                playlistId: playlistId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectTasksTable, CollectTaskRow>(table),
                  BaseReferences<
                    _$IaDatabase,
                    $CollectTasksTable,
                    CollectTaskRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$IaDatabase,
      $CollectTasksTable,
      CollectTaskRow,
      $$CollectTasksTableFilterComposer,
      $$CollectTasksTableOrderingComposer,
      $$CollectTasksTableAnnotationComposer,
      $$CollectTasksTableCreateCompanionBuilder,
      $$CollectTasksTableUpdateCompanionBuilder,
      (
        CollectTaskRow,
        BaseReferences<_$IaDatabase, $CollectTasksTable, CollectTaskRow>,
      ),
      CollectTaskRow,
      PrefetchHooks Function()
    >;

class $IaDatabaseManager {
  final _$IaDatabase _db;
  $IaDatabaseManager(this._db);
  $$RepositoryRootsTableTableManager get repositoryRoots =>
      $$RepositoryRootsTableTableManager(_db, _db.repositoryRoots);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db, _db.playHistory);
  $$LyricsMetaTableTableManager get lyricsMeta =>
      $$LyricsMetaTableTableManager(_db, _db.lyricsMeta);
  $$TrackVectorsTableTableManager get trackVectors =>
      $$TrackVectorsTableTableManager(_db, _db.trackVectors);
  $$ModelFilesTableTableManager get modelFiles =>
      $$ModelFilesTableTableManager(_db, _db.modelFiles);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$CollectTasksTableTableManager get collectTasks =>
      $$CollectTasksTableTableManager(_db, _db.collectTasks);
}
