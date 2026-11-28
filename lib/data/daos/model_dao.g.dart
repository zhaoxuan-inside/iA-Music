// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_dao.dart';

// ignore_for_file: type=lint
mixin _$ModelDaoMixin on DatabaseAccessor<IaDatabase> {
  $ModelFilesTable get modelFiles => attachedDatabase.modelFiles;
  ModelDaoManager get managers => ModelDaoManager(this);
}

class ModelDaoManager {
  final _$ModelDaoMixin _db;
  ModelDaoManager(this._db);
  $$ModelFilesTableTableManager get modelFiles =>
      $$ModelFilesTableTableManager(_db.attachedDatabase, _db.modelFiles);
}
