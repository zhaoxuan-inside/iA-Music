/// 屏1 正在播放：大封面 + 黑胶倒影 + 细线进度；无会话 = 随缘听歌磁贴。
///
/// 这一屏是 Zune 的「封面即页面」：封面不缩在信息卡里，而是以接近满宽
/// 的尺寸落在黑底上，标题与进度从属于它。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../detail/detail_page.dart';
import '../play/now_playing/now_playing_page.dart';
import '../shared/ambient.dart';
import '../shared/cover.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';

class PlayingPage extends ConsumerWidget {
  const PlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select：切歌才重建整屏；positionMs 心跳由 _NowHeroSeek 单独订阅。
    final cur = ref.watch(playbackProvider.select((s) => s.current));
    final edge = edgeInsets(context);
    final count = ref.watch(trackCountProvider).value ?? 0;

    return HubPage(
      header: const PageHeader(
        kicker: 'I A  M U S I C',
        title: '音乐',
        hero: true,
        trailing: SearchAction(),
      ),
      children: [
        if (cur != null)
          _NowHero(cur: cur, edge: edge)
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
  const _NowHero({required this.cur, required this.edge});

  final Track cur;
  final EdgeInsets edge;

  @override
  ConsumerState<_NowHero> createState() => _NowHeroState();
}

class _NowHeroState extends ConsumerState<_NowHero> {
  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final cur = widget.cur;
    final cover = math.min(
      MediaQuery.sizeOf(context).width - widget.edge.horizontal - 16,
      IaSpacing.coverHeroMax,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: GestureDetector(
            onTap: () => openNowPlaying(context),
            // DESIGN「封面切换」：大封面 260ms 交叉淡入。
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: AlbumArt(
                key: ValueKey('hub-art-${cur.id}'),
                track: cur,
                size: cover,
                reflection: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: IaMotion.trackSlide,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey('hub-meta-${cur.id}'),
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
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: IaColors.textMid,
                      ),
                    ),
                  ],
                ),
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
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 28,
                  color: IaColors.textHi,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _NowHeroSeek(cur: cur),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(playbackProvider.notifier).previous(),
              icon: const Icon(
                Icons.skip_previous,
                size: 22,
                color: IaColors.textMid,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(playbackProvider.notifier).next(),
              icon: const Icon(
                Icons.skip_next,
                size: 22,
                color: IaColors.textMid,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => openNowPlaying(context),
              child: const Text(
                '打开播放页  ›',
                style: TextStyle(fontSize: 12, color: IaColors.textMid),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 在播磁贴的进度区（细线 seek + 时间行）：唯一订阅 positionMs 心跳的部分。
/// 时长取当前曲目元数据（快照 durationMs 曾是恒 0 死字段，seek 一直失效）。
class _NowHeroSeek extends ConsumerStatefulWidget {
  const _NowHeroSeek({required this.cur});

  final Track cur;

  @override
  ConsumerState<_NowHeroSeek> createState() => _NowHeroSeekState();
}

class _NowHeroSeekState extends ConsumerState<_NowHeroSeek> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.cur.durationMs;
    final pos = (_drag ??
            (durationMs > 0
                ? ref.watch(playbackProvider.select((s) => s.positionMs)) /
                    durationMs
                : 0.0))
        .clamp(0.0, 1.0);
    final positionMs = ref.watch(playbackProvider.select((s) => s.positionMs));

    return Column(
      children: [
        ZuneSeekBar(
          value: pos,
          onSeek: durationMs > 0 ? (v) => setState(() => _drag = v) : null,
          onSeekEnd: durationMs > 0
              ? (v) {
                  ref
                      .read(playbackProvider.notifier)
                      .seekTo((v * durationMs).round());
                  setState(() => _drag = null);
                }
              : null,
        ),
        Row(
          children: [
            Text(
              formatDuration(positionMs),
              style: const TextStyle(fontSize: 11, color: IaColors.textLow),
            ),
            const Spacer(),
            Text(
              formatDuration(durationMs),
              style: const TextStyle(fontSize: 11, color: IaColors.textLow),
            ),
          ],
        ),
      ],
    );
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
                  IaSpacing.xl,
                  IaSpacing.xl,
                  IaSpacing.xl,
                  IaSpacing.l,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '随缘听歌',
                      style: TextStyle(
                        fontSize: 38,
                        height: 1,
                        fontWeight: IaType.light,
                        letterSpacing: IaType.titleTracking,
                        color: IaColors.textHi,
                      ),
                    ),
                    const SizedBox(height: IaSpacing.s),
                    const Text(
                      '全曲库随机 · 一点就开 ▶',
                      style: TextStyle(fontSize: 12, color: IaColors.textLow),
                    ),
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
      return const Text(
        '曲库还是空的——先去收集音乐',
        style: TextStyle(fontSize: 12, color: IaColors.textLow),
      );
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
                InkWell(
                  onTap: () => Navigator.of(context).push(zuneRoute<void>(
                      builder: (_) => DetailPage(
                          type: DetailType.album, id: albumKey(a.album)))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: IaColors.textHi,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: IaColors.textLow),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 专辑封面：取该专辑首曲封面；无封面时沿用确定性色块。
/// 点击封面 = 播放该专辑（从首曲起整张专辑入队）。
class _AlbumCover extends ConsumerWidget {
  const _AlbumCover({required this.album, this.size = double.infinity});

  final AlbumGroup album;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 封面走单行首曲查询；整张专辑队列在点按时一次性读取（不再常驻 watch）。
    final first =
        ref.watch(albumFirstTrackProvider(albumKey(album.album))).value;
    if (first == null) {
      if (size.isFinite) {
        return SizedBox(
          width: size,
          height: size,
          child: const ColoredBox(color: IaColors.hairline),
        );
      }
      return const ColoredBox(color: IaColors.hairline);
    }
    return InkWell(
      onTap: () async {
        final tracks =
            await ref.read(albumTracksProvider(albumKey(album.album)).future);
        if (!context.mounted || tracks.isEmpty) {
          return;
        }
        await ref
            .read(playbackProvider.notifier)
            .playTrack(tracks.first, queue: tracks);
      },
      child: CoverArt(track: first, size: size),
    );
  }
}
