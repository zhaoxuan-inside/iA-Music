/// GitHub 歌单拉取服务（真实实现）：
/// raw.githubusercontent 拉取 JSON → 契约校验 → 建歌单（pending）→ 逐首写任务与歌词。
///
/// 数据契约（docs/PRODUCT.md）：
/// { "name": "歌单名", "tracks": [ { "source": "bilibili",
///   "query": "搜索词", "url": "歌曲来源地址", "artist": "歌手",
///   "title": "歌名", "lyrics": "[00:01.00]…(LRC/纯文本)" } ] }
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../data/database.dart';
import '../../domain/errors.dart';

class GithubPlaylistService {
  GithubPlaylistService(this._db, {HttpClient? client})
      : _client = client ?? HttpClient();

  final IaDatabase _db;
  final HttpClient _client;

  /// 清单 source 别名归一：direct 之外的值原样透传——提取期由宿主按
  /// URL 路由到对应音频源插件（插件可换名，清单格式不绑定插件 id）。
  static const Map<String, String> sourceAliases = {
    'direct': 'direct',
    '直链': 'direct',
  };

  /// 拉取并解析；返回 (歌单名, 曲目列表)。网络/契约错误抛 ContractError。
  Future<({String name, List<GithubTrack> tracks})> fetch(Uri uri) async {
    try {
      final req = await _client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != 200) {
        throw NetworkError(detail: 'GitHub 拉取失败：HTTP ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      return parse(body);
    } on ContractError {
      rethrow;
    } on Object catch (e, st) {
      Error.throwWithStackTrace(NetworkError(detail: 'GitHub 拉取失败：$e'), st);
    }
  }

  /// 契约校验与解析（纯函数；测试直接覆盖）。
  ({String name, List<GithubTrack> tracks}) parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw MetadataError(detail: '契约不符：顶层必须是对象');
    }
    final name = (decoded['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw MetadataError(detail: '契约不符：缺少 name');
    }
    final rawTracks = decoded['tracks'];
    if (rawTracks is! List) {
      throw MetadataError(detail: '契约不符：缺少 tracks 数组');
    }
    final tracks = <GithubTrack>[];
    for (final t in rawTracks) {
      if (t is! Map<String, dynamic>) {
        throw MetadataError(detail: '契约不符：tracks 内有非对象项');
      }
      final url = (t['url'] as String?)?.trim() ?? '';
      final title = (t['title'] as String?)?.trim() ?? '';
      if (url.isEmpty || title.isEmpty) {
        throw MetadataError(detail: '契约不符：每首必须含 url 与 title');
      }
      final sourceRaw = (t['source'] as String?)?.trim().toLowerCase() ?? '';
      tracks.add(GithubTrack(
        source: sourceAliases[sourceRaw] ?? sourceRaw,
        query: (t['query'] as String?)?.trim() ?? '',
        url: url,
        artist: (t['artist'] as String?)?.trim() ?? '',
        title: title,
        lyrics: (t['lyrics'] as String?)?.trim() ?? '',
      ));
    }
    if (tracks.isEmpty) {
      throw MetadataError(detail: '契约不符：tracks 为空');
    }
    return (name: name, tracks: tracks);
  }

  /// 导入：建歌单（pending=n）+ 逐首落任务行；歌词即刻落盘缓存。
  /// 返回导入歌单 id。`cacheDir` 需为应用私有缓存目录。
  Future<int> import(
      {required String name,
      required List<GithubTrack> tracks,
      required String cacheDir}) async {
    final playlistId = await _db.playlistDao.createPlaylist(name);
    await (_db.update(_db.playlists)..where((p) => p.id.equals(playlistId)))
        .write(PlaylistsCompanion(pending: Value(tracks.length)));

    for (final t in tracks) {
      String? lyricsPath;
      if (t.lyrics.isNotEmpty) {
        final f = File('$cacheDir/lyrics_gh_${playlistId}_${t.title.hashCode}.lrc');
        await f.writeAsString(t.lyrics, flush: true);
        lyricsPath = f.path;
      }
      await _db.collectDao.addTask(CollectTasksCompanion.insert(
        source: t.source,
        query: Value(t.query),
        url: t.url,
        title: t.title,
        artist: t.artist,
        lyricsPath: lyricsPath == null ? const Value.absent() : Value(lyricsPath),
        playlistId: Value(playlistId),
      ));
    }
    return playlistId;
  }
}

/// GitHub 歌单曲目（解析后的中间形态）。
class GithubTrack {
  const GithubTrack({
    required this.source,
    required this.query,
    required this.url,
    required this.artist,
    required this.title,
    required this.lyrics,
  });

  final String source;
  final String query;
  final String url;
  final String artist;
  final String title;
  final String lyrics;
}
