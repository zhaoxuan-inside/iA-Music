/// 歌单页：喜欢/历史系统卡 + 用户歌单 + 新建；详情页含曲目管理与移除。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../l10n/app_localizations.dart';
import '../../state/playback_controller.dart';
import '../../state/providers.dart';
import '../shared/common.dart' hide DbActions;
import 'history_page.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final p = context.ia;
    final playlists = ref.watch(playlistListProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                IaSpacing.xl, IaSpacing.l, IaSpacing.xl, IaSpacing.s),
            child: Row(
              children: [
                Text(s.navPlaylists,
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: p.mainText)),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _createPlaylist(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.newPlaylist),
                ),
              ],
            ),
          ),
          Expanded(
            child: playlists == null
                ? const Center(child: CircularProgressIndicator())
                : playlists.isEmpty
                    ? EmptyState(
                        icon: Icons.queue_music_outlined,
                        title: s.emptyPlaylists,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(IaSpacing.xl),
                        children: [
                          _HistoryCard(),
                          for (final pl in playlists.where((p) => p.isSystem))
                            _PlaylistCard(playlist: pl),
                          if (playlists.any((p) => !p.isSystem)) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  IaSpacing.xs, IaSpacing.l, IaSpacing.xs, IaSpacing.s),
                              child: Text(s.playlistMine,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: p.secondaryText)),
                            ),
                            for (final pl in playlists.where((p) => !p.isSystem))
                              _PlaylistCard(playlist: pl),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final name = await _askName(context, s.newPlaylist, s.playlistNameHint);
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final id = await ref.read(dbProvider).playlistDao.createPlaylist(name.trim());
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailPage(playlistId: id, name: name.trim()),
      ));
    }
  }
}

/// 播放列表流（含系统歌单自动建立）。
final playlistListProvider = StreamProvider.autoDispose<List<Playlist>>((ref) async* {
  await ref.watch(dbProvider).playlistDao.ensureFavorites();
  yield* ref.watch(dbProvider).playlistDao.watchPlaylists();
});

/// 歌单详情曲目流。
final playlistTracksProvider =
    StreamProvider.autoDispose.family<List<Track>, int>((ref, playlistId) {
  return ref.watch(dbProvider).playlistDao.watchPlaylistTracks(playlistId);
});

Future<String?> _askName(BuildContext context, String title, String hint,
    {String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(S.of(context).confirm)),
      ],
    ),
  );
}

/// 最近播放入口卡（数据在 play_history 表，不入歌单域）。
class _HistoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.ia;
    return Card(
      margin: const EdgeInsets.only(bottom: IaSpacing.m),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: IaSpacing.l, vertical: IaSpacing.s),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: p.lifted,
            borderRadius: BorderRadius.circular(IaSpacing.radiusM),
          ),
          child: Icon(Icons.history, color: p.secondaryText, size: 22),
        ),
        title: Text(s.playlistHistory,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
        ),
      ),
    );
  }
}

class _PlaylistCard extends ConsumerWidget {
  const _PlaylistCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final p = context.ia;
    final icon = switch (playlist.kind) {
      PlaylistKind.favorites => Icons.favorite,
      PlaylistKind.user => Icons.queue_music_outlined,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: IaSpacing.m),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: IaSpacing.l, vertical: IaSpacing.s),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: playlist.isSystem ? p.heart.withValues(alpha: 0.14) : p.lifted,
            borderRadius: BorderRadius.circular(IaSpacing.radiusM),
          ),
          child: Icon(icon,
              color: playlist.isSystem ? p.heart : p.secondaryText, size: 22),
        ),
        title: Text(playlist.name,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: Text(s.playlistCount(playlist.trackCount)),
        trailing: playlist.isSystem
            ? const SizedBox.shrink()
            : PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: p.secondaryText),
                onSelected: (v) async {
                  if (v == 'rename') {
                    final name = await _askName(
                        context, s.renamePlaylist, s.playlistNameHint,
                        initial: playlist.name);
                    if (name != null && name.trim().isNotEmpty) {
                      await ref
                          .read(dbProvider)
                          .playlistDao
                          .renamePlaylist(playlist.id, name.trim());
                    }
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(s.deletePlaylist),
                        content: Text(s.deletePlaylistConfirm(playlist.name)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(s.cancel)),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(s.delete)),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(dbProvider)
                          .playlistDao
                          .deletePlaylist(playlist.id);
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rename', child: Text(s.renamePlaylist)),
                  PopupMenuItem(value: 'delete', child: Text(s.deletePlaylist)),
                ],
              ),
        onTap: () {
          if (playlist.kind == PlaylistKind.favorites) {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PlaylistDetailPage(
                  playlistId: playlist.id, name: playlist.name, system: true),
            ));
          } else {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PlaylistDetailPage(
                  playlistId: playlist.id, name: playlist.name),
            ));
          }
        },
      ),
    );
  }
}

class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage({
    required this.playlistId,
    required this.name,
    this.system = false,
    super.key,
  });

  final int playlistId;
  final String name;
  final bool system;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final p = context.ia;
    final tracks = ref.watch(playlistTracksProvider(playlistId)).value;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: tracks == null
          ? const Center(child: CircularProgressIndicator())
          : tracks.isEmpty
              ? EmptyState(icon: Icons.queue_music_outlined, title: s.emptyPlaylists)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(IaSpacing.xl),
                      child: Row(
                        children: [
                          Text(s.playlistCount(tracks.length),
                              style: TextStyle(fontSize: 13, color: p.secondaryText)),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: tracks.isEmpty
                                ? null
                                : () => ref
                                    .read(playbackProvider.notifier)
                                    .playTracks(tracks),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(s.playAll),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.only(bottom: IaSpacing.xxl),
                        itemCount: tracks.length,
                        itemBuilder: (_, i) => TrackRow(
                          tracks: tracks,
                          index: i,
                          onRemoved: system
                              ? null
                              : (t) => ref
                                  .read(dbProvider)
                                  .playlistDao
                                  .removeTrack(playlistId, t.id),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
