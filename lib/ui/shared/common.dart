/// 共享组件：封面（四级决议入口）、曲目行、空态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../l10n/app_localizations.dart';
import '../../state/library_providers.dart';
import '../../state/media_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/providers.dart';

/// 封面：DB 缓存位 → 链决议 → 首字母色块。
class CoverArt extends ConsumerWidget {
  const CoverArt({required this.track, this.size = IaSpacing.coverSmall, super.key});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ia;
    final file = ref
        .watch(coverProvider((track.id, track.coverPath)))
        .value;
    final radius = BorderRadius.circular(IaSpacing.radiusS);
    if (file != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(file,
            width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }
    final initial = track.title.isNotEmpty ? track.title.substring(0, 1).toUpperCase() : '?';
    final hue = (track.id * 47) % 360;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: HSLColor.fromAHSL(1, hue.toDouble(), 0.32, 0.28).toColor(),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: p.mainText.withValues(alpha: 0.9),
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 曲目行：点击播放整批；长按/右键上下文菜单。
class TrackRow extends ConsumerWidget {
  const TrackRow({
    required this.tracks,
    required this.index,
    this.onRemoved,
    super.key,
  });

  final List<Track> tracks;
  final int index;
  final void Function(Track track)? onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ia;
    final s = S.of(context);
    final track = tracks[index];
    final playing = ref.watch(
        playbackProvider.select((snap) => snap.current?.id == track.id && snap.playing));
    final fav = ref.watch(favoriteProvider(track.id)).value ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: IaSpacing.m),
      leading: CoverArt(track: track),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: playing ? p.accent : p.mainText,
          fontWeight: playing ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${track.artistDisplay} · ${track.albumDisplay}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.missing)
            Text(s.trackMissing,
                style: TextStyle(fontSize: 11, color: p.secondaryText)),
          if (!track.missing) ...[
            IconButton(
              icon: Icon(fav ? Icons.favorite : Icons.favorite_outline,
                  size: 20,
                  color: fav ? p.heart : p.secondaryText),
              onPressed: () => ref
                  .read(dbActionsProvider)
                  .setFavorite(track.id, !fav),
            ),
            Text(_fmt(track.durationMs),
                style: TextStyle(fontSize: 12, color: p.secondaryText)),
            IconButton(
              icon: Icon(Icons.more_vert, size: 20, color: p.secondaryText),
              onPressed: () => _showMenu(context, ref, track),
            ),
          ],
        ],
      ),
      onTap: track.missing
          ? null
          : () => ref.read(playbackProvider.notifier).playTracks(tracks, startIndex: index),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref, Track track) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(s.playNext),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(playbackProvider.notifier).playNext(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(s.playlistFavorites),
              onTap: () async {
                Navigator.pop(ctx);
                final cur = await ref.read(dbActionsProvider).isFavorite(track.id);
                await ref.read(dbActionsProvider).setFavorite(track.id, !cur);
              },
            ),
            if (onRemoved != null)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: Text(s.remove),
                onTap: () {
                  Navigator.pop(ctx);
                  onRemoved!(track);
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int ms) {
    final m = ms ~/ 60000;
    final sec = (ms % 60000) ~/ 1000;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

/// 曲库/歌单域的轻动作集合（喜欢切换、加入歌单对话框）。
final dbActionsProvider = Provider<DbActions>(DbActions.new);

class DbActions {
  DbActions(this._ref);

  final Ref _ref;

  Future<void> setFavorite(int trackId, bool fav) =>
      _ref.read(dbProvider).playlistDao.setFavorite(trackId, fav);

  Future<bool> isFavorite(int trackId) =>
      _ref.read(dbProvider).playlistDao.isFavorite(trackId);
}

/// 空态占位。
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: p.secondaryText.withValues(alpha: 0.5)),
          const SizedBox(height: IaSpacing.l),
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: p.mainText)),
          if (subtitle != null) ...[
            const SizedBox(height: IaSpacing.s),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: p.secondaryText)),
          ],
          if (action != null) ...[
            const SizedBox(height: IaSpacing.xl),
            action!,
          ],
        ],
      ),
    );
  }
}
