// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_dao.dart';

// ignore_for_file: type=lint
mixin _$LibraryDaoMixin on DatabaseAccessor<IaDatabase> {
  $RepositoryRootsTable get repositoryRoots => attachedDatabase.repositoryRoots;
  $TracksTable get tracks => attachedDatabase.tracks;
  $PlayHistoryTable get playHistory => attachedDatabase.playHistory;
  $PlaylistsTable get playlists => attachedDatabase.playlists;
  $PlaylistTracksTable get playlistTracks => attachedDatabase.playlistTracks;
  $LyricsMetaTable get lyricsMeta => attachedDatabase.lyricsMeta;
  $TrackVectorsTable get trackVectors => attachedDatabase.trackVectors;
  LibraryDaoManager get managers => LibraryDaoManager(this);
}

class LibraryDaoManager {
  final _$LibraryDaoMixin _db;
  LibraryDaoManager(this._db);
  $$RepositoryRootsTableTableManager get repositoryRoots =>
      $$RepositoryRootsTableTableManager(
        _db.attachedDatabase,
        _db.repositoryRoots,
      );
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db.attachedDatabase, _db.playHistory);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db.attachedDatabase, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(
        _db.attachedDatabase,
        _db.playlistTracks,
      );
  $$LyricsMetaTableTableManager get lyricsMeta =>
      $$LyricsMetaTableTableManager(_db.attachedDatabase, _db.lyricsMeta);
  $$TrackVectorsTableTableManager get trackVectors =>
      $$TrackVectorsTableTableManager(_db.attachedDatabase, _db.trackVectors);
}
