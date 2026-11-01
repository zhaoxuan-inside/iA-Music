/// 同步域装配面（WS6）：通道 Port 选择器 + SyncEngine 生命周期 +
/// drift 表变更喂点（tableUpdates → 30s 防抖；REQ-SYNC-02 自动同步）。
library;

import 'dart:async';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import 'package:ia_music/adapters/secure_store_adapter.dart';
import 'package:ia_music/adapters/sync_gdrive_adapter.dart';
import 'package:ia_music/adapters/sync_github_adapter.dart';
import 'package:ia_music/adapters/sync_onedrive_adapter.dart';
import 'package:ia_music/adapters/sync_webdav_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/sync/sync_engine.dart';

final class SyncService {
  SyncService({required IaDatabase db, SecureStorePort? secure})
      : _db = db,
        _secure = secure ?? SecureStoreAdapter() {
    _data = DataAccess(db);
  }

  final IaDatabase _db;
  final SecureStorePort _secure;
  late final DataAccess _data;
  SyncEngine? _engine;
  StreamSubscription<Set<TableUpdate>>? _feedSub;

  /// 当前引擎（无通道=null；通道切换时重建）。
  SyncEngine? get engine => _engine;

  /// 启动装配（main/hub 调用一次）：按当前活跃通道建引擎 +
  /// 订阅域表变更喂点（playlists/playlistTracks/tracks/playHistory/
  /// fewWatchList/lyricsMeta 任一写入 → notifyLocalChange → 30s 防抖）。
  Future<void> attach() async {
    await _rebuildEngine();
    _feedSub = _db.tableUpdates(TableUpdateQuery.onAllTables([
      _db.playlists,
      _db.playlistTracks,
      _db.tracks,
      _db.playHistory,
      _db.fewWatchList,
      _db.lyricsMeta,
    ])).listen((_) => _engine?.notifyLocalChange());
  }

  Future<void> _rebuildEngine() async {
    await _engine?.dispose();
    _engine = null;
    final channel = await _data.sync.currentChannel();
    if (channel == null) {
      return;
    }
    final cfg = await channelConfigOf(channel);
    if (cfg == null) {
      return;
    }
    final port = _buildPort(channel, cfg);
    final engine = SyncEngine(db: _db, port: port, remoteDir: cfg.remoteDir);
    _engine = engine;
  }

  /// 通道 Port 选择器（ADR-0001 R2：WebDAV=全量；GitHub=轻数据；
  /// OneDrive/GDrive=文件型云盘 + OAuth 设备码流）。
  SyncChannelPort _buildPort(SyncChannelData channel, ChannelConfig cfg) {
    switch (channel.type) {
      case SyncChannelType.webdav:
        return WebDavAdapter(credentials: _secure.read, config: cfg);
      case SyncChannelType.github:
        return GitHubAdapter(credentials: _secure.read, config: cfg);
      case SyncChannelType.onedrive:
        return OneDriveAdapter(
          credentials: _secure.read,
          credentialsWriter: _secure.write,
          config: cfg,
        );
      case SyncChannelType.gdrive:
        return GoogleDriveAdapter(
          credentials: _secure.read,
          credentialsWriter: _secure.write,
          config: cfg,
        );
    }
  }

  /// DB 通道行 → 契约 ChannelConfig（凭据经 SecureStore 引用键）。
  Future<ChannelConfig?> channelConfigOf(SyncChannelData channel) async {
    final ref = channel.credentialsRef;
    if (ref == null || ref.isEmpty) {
      return null;
    }
    return ChannelConfig(
      type: switch (channel.type) {
        SyncChannelType.webdav => ChannelType.webdav,
        SyncChannelType.github => ChannelType.github,
        SyncChannelType.onedrive => ChannelType.onedrive,
        SyncChannelType.gdrive => ChannelType.gdrive,
      },
      baseUrl: channel.baseUrl,
      remoteDir: channel.remoteDir,
      username: channel.username,
      credentialsRefKey: ref,
    );
  }

  /// 通道配置落账（同步中心 UI 保存面）：先连接测试，通过才可保存（REQ-SYNC-01）。
  /// 返回 null=成功；否则=人话失败原因。
  Future<String?> applyChannel({
    required SyncChannelType type,
    required String baseUrl,
    required String credentialsValue, // WebDAV 密码 / GitHub PAT / OAuth 凭据 JSON
    String? username,
    String remoteDir = 'iA-Music/',
  }) async {
    final refKey = 'sync.${type.name}.credentials';
    final probeCfg = ChannelConfig(
      type: switch (type) {
        SyncChannelType.webdav => ChannelType.webdav,
        SyncChannelType.github => ChannelType.github,
        SyncChannelType.onedrive => ChannelType.onedrive,
        SyncChannelType.gdrive => ChannelType.gdrive,
      },
      baseUrl: baseUrl,
      remoteDir: remoteDir,
      username: username,
      credentialsRefKey: refKey,
    );
    final probePort = _buildProbePort(type, probeCfg);
    await _secure.write(refKey, credentialsValue);
    final result = await probePort.testConnection(probeCfg);
    if (!result.ok) {
      await _secure.delete(refKey); // 测试不过=不留半凭据
      return result.reason ?? '连接测试失败';
    }
    await _data.sync.applyChannel(
      type,
      baseUrl,
      credentialsRef: refKey,
      username: username,
    );
    // 更新 remoteDir（applyChannel 不含该列——补一次 update）
    final row = await _data.sync.currentChannel();
    if (row != null && row.remoteDir != remoteDir) {
      await (_db.update(_db.syncChannel)
            ..where((c) => c.id.equals(row.id)))
          .write(SyncChannelCompanion(remoteDir: Value(remoteDir)));
    }
    await _rebuildEngine();
    return null;
  }

  SyncChannelPort _buildProbePort(SyncChannelType type, ChannelConfig cfg) {
    switch (type) {
      case SyncChannelType.webdav:
        return WebDavAdapter(credentials: _secure.read, config: cfg);
      case SyncChannelType.github:
        return GitHubAdapter(credentials: _secure.read, config: cfg);
      case SyncChannelType.onedrive:
        return OneDriveAdapter(
          credentials: _secure.read,
          credentialsWriter: _secure.write,
          config: cfg,
        );
      case SyncChannelType.gdrive:
        return GoogleDriveAdapter(
          credentials: _secure.read,
          credentialsWriter: _secure.write,
          config: cfg,
        );
    }
  }

  /// 手动同步（REQ-SYNC-07）。
  Future<SyncSummary?> syncNow() async =>
      _engine?.run(SyncTrigger.manual);

  /// 断开通道（同步中心 UI）。
  Future<void> detachChannel() async {
    final row = await _data.sync.currentChannel();
    if (row != null) {
      await (_db.update(_db.syncChannel)..where((c) => c.id.equals(row.id)))
          .write(const SyncChannelCompanion(isActive: Value(false)));
    }
    await _engine?.dispose();
    _engine = null;
  }

  Future<void> dispose() async {
    await _feedSub?.cancel();
    await _engine?.dispose();
  }
}

