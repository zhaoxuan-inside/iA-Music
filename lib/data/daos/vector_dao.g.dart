// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vector_dao.dart';

// ignore_for_file: type=lint
mixin _$VectorDaoMixin on DatabaseAccessor<IaDatabase> {
  $RepositoryRootsTable get repositoryRoots => attachedDatabase.repositoryRoots;
  $TracksTable get tracks => attachedDatabase.tracks;
  $TrackVectorsTable get trackVectors => attachedDatabase.trackVectors;
  VectorDaoManager get managers => VectorDaoManager(this);
}

class VectorDaoManager {
  final _$VectorDaoMixin _db;
  VectorDaoManager(this._db);
  $$RepositoryRootsTableTableManager get repositoryRoots =>
      $$RepositoryRootsTableTableManager(
        _db.attachedDatabase,
        _db.repositoryRoots,
      );
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$TrackVectorsTableTableManager get trackVectors =>
      $$TrackVectorsTableTableManager(_db.attachedDatabase, _db.trackVectors);
}
