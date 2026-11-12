/// 壳层 KV 设置 DAO（JSON 值；解析权在 SettingsService）。
library;

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<IaDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> valueOf(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.valueJson;
  }

  Future<void> setValue(String key, String valueJson) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, valueJson: valueJson),
    );
  }
}
