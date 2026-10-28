/// 歌单页（PLAYLISTS 列表 + 详情 · DEC-012 重写）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/playlists/playlist_service.dart';
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
  });

  final DataAccess data;
  final Future<PlaybackService> Function() ensurePlayback;
  final VoidCallback? onChanged;

  @override
  State<PlaylistsPage> createState() => PlaylistsPageState();
}

class PlaylistsPageState extends State<PlaylistsPage> {
  PlaylistService get _svc => PlaylistService(widget.data);
  List<PlaylistDigest> _rows = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final rows = await _svc.listAll();
    if (mounted) {
      setState(() {
        _rows = rows;
        _loaded = true;
      });
    }
  }

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('新建歌单'),
          content: TextField(
            key: const ValueKey('playlist_name_input'),
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: '歌单名称'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('创建')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await _svc.create(name, nowMs: DateTime.now().millisecondsSinceEpoch);
    widget.onChanged?.call();
    await _reload();
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
    return Scaffold(
      key: const ValueKey('playlists_page'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PLAYLISTS',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('playlist_create'),
                tooltip: '新建歌单',
                onPressed: () => unawaited(_create()),
                icon: Icon(IaIcon.add, color: p.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loaded && _rows.isEmpty)
            Padding(
              key: const ValueKey('playlists_empty'),
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  '还没有歌单。红心的歌会进「我喜欢的音乐」。',
                  style: TextStyle(fontSize: 13, color: p.secondaryText),
                ),
              ),
            )
          else
            for (final d in _rows)
              ListTile(
                key: ValueKey('playlist_row_${d.playlist.id}'),
                leading: Icon(
                  d.playlist.kind.name == 'system_favorite'
                      ? IaIcon.heart
                      : IaIcon.playlist,
                  color: d.playlist.kind.name == 'system_favorite'
                      ? p.heart
                      : p.accent,
                ),
                title: Text(d.playlist.name),
                subtitle: Text('${d.trackCount} 首'),
                trailing: Icon(IaIcon.arrowForward),
                onTap: () => unawaited(_open(d)),
              ),
        ],
      ),
    );
  }
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

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final rows = await _svc.rows(widget.playlistId);
    if (mounted) setState(() => _rows = rows);
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

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return Scaffold(
      key: ValueKey('playlist_detail_${widget.playlistId}'),
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_rows.isNotEmpty)
            Center(
              child: FilledButton.icon(
                key: const ValueKey('playlist_play_all'),
                onPressed: () => unawaited(_play()),
                icon: Icon(IaIcon.play),
                label: Text('播放全部（${_rows.length} 首）'),
              ),
            ),
          const SizedBox(height: 12),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  '歌单是空的',
                  style: TextStyle(fontSize: 13, color: p.secondaryText),
                ),
              ),
            )
          else
            for (var i = 0; i < _rows.length; i++)
              InkWell(
                key: ValueKey('playlist_track_${_rows[i].id}'),
                onTap: () => unawaited(_play(startIndex: i)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CoverArt(
                        trackId: _rows[i].id,
                        title: _rows[i].title ?? '',
                        data: widget.data,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _rows[i].title ?? '未命名',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _rows[i].artistDisplay ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: p.secondaryText),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        iaMmss(_rows[i].durationMs ?? 0),
                        style: TextStyle(
                          fontSize: 12,
                          color: p.secondaryText,
                          fontFeatures: kIaNumericFeatures,
                        ),
                      ),
                      IconButton(
                        tooltip: '从歌单移除',
                        onPressed: () => unawaited(_remove(_rows[i].id)),
                        icon: Icon(IaIcon.close,
                            size: 18, color: p.secondaryText),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
