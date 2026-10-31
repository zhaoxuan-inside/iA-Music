/// 歌单页（PLAYLISTS 列表 + 详情 · DEC-012 重写；WS2 补全：
/// 我的三卡数据行 REQ-NAV-05 + 歌单重命名/删除 REQ-PL-02 + 拖拽排序 REQ-PL-04）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/playlists/playlist_service.dart';
import 'package:ia_music/ui/library/history_page.dart';
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({
    super.key,
    required this.data,
    required this.ensurePlayback,
    this.onChanged,
    this.onGoLibrary,
  });

  final DataAccess data;
  final Future<PlaybackService> Function() ensurePlayback;
  final VoidCallback? onChanged;

  /// 「本地」卡跳转曲库 Tab（壳层注入；null=隐藏跳转）。
  final VoidCallback? onGoLibrary;

  @override
  State<PlaylistsPage> createState() => PlaylistsPageState();
}

class PlaylistsPageState extends State<PlaylistsPage> {
  PlaylistService get _svc => PlaylistService(widget.data);
  List<PlaylistDigest> _rows = const [];
  bool _loaded = false;
  int? _favCount;
  int? _histCount;
  int? _libCount;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final rows = await _svc.listAll();
    final fav = await _svc.favoriteCount();
    final hist = await _svc.historyCount();
    final lib = await _svc.libraryCount();
    if (mounted) {
      setState(() {
        _rows = rows;
        _loaded = true;
        _favCount = fav;
        _histCount = hist;
        _libCount = lib;
      });
    }
  }

  Future<void> _create() async {
    final name = await _promptName(
      context,
      title: sOf(context).playlistCreateTitle,
      hint: sOf(context).playlistNameHint,
    );
    if (name == null || name.isEmpty) return;
    await _svc.create(name, nowMs: DateTime.now().millisecondsSinceEpoch);
    widget.onChanged?.call();
    await _reload();
  }

  Future<void> _rename(PlaylistDigest d) async {
    final name = await _promptName(
      context,
      title: sOf(context).playlistRename,
      hint: sOf(context).playlistNewName,
      initial: d.playlist.name,
    );
    if (name == null || name.isEmpty || name == d.playlist.name) return;
    await _svc.rename(
      d.playlist.id,
      name,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(sOf(context).renamed)));
    widget.onChanged?.call();
    await _reload();
  }

  Future<void> _delete(PlaylistDigest d) async {
    final t = sOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.playlistDelete),
        content: Text(t.playlistDeleteConfirm(d.playlist.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
            key: const ValueKey('playlist_delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.playlistDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.delete(
      d.playlist.id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(sOf(context).playlistDeleted)));
    widget.onChanged?.call();
    await _reload();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HistoryPage(
        data: widget.data,
        ensurePlayback: widget.ensurePlayback,
        onChanged: widget.onChanged,
      ),
    ));
    unawaited(_reload());
  }

  Future<void> _open(PlaylistDigest d) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlaylistDetailPage(
        playlistId: d.playlist.id,
        title: d.playlist.name,
        data: widget.data,
        ensurePlayback: widget.ensurePlayback,
        onChanged: () {
          widget.onChanged?.call();
          unawaited(_reload());
        },
      ),
    ));
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('playlists_page'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.navPlaylists,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('playlist_create'),
                tooltip: t.playlistCreateTitle,
                onPressed: () => unawaited(_create()),
                icon: Icon(IaIcon.add, color: p.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 我的三卡（REQ-NAV-05）：喜欢 / 历史 / 本地
          Row(
            children: [
              _countCard(
                key: 'card_favorites',
                icon: IaIcon.heart,
                color: p.heart,
                label: t.cardFavorites,
                count: _favCount,
                onTap: () {
                  final fav = _rows.where(
                      (d) => d.playlist.kind == PlaylistKind.system_favorite);
                  if (fav.isNotEmpty) {
                    unawaited(_open(fav.first));
                  }
                },
              ),
              const SizedBox(width: 12),
              _countCard(
                key: 'card_history',
                icon: IaIcon.sequence,
                color: p.accent,
                label: t.cardHistory,
                count: _histCount,
                onTap: () => unawaited(_openHistory()),
              ),
              const SizedBox(width: 12),
              _countCard(
                key: 'card_local',
                icon: IaIcon.playlist,
                color: p.accent,
                label: t.cardLocal,
                count: _libCount,
                onTap: widget.onGoLibrary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loaded && _rows.isEmpty)
            Padding(
              key: const ValueKey('playlists_empty'),
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  t.playlistsEmpty,
                  style: TextStyle(fontSize: 13, color: p.secondaryText),
                ),
              ),
            )
          else
            for (final d in _rows)
              ListTile(
                key: ValueKey('playlist_row_${d.playlist.id}'),
                leading: Icon(
                  d.playlist.kind == PlaylistKind.system_favorite
                      ? IaIcon.heart
                      : IaIcon.playlist,
                  color: d.playlist.kind == PlaylistKind.system_favorite
                      ? p.heart
                      : p.accent,
                ),
                title: Text(d.playlist.name),
                subtitle: Text(t.trackCount(d.trackCount)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (d.playlist.kind != PlaylistKind.system_favorite) ...[
                      IconButton(
                        key: ValueKey('playlist_rename_${d.playlist.id}'),
                        tooltip: t.playlistRename,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => unawaited(_rename(d)),
                        icon: Icon(IaIcon.edit,
                            size: 20, color: p.secondaryText),
                      ),
                      IconButton(
                        key: ValueKey('playlist_delete_${d.playlist.id}'),
                        tooltip: t.playlistDelete,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => unawaited(_delete(d)),
                        icon:
                            Icon(IaIcon.delete, size: 20, color: p.secondaryText),
                      ),
                    ],
                    Icon(IaIcon.arrowForward),
                  ],
                ),
                onTap: () => unawaited(_open(d)),
              ),
        ],
      ),
    );
  }

  Widget _countCard({
    required String key,
    required IconData icon,
    required Color color,
    required String label,
    required int? count,
    VoidCallback? onTap,
  }) {
    final p = context.ia;
    return Expanded(
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        borderRadius: BorderRadius.circular(IaRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(IaRadius.card),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                '${count ?? '–'}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: p.mainText,
                  fontFeatures: kIaNumericFeatures,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: p.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  required String hint,
  String? initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final c = TextEditingController(text: initial ?? '');
      return AlertDialog(
        title: Text(title),
        content: TextField(
          key: const ValueKey('playlist_name_input'),
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(sOf(ctx).cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(sOf(ctx).save)),
        ],
      );
    },
  );
}

final class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.title,
    required this.data,
    required this.ensurePlayback,
    this.onChanged,
  });

  final int playlistId;
  final String title;
  final DataAccess data;
  final Future<PlaybackService> Function() ensurePlayback;
  final VoidCallback? onChanged;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  PlaylistService get _svc => PlaylistService(widget.data);
  List<Track> _rows = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final rows = await _svc.rows(widget.playlistId);
    if (mounted) {
      setState(() {
        _rows = rows;
        _loaded = true;
      });
    }
  }

  Future<void> _play({int startIndex = 0}) async {
    if (_rows.isEmpty) return;
    final svc = await widget.ensurePlayback();
    await svc.playTrackIds(
      [for (final t in _rows) t.id],
      startIndex: startIndex,
    );
  }

  Future<void> _remove(int trackId) async {
    await _svc.removeFrom(widget.playlistId, trackId);
    await _reload();
    widget.onChanged?.call();
  }

  /// 拖拽落位（REQ-PL-04）：onReorderItem 已修正 newIndex（移除项语义）。
  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      final moved = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, moved);
    });
    await _svc.reorder(
      widget.playlistId,
      orderedTrackIds: [for (final t in _rows) t.id],
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: ValueKey('playlist_detail_${widget.playlistId}'),
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_rows.isNotEmpty) _collage(),
          const SizedBox(height: 12),
          if (_rows.isNotEmpty)
            Center(
              child: FilledButton.icon(
                key: const ValueKey('playlist_play_all'),
                onPressed: () => unawaited(_play()),
                icon: Icon(IaIcon.play),
                label: Text(t.playlistPlayAll(_rows.length)),
              ),
            ),
          const SizedBox(height: 12),
          if (_loaded && _rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  t.playlistEmpty,
                  style: TextStyle(fontSize: 13, color: p.secondaryText),
                ),
              ),
            )
          else if (_rows.isNotEmpty)
            // 拖拽排序（REQ-PL-04；歌单内语义=自定顺序）
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              itemCount: _rows.length,
              onReorderItem: (oldIndex, newIndex) =>
                  unawaited(_reorder(oldIndex, newIndex)),
              itemBuilder: (context, i) {
                final tr = _rows[i];
                return InkWell(
                  key: ValueKey('playlist_track_${tr.id}'),
                  onTap: () => unawaited(_play(startIndex: i)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CoverArt(
                          trackId: tr.id,
                          title: tr.title ?? '',
                          data: widget.data,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr.title ?? t.untitled,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                tr.artistDisplay ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: p.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          iaMmss(tr.durationMs ?? 0),
                          style: TextStyle(
                            fontSize: 12,
                            color: p.secondaryText,
                            fontFeatures: kIaNumericFeatures,
                          ),
                        ),
                        IconButton(
                          tooltip: t.playlistRemoveTooltip,
                          onPressed: () => unawaited(_remove(tr.id)),
                          icon: Icon(IaIcon.close,
                              size: 18, color: p.secondaryText),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 头图=前 4 首封面拼贴（PRD REQ-PL-02 歌单封面自动面）。
  Widget _collage() {
    final head = _rows.take(4).toList();
    return SizedBox(
      key: const ValueKey('playlist_collage'),
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(IaRadius.cover),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final tr in head)
              CoverArt(
                trackId: tr.id,
                title: tr.title ?? '',
                data: widget.data,
                size: 89,
                radius: 0,
              ),
          ],
        ),
      ),
    );
  }
}
