/// 收集任务 DAO：GitHub 歌单拉取/直链下载/平台提取 的落库队列。
library;

import 'package:drift/drift.dart';

import '../database.dart';

part 'collect_dao.g.dart';

/// 收集任务状态：pending → running → done / blocked(待提取引擎) / failed。
enum CollectStatusCol { pending, running, done, blocked, failed }

@DataClassName('CollectTaskRow')
class CollectTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text()(); // 来源平台标识（bilibili/youtube/direct/github）
  TextColumn get query => text().withDefault(const Constant(''))(); // 搜索词
  TextColumn get url => text()(); // 歌曲来源地址
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get status => textEnum<CollectStatusCol>()
      .withDefault(const Constant('pending'))();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()(); // 音频落盘路径（直链下载完成）
  TextColumn get lyricsPath => text().nullable()(); // 歌词落盘路径（拉取即写）
  IntColumn get playlistId => integer().nullable()(); // 归属歌单（GitHub 拉取建的歌单）
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{url, title, artist}];
}

@DriftAccessor(tables: [CollectTasks])
class CollectDao extends DatabaseAccessor<IaDatabase> with _$CollectDaoMixin {
  CollectDao(super.db);

  /// 进度页实时流（进行中在前，其余按时间倒序）。
  Stream<List<CollectTaskRow>> watchAll() {
    return (select(collectTasks)
          ..orderBy([
            (u) => OrderingTerm.desc(u.createdAt),
          ]))
        .watch();
  }

  Future<List<CollectTaskRow>> pendingOrRunning() async {
    return (select(collectTasks)
          ..where((t) =>
              t.status.equals(CollectStatusCol.pending.name) |
              t.status.equals(CollectStatusCol.running.name)))
        .get();
  }

  Future<int> addTask(CollectTasksCompanion entry) =>
      into(collectTasks).insert(entry, onConflict: DoNothing());

  Future<void> setProgress(int id, int progress) {
    return (update(collectTasks)..where((t) => t.id.equals(id)))
        .write(CollectTasksCompanion(progress: Value(progress.clamp(0, 100))));
  }

  Future<void> setStatus(int id, CollectStatusCol status, {String? filePath}) {
    return (update(collectTasks)..where((t) => t.id.equals(id))).write(
      CollectTasksCompanion(
        status: Value(status),
        filePath: filePath == null ? const Value.absent() : Value(filePath),
      ),
    );
  }
}
