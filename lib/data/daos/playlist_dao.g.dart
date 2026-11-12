// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaylistDaoMixin on DatabaseAccessor<IaDatabase> {
  $PlaylistsTable get playlists => attachedDatabase.playlists;
  $RepositoryRootsTable get repositoryRoots => attachedDatabase.repositoryRoots;
  $TracksTable get tracks => attachedDatabase.tracks;
  $PlaylistTracksTable get playlistTracks => attachedDatabase.playlistTracks;
  PlaylistDaoManager get managers => PlaylistDaoManager(this);
}

class PlaylistDaoManager {
  final _$PlaylistDaoMixin _db;
  PlaylistDaoManager(this._db);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db.attachedDatabase, _db.playlists);
  $$RepositoryRootsTableTableManager get repositoryRoots =>
      $$RepositoryRootsTableTableManager(
        _db.attachedDatabase,
        _db.repositoryRoots,
      );
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(
        _db.attachedDatabase,
        _db.playlistTracks,
      );
}
