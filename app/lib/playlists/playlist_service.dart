/// 歌单域服务 —— 红心/歌单 CRUD/重复拦截/收录计数（TASK-S4 · REQ-PL-01..06）。
///
/// 纪律（DETAILED-DESIGN §1.2 / playlists_prd）：
/// * 「我喜欢的音乐」=**唯一一格 system_favorite**（DB 级部分唯一索引兜底；
///   ensureFavorite 幂等建立——S1 DAO 原语复用）。
/// * 红心=收藏系统歌单的加/出动作（toggle）；图标即时状态由本层布尔返回+计数
///   同步读（「我喜欢的音乐」计数=track_count 直接读，REQ-PL-01「计数同步变化」）。
/// * 重复添加=DB UNIQUE 拦截（playlist_tracks UNIQUE(playlist_id, track_id)）——
///   服务层 addTrack 返回 false；UI 原话「《X》已在『Y』中」（REQ-PL-03）。
/// * 历史淘汰=[只删 play_history 表行]（守则；_flush/prune 归 S3 接线）。
/// * 墓碑语义=SyncEngine（S6）补写；本域只做业务面动作（沿 S2/S3 纪律）。
library;

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';

/// 我的页/歌单列表行摘要（真行+计数；无替身数据）。
typedef PlaylistDigest = ({Playlist playlist, int trackCount});

class PlaylistService {
  PlaylistService(this.data);

  final DataAccess data;

  /// 全列（排除软删；含曲目计数；红心行在首个=system_favorite 置顶面）。
  Future<List<PlaylistDigest>> listAll() async => [
        for (final (p, c) in await data.playlists.listAll())
          (playlist: p, trackCount: c),
      ];

  /// 红心切换（REQ-PL-01）：true=已加入（红） / false=已移出（未红）。
  Future<bool> toggleFavorite(int trackId, {required int nowMs}) async {
    final fav = await data.playlists.ensureFavorite(nowMs: nowMs);
    if (await data.playlists.contains(fav.id, trackId)) {
      await data.playlists.removeTrack(fav.id, trackId);
      await data.playlists.touchUpdatedAt(fav.id, nowMs);
      return false;
    }
    final ok = await data.playlists.addTrack(fav.id, trackId, nowMs: nowMs);
    if (!ok) {
      return false; // 理论不可达（contains 已拦截）——防御口径：视为未红
    }
    await data.playlists.touchUpdatedAt(fav.id, nowMs);
    return true;
  }

  Future<bool> isFavorite(int trackId) async {
    final fav = await data.playlists.ensureFavorite(nowMs: 0);
    return data.playlists.contains(fav.id, trackId);
  }

  /// 「我喜欢的音乐」计数（REQ-PL-01 计数同步读）。
  Future<int> favoriteCount() async {
    final fav = await data.playlists.ensureFavorite(nowMs: 0);
    return data.playlists.trackCount(fav.id);
  }

  /// 「我喜欢的音乐」曲目 id 全集（列表行红心态初始装配面）。
  Future<Set<int>> favoriteIds() async {
    final fav = await data.playlists.ensureFavorite(nowMs: 0);
    return {for (final t in await rows(fav.id)) t.id};
  }

  /// 新建歌单（REQ-PL-02；真行返回）。
  Future<Playlist> create(String name, {required int nowMs}) =>
      data.playlists.create(name, nowMs: nowMs);

  /// 加入歌曲（REQ-PL-03）：false=重复（已存在——UI 拦截原话在页面层）。
  Future<bool> addTo(int playlistId, int trackId, {required int nowMs}) =>
      data.playlists.addTrack(playlistId, trackId, nowMs: nowMs);

  Future<void> removeFrom(int playlistId, int trackId) =>
      data.playlists.removeTrack(playlistId, trackId);

  /// 歌单曲行（REQ-PL-04/06：idx_pt_pos 顺序）。
  Future<List<Track>> rows(int playlistId) async =>
      [for (final (_, t) in await data.playlists.browse(playlistId)) t];

  Future<void> delete(int playlistId, {required int nowMs}) =>
      data.playlists.softDeletePlaylist(playlistId, nowMs);

  // ── 我的页计数卡（REQ-NAV-05 三卡；S4 从属面） ──

  Future<int> libraryCount() => data.library.libraryTotal();
  Future<int> historyCount() => data.history.historyTotal();
}
