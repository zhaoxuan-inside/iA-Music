/// 屏1 正在播放：大封面 + 黑胶倒影 + 细线进度；无会话 = 随缘听歌磁贴。
///
/// 这一屏是 Zune 的「封面即页面」：封面不缩在信息卡里，而是以接近满宽
/// 的尺寸落在黑底上，标题与进度从属于它。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playback.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../play/now_playing.dart';
import '../shared/ambient.dart';
import '../shared/cover.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';

class PlayingPage extends ConsumerWidget {
  const PlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playbackProvider);
    final cur = snap.current;
    final edge = edgeInsets(context);
    final count = ref.watch(trackCountProvider).value ?? 0;

    return ListView(
      padding: hubPadding(context),
      children: [
        const SizedBox(height: IaSpacing.xl),
        const PageHeader(
          kicker: 'I A  M U S I C',
          title: '音乐',
          hero: true,
          trailing: SearchAction(),
        ),
        const SizedBox(height: IaSpacing.xl),
        if (cur != null)
          _NowHero(snap: snap, cur: cur, edge: edge)
        else
          const _RandomTile(),
        const SizedBox(height: IaSpacing.xxl),
        SectionHead(label: '音乐仓库 · 最近添加', meta: '$count 首'),
        const SizedBox(height: IaSpacing.m),
        const _RecentStrip(),
      ],
    );
  }
}

/// 在播大磁贴：封面 / 倒影 / 标题 / 细线进度 / 播放键。
class _NowHero extends ConsumerStatefulWidget {
  const _NowHero({
    required this.snap,
    required this.cur,
    required this.edge,
  });

  final PlaybackSnapshot snap;
  final Track cur;
  final EdgeInsets edge;

  @override
  ConsumerState<_NowHero> createState() => _NowHeroState();
}

class _NowHeroState extends ConsumerState<_NowHero> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final snap = widget.snap;
    final cur = widget.cur;
    final cover = math.min(
      MediaQuery.sizeOf(context).width - widget.edge.horizontal - 16,
      IaSpacing.coverHeroMax,
    );
    final pos = (_drag ??
            (snap.durationMs > 0 ? snap.positionMs / snap.durationMs : 0.0))
        .clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: GestureDetector(
            onTap: () => openNowPlaying(context),
            child: AlbumArt(track: cur, size: cover, reflection: true),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cur.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.14,
                      fontWeight: IaType.light,
                      letterSpacing: IaType.titleTracking,
                      color: IaColors.textHi,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${cur.artistDisplay} · ${cur.albumDisplay}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12.5, color: IaColors.textMid),
                  ),
                ],
              ),
            ),
            const SizedBox(width: IaSpacing.l),
            InkWell(
              onTap: () => ref.read(playbackProvider.notifier).togglePlay(),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.accent, width: 1.2),
                ),
                child: Icon(
                  snap.playing ? Icons.pause : Icons.play_arrow,
                  size: 28,
                  color: IaColors.textHi,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ZuneSeekBar(
          value: pos,
          onSeek: snap.durationMs > 0
              ? (v) => setState(() => _drag = v)
              : null,
          onSeekEnd: snap.durationMs > 0
              ? (v) {
                  ref
                      .read(playbackProvider.notifier)
                      .seekTo((v * snap.durationMs).round());
                  setState(() => _drag = null);
                }
              : null,
        ),
        Row(
          children: [
            Text(_fmt(snap.positionMs),
                style: const TextStyle(fontSize: 11, color: IaColors.textLow)),
            const Spacer(),
            Text(_fmt(snap.durationMs),
                style: const TextStyle(fontSize: 11, color: IaColors.textLow)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(playbackProvider.notifier).previous(),
              icon: const Icon(Icons.skip_previous,
                  size: 22, color: IaColors.textMid),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(playbackProvider.notifier).next(),
              icon: const Icon(Icons.skip_next,
                  size: 22, color: IaColors.textMid),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => openNowPlaying(context),
              child: const Text('打开播放页  ›',
                  style: TextStyle(fontSize: 12, color: IaColors.textMid)),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// 无会话：随缘听歌磁贴（最近入库封面做 2×2 拼贴，压暗作背景）。
class _RandomTile extends ConsumerWidget {
  const _RandomTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final albums =
        ref.watch(recentAddedAlbumsProvider).value ?? const <AlbumGroup>[];
    final four = albums.take(4).toList();

    return InkWell(
      onTap: () => _listenRandom(context, ref),
      child: SizedBox(
        height: 212,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (four.isNotEmpty)
                Opacity(
                  opacity: 0.46,
                  child: GridView.count(
                    crossAxisCount: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    childAspectRatio: 1.45,
                    children: [
                      for (final a in four) _AlbumCover(album: a),
                      for (var i = four.length; i < 4; i++)
                        const ColoredBox(color: IaColors.canvas),
                    ],
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.92),
                      Colors.black.withValues(alpha: 0.34),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: p.accent, width: 3)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    IaSpacing.xl, IaSpacing.xl, IaSpacing.xl, IaSpacing.l),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('随缘听歌',
                        style: TextStyle(
                            fontSize: 38,
                            height: 1,
                            fontWeight: IaType.light,
                            letterSpacing: IaType.titleTracking,
                            color: IaColors.textHi)),
                    const SizedBox(height: IaSpacing.s),
                    const Text('全曲库随机 · 一点就开 ▶',
                        style:
                            TextStyle(fontSize: 12, color: IaColors.textLow)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _listenRandom(BuildContext context, WidgetRef ref) async {
    final lib = ref.read(listenLibraryProvider);
    final tracks = await lib.all();
    if (!context.mounted) {
      return;
    }
    if (tracks.isEmpty) {
      showWpToast(context, title: '随缘听歌', message: '曲库为空——先去收集音乐');
      return;
    }
    await ref.read(playbackProvider.notifier).playTracks(tracks, shuffle: true);
  }
}

/// 最近添加封面长廊（按 addedAt 倒序）。
class _RecentStrip extends ConsumerWidget {
  const _RecentStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums =
        ref.watch(recentAddedAlbumsProvider).value ?? const <AlbumGroup>[];
    if (albums.isEmpty) {
      return const Text('曲库还是空的——先去收集音乐',
          style: TextStyle(fontSize: 12, color: IaColors.textLow));
    }
    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: math.min(albums.length, 10),
        separatorBuilder: (_, _) => const SizedBox(width: IaSpacing.m),
        itemBuilder: (_, i) {
          final a = albums[i];
          return SizedBox(
            width: 138,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AlbumCover(album: a, size: 138),
                const SizedBox(height: IaSpacing.s),
                Text(a.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12.5, color: IaColors.textHi)),
                const SizedBox(height: 2),
                Text(a.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: IaColors.textLow)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 专辑封面：取该专辑首曲封面；无封面时沿用确定性色块。
class _AlbumCover extends ConsumerWidget {
  const _AlbumCover({required this.album, this.size = double.infinity});

  final AlbumGroup album;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks =
        ref.watch(albumTracksProvider(albumKey(album.album))).value ??
            const <Track>[];
    final first = tracks.firstOrNull;
    if (first == null) {
      if (size.isFinite) {
        return SizedBox(
            width: size,
            height: size,
            child: const ColoredBox(color: IaColors.hairline));
      }
      return const ColoredBox(color: IaColors.hairline);
    }
    return CoverArt(track: first, size: size);
  }
}
