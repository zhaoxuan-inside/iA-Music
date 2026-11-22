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
  TextColumn get source => text()(); // 来源：音频源插件 id / direct / github
  TextColumn get query => text().withDefault(const Constant(''))(); // 搜索词
  TextColumn get url => text()(); // 歌曲来源地址
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get status => textEnum<CollectStatusCol>()
      .withDefault(const Constant('pending'))();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()(); // 音频落盘路径（直链下载完成）
  TextColumn get lyricsPath => text().nullable()(); // 歌词落盘路径（拉取即写）
  TextColumn get errorText => text().nullable()(); // 失败原因原文（截断 400，重排时清空）
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

  /// 僵尸回收：App 中途死亡留下的 running 任务重回队列。
  /// 本队列单用户单进程——runner 开轮时不存在「合法的 running」。
  Future<int> requeueRunning() {
    return (update(collectTasks)
          ..where((t) => t.status.equals(CollectStatusCol.running.name)))
        .write(CollectTasksCompanion(
      status: Value(CollectStatusCol.pending),
      progress: const Value(0),
      errorText: const Value(null),
    ));
  }

  Future<int> addTask(CollectTasksCompanion entry) =>
      into(collectTasks).insert(entry, onConflict: DoNothing());

  /// 入队便利（UI/服务层免构 Companion；标题空由提取引擎运行时补全）。
  /// 重复链接（唯一键冲突）不重复入队也不抛错——返回已有任务 id，
  /// 让调用方得以驱动一轮 runOnce（僵尸任务由此获得回收机会）。
  Future<int> enqueue(String source, String url,
      {String title = '', String artist = '', int? playlistId}) async {
    try {
      return await addTask(CollectTasksCompanion.insert(
        source: source,
        url: url,
        title: title,
        artist: artist,
        playlistId: Value(playlistId),
      ));
    } on Object {
      final existing = await (select(collectTasks)
            ..where((t) =>
                t.url.equals(url) &
                t.title.equals(title) &
                t.artist.equals(artist)))
          .getSingleOrNull();
      return existing?.id ?? -1;
    }
  }

  Future<void> setProgress(int id, int progress) {
    return (update(collectTasks)..where((t) => t.id.equals(id)))
        .write(CollectTasksCompanion(progress: Value(progress.clamp(0, 100))));
  }

  Future<void> setStatus(int id, CollectStatusCol status,
      {String? filePath, String? errorText}) {
    return (update(collectTasks)..where((t) => t.id.equals(id))).write(
      CollectTasksCompanion(
        status: Value(status),
        filePath: filePath == null ? const Value.absent() : Value(filePath),
        errorText: errorText == null ? const Value.absent() : Value(errorText),
      ),
    );
  }

  /// 多 P 拆分：把当前任务重定向到指定分 P（URL/标题/歌手）。
  Future<void> retarget(int id,
      {required String url, required String title, required String artist}) {
    return (update(collectTasks)..where((t) => t.id.equals(id))).write(
      CollectTasksCompanion(
        url: Value(url),
        title: Value(title),
        artist: Value(artist),
      ),
    );
  }

  /// 批量任务（如 100P 合集）里失败的任务重新排队。
  Future<int> retryFailed() {
    return (update(collectTasks)
          ..where((t) => t.status.equals(CollectStatusCol.failed.name)))
        .write(CollectTasksCompanion(
      status: Value(CollectStatusCol.pending),
      progress: const Value(0),
      errorText: const Value(null),
    ));
  }
}
