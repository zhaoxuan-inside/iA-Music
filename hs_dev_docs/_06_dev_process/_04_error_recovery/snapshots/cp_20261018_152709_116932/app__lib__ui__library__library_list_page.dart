/// 曲库列表页（S2 纵切；S4 增行点击起播/红心入口/加入歌单）。
///
/// REQ-LIB-06：排序四按（最近/标题/歌手/时长），切换即时生效（revision 重取）。
/// REQ-LIB-05：missingAt 非空 → 灰显 + 「文件缺失」徽标。
/// REQ-LIB-03/07：行菜单编辑标题 / 从曲库移除（对话框确认）。
/// REQ-NAV-02 随机入口（AppBar 洗牌键）；REQ-PLAY-01 行点击→沉浸页。
/// REQ-PL-03 加入歌单（重复=DB UNIQUE 拦截 → 原话提示）。
///
/// 播放域两种装配：
/// * 壳层注入 `ensurePlayback` → 用**壳层唯一实例**（跨 Tab 一致），本条/横幅由
///   壳层 dock 呈现（本页不重复渲染）；
/// * 独立挂载（设置页直达）→ 自建页面级实例并渲染本条/横幅（S3 行为保留）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/adapters/mpv_engine_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/playlists/playlist_service.dart';
import 'package:ia_music/ui/play/play_page.dart';
import 'package:ia_music/ui/play/playback_dock.dart';

final class LibraryListPage extends StatefulWidget {
  const LibraryListPage({
    super.key,
    required this.hub,
    this.ensurePlayback,
    this.onPlayRequested,
  });

  final LibraryHub hub;

  /// 壳层注入的播放域解析缝（空=本页自建页面级实例）。
  final Future<PlaybackService> Function()? ensurePlayback;

  /// 壳层推页缝（空=本页自行 push 沉浸页）。
  final VoidCallback? onPlayRequested;

  @override
  State<LibraryListPage> createState() => LibraryListPageState();
}

class LibraryListPageState extends State<LibraryListPage> {
  LibSort _sort = LibSort.recent;

  static const Map<LibSort, String> _sortLabels = {
    LibSort.recent: '最近',
    LibSort.title: '标题',
    LibSort.artist: '歌手',
    LibSort.duration: '时长',
  };

  /// 页面级实例（仅独立挂载时创建）。
  PlaybackService? _own;

  /// 最近使用的实例（快照/本条消费面）。
  PlaybackService? _active;

  bool get _ownsPlayback => widget.ensurePlayback == null;

  /// 播放服务缝（测试经同一入口驱动；未起播前为 null）。
  PlaybackService? get playbackOrNull => _active;

  Future<PlaybackService> _resolvePlayback() async {
    final injected = widget.ensurePlayback;
    if (injected != null) {
      final svc = await injected();
      _active = svc;
      return svc;
    }
    var svc = _own;
    if (svc == null || !svc.isReady) {
      svc = PlaybackService(MpvEngineAdapter(), widget.hub.data);
      await svc.init();
      _own = svc;
    }
    _active = svc;
    if (mounted) {
      setState(() {}); // 本条/横幅随后可见
    }
    return svc;
  }

  /// 随机播放（REQ-NAV-02 锚：点随机→曲库随机开播）；返回实例供测试驱动。
  Future<PlaybackService> startShuffle({int poolSize = 100}) async {
    final svc = await _resolvePlayback();
    await svc.startRandom(poolSize: poolSize);
    return svc;
  }

  /// 行点击起播（REQ-PLAY-01）：本曲为队列（列表循环续播），并进沉浸页。
  Future<void> playTrack(Track t) async {
    if (t.missingAt != null) {
      return;
    }
    final svc = await _resolvePlayback();
    await svc.playTrackIds([t.id]);
    if (!mounted) {
      return;
    }
    final opener = widget.onPlayRequested;
    if (opener != null) {
      opener();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlayPage(service: svc, data: widget.hub.data),
    ));
  }

  Future<void> dislikeNow() async {
    await _active?.dislikeThenNext();
  }

  Future<void> nextNow() async {
    await _active?.next();
  }

  /// 红心（列表行入口；REQ-PL-01 行级红心）——返回新状态（true=已红）。
  Future<bool> toggleFavorite(Track t) async {
    final svc = PlaylistService(widget.hub.data);
    final added = await svc.toggleFavorite(
      t.id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (mounted) {
      setState(() {
        if (added) {
          _favIds.add(t.id);
        } else {
          _favIds.remove(t.id);
        }
      });
    }
    return added;
  }

  final Set<int> _favIds = {};

  Future<void> refreshFavorites() async {
    final svc = PlaylistService(widget.hub.data);
    final fav = await svc.listAll();
    if (fav.isEmpty) {
      return;
    }
    final id = fav
        .firstWhere((d) => d.playlist.kind.name == 'system_favorite',
            orElse: () => fav.first)
        .playlist
        .id;
    final rows = await svc.rows(id);
    if (mounted) {
      setState(() {
        _favIds
          ..clear()
          ..addAll(rows.map((r) => r.id));
      });
    }
  }

  /// 加入歌单（REQ-PL-03）：重复 → false；UI 原话「《X》已在『Y』中」。
  /// 返回 (成功, 歌单名) 供测试/提示面复用。
  Future<(bool, String?)> addToPlaylist(Track t, int playlistId) async {
    final svc = PlaylistService(widget.hub.data);
    final digests = await svc.listAll();
    final name = digests
        .where((d) => d.playlist.id == playlistId)
        .map((d) => d.playlist.name)
        .firstOrNull;
    final ok = await svc.addTo(
      playlistId,
      t.id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) {
      return (ok, name);
    }
    final messenger = ScaffoldMessenger.of(context);
    // 原位提示：新提示即时顶替旧提示（同页连续操作不被 SnackBar 队列延迟）
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? '已加入『${name ?? ''}』' : '《${t.title ?? ''}》已在『${name ?? ''}』中'),
    ));
    return (ok, name);
  }

  @override
  void dispose() {
    // 全净释放（§4.3）：仅自建实例随页面收口（壳层实例归壳层）。
    if (_ownsPlayback) {
      unawaited(_own?.dispose());
    }
    _own = null;
    super.dispose();
  }

  Widget _noticeBar() {
    final svc = _active;
    if (svc == null) {
      return const SizedBox.shrink();
    }
    return PlaybackNoticeBar(service: svc);
  }

  Widget _playbackStrip() {
    final svc = _active;
    if (svc == null) {
      return const SizedBox.shrink();
    }
    return PlaybackStrip(
      service: svc,
      onOpen: () => unawaited(_openImmersive(svc)),
      onDislike: dislikeNow,
      onNext: nextNow,
    );
  }

  Future<void> _openImmersive(PlaybackService svc) async {
    final opener = widget.onPlayRequested;
    if (opener != null) {
      opener();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlayPage(service: svc, data: widget.hub.data),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final showOwnDock = _ownsPlayback && _active != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐空间'),
        actions: [
          IconButton(
            key: const ValueKey('shuffle_entry'),
            tooltip: '随机播放（随机池=全库−少播）',
            onPressed: () => unawaited(startShuffle()),
            icon: const Icon(Icons.shuffle),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showOwnDock) _noticeBar(),
          Expanded(
            child: StreamBuilder<int>(
              stream: widget.hub.revisions,
              initialData: 0,
              builder: (context, rev) => FutureBuilder<List<Track>>(
                key: ValueKey('tracks_${rev.data}_$_sort'),
                future: widget.hub.trackRowsSnapshot(_sort),
                builder: (context, snap) {
                  final rows = snap.data ?? const <Track>[];
                  if (rows.isEmpty) {
                    return const Center(child: Text('曲库为空'));
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            Text('${rows.length} 首',
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                            for (final entry in _sortLabels.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: _sort == entry.key,
                                onSelected: (_) =>
                                    setState(() => _sort = entry.key),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) => _row(context, rows[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (showOwnDock) _playbackStrip(),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Track t) {
    final missing = t.missingAt != null;
    final style = missing ? const TextStyle(color: Colors.grey) : null;
    final artist = (t.artistDisplay == null || t.artistDisplay!.isEmpty)
        ? ''
        : t.artistDisplay!;
    final dur = t.durationMs == null ? '' : _mmss(t.durationMs!);
    return ListTile(
      key: ValueKey('track_row_${t.id}'),
      enabled: !missing,
      onTap: missing ? null : () => unawaited(playTrack(t)),
      leading: missing
          ? const Icon(Icons.music_off, color: Colors.grey)
          : const Icon(Icons.music_note),
      title: Text(t.title ?? '', style: style),
      subtitle: Text('$artist  $dur', style: style),
      trailing: missing
          ? const Text('文件缺失', style: TextStyle(color: Colors.grey))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('row_heart_${t.id}'),
                  tooltip: _favIds.contains(t.id) ? '取消红心' : '红心',
                  onPressed: () => unawaited(toggleFavorite(t)),
                  icon: Icon(
                    _favIds.contains(t.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: _favIds.contains(t.id)
                        ? const Color(0xFFE53935)
                        : Colors.white54,
                  ),
                ),
                PopupMenuButton<_RowMenu>(
                  key: ValueKey('menu_${t.id}'),
                  onSelected: (m) => _menuAction(t, m),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _RowMenu.edit, child: Text('编辑标题')),
                    PopupMenuItem(
                        value: _RowMenu.addToPlaylist,
                        child: Text('加入歌单…')),
                    PopupMenuItem(
                        value: _RowMenu.remove, child: Text('从曲库移除')),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _menuAction(Track t, _RowMenu m) async {
    switch (m) {
      case _RowMenu.edit:
        final controller = TextEditingController(text: t.title ?? '');
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('编辑标题'),
            content: TextField(controller: controller),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存')),
            ],
          ),
        );
        if (ok ?? false) {
          await widget.hub.editTrackTitle(
            t.id,
            controller.text,
            nowMs: DateTime.now().millisecondsSinceEpoch,
          );
        }
      case _RowMenu.addToPlaylist:
        final svc = PlaylistService(widget.hub.data);
        final digests = await svc.listAll();
        if (!mounted) {
          return;
        }
        if (digests.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('先创建一个歌单')));
          return;
        }
        final chosen = await showDialog<int>(
          context: context,
          builder: (_) => SimpleDialog(
            title: const Text('加入歌单'),
            children: [
              for (final d in digests)
                SimpleDialogOption(
                  key: ValueKey('pick_playlist_${d.playlist.id}'),
                  onPressed: () => Navigator.pop(context, d.playlist.id),
                  child: Text('${d.playlist.name}（${d.trackCount}）'),
                ),
            ],
          ),
        );
        if (chosen == null) {
          return;
        }
        await addToPlaylist(t, chosen);
      case _RowMenu.remove:
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('从曲库移除？'),
            content: const Text('仅解除入库记录，不会删除本地文件。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('移除')),
            ],
          ),
        );
        if (ok ?? false) {
          await widget.hub.removeTrack(t.id,
              nowMs: DateTime.now().millisecondsSinceEpoch);
        }
    }
  }

  static String _mmss(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

enum _RowMenu { edit, addToPlaylist, remove }
