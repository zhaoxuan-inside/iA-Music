// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collect_dao.dart';

// ignore_for_file: type=lint
mixin _$CollectDaoMixin on DatabaseAccessor<IaDatabase> {
  $CollectTasksTable get collectTasks => attachedDatabase.collectTasks;
  CollectDaoManager get managers => CollectDaoManager(this);
}

class CollectDaoManager {
  final _$CollectDaoMixin _db;
  CollectDaoManager(this._db);
  $$CollectTasksTableTableManager get collectTasks =>
      $$CollectTasksTableTableManager(_db.attachedDatabase, _db.collectTasks);
}
