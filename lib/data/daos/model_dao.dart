/// 模型文件登记 DAO：推理模型文件的就绪记账面。
/// 行存在 = 已就绪且校验通过；下载/校验/落盘动作在 ModelStore（文件管理域）。
library;

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'model_dao.g.dart';

@DriftAccessor(tables: [ModelFiles])
class ModelDao extends DatabaseAccessor<IaDatabase> with _$ModelDaoMixin {
  ModelDao(super.db);

  Future<ModelFileRow?> readyModel(String id) =>
      (select(modelFiles)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// 登记/刷新就绪状态（PK=id 覆盖写，换版本重下即刷新）。
  Future<void> markReady({
    required String id,
    required String url,
    required String sha256,
    required String filePath,
    required int sizeBytes,
  }) {
    return into(modelFiles).insertOnConflictUpdate(
      ModelFilesCompanion.insert(
        id: id,
        url: url,
        sha256: sha256,
        filePath: filePath,
        sizeBytes: Value(sizeBytes),
      ),
    );
  }

  /// 注销登记（文件丢失/校验锚变更/换版本重下前清位）。
  Future<void> forget(String id) =>
      (delete(modelFiles)..where((m) => m.id.equals(id))).go();
}
