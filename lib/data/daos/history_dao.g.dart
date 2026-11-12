// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_dao.dart';

// ignore_for_file: type=lint
mixin _$HistoryDaoMixin on DatabaseAccessor<IaDatabase> {
  $RepositoryRootsTable get repositoryRoots => attachedDatabase.repositoryRoots;
  $TracksTable get tracks => attachedDatabase.tracks;
  $PlayHistoryTable get playHistory => attachedDatabase.playHistory;
  HistoryDaoManager get managers => HistoryDaoManager(this);
}

class HistoryDaoManager {
  final _$HistoryDaoMixin _db;
  HistoryDaoManager(this._db);
  $$RepositoryRootsTableTableManager get repositoryRoots =>
      $$RepositoryRootsTableTableManager(
        _db.attachedDatabase,
        _db.repositoryRoots,
      );
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db.attachedDatabase, _db.playHistory);
}

mixin _$LyricsDaoMixin on DatabaseAccessor<IaDatabase> {
  $RepositoryRootsTable get repositoryRoots => attachedDatabase.repositoryRoots;
  $TracksTable get tracks => attachedDatabase.tracks;
  $LyricsMetaTable get lyricsMeta => attachedDatabase.lyricsMeta;
  LyricsDaoManager get managers => LyricsDaoManager(this);
}

class LyricsDaoManager {
  final _$LyricsDaoMixin _db;
  LyricsDaoManager(this._db);
  $$RepositoryRootsTableTableManager get repositoryRoots =>
      $$RepositoryRootsTableTableManager(
        _db.attachedDatabase,
        _db.repositoryRoots,
      );
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$LyricsMetaTableTableManager get lyricsMeta =>
      $$LyricsMetaTableTableManager(_db.attachedDatabase, _db.lyricsMeta);
}
