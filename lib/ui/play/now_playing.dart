/// 沉浸播放页：pivot（播放|歌词|队列）+ 整页横滑切歌 + 歌词沉浸 + 队列编辑。
///
/// Zune HD 的做法：不套一层「播放器卡片」，而是让封面、倒影、环境光
/// 直接成为页面；控制只保留细线、细字与一个 accent 圆环。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playback.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/media_providers.dart';
import '../../state/playback_controller.dart';
import '../shared/actions.dart';
import '../shared/ambient.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

/// 打开沉浸播放页：从底部上浮 + 淡入（Zune 磁贴升起）。
Future<void> openNowPlaying(BuildContext context) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => const NowPlayingPage(),
    transitionsBuilder: (_, anim, _, child) {
      final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(t),
        child: FadeTransition(opacity: t, child: child),
      );
    },
  ));
}

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  int _pane = 0; // 0 播放 1 歌词 2 队列
  double? _dragValue;
  Offset? _panStart;
  bool _swiped = false;

  static const _panes = ['播放', '歌词', '队列'];

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(playbackProvider);
    final edge = edgeInsets(context);
    final cur = snap.current;

    if (cur == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: AmbientBackdrop(
        track: cur,
        opacity: 0.56,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NpHeader(
                pane: _pane,
                edge: edge,
                index: snap.index,
                total: snap.queue.length,
                onPick: (i) => setState(() => _pane = i),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => _panStart = d.localPosition,
                  onPanUpdate: (d) {
                    if (_panStart == null || _swiped) {
                      return;
                    }
                    final dx = d.localPosition.dx - _panStart!.dx;
                    final dy = d.localPosition.dy - _panStart!.dy;
                    // 播放屏下滑退出（与系统返回等价）。
                    if (_pane == 0 && dy > 70 && dy.abs() > dx.abs() * 1.4) {
                      _swiped = true;
                      Navigator.of(context).maybePop();
                      return;
                    }
                    // 播放屏：横滑切歌；其它屏：横滑换屏。
                    if (dx.abs() > 72 && dx.abs() > dy.abs() * 1.5) {
                      _swiped = true;
                      if (_pane == 0) {
                        dx < 0
                            ? ref.read(playbackProvider.notifier).next()
                            : ref.read(playbackProvider.notifier).previous();
                      } else {
                        setState(() {
                          _pane = (_pane + (dx < 0 ? 1 : -1)).clamp(0, 2);
                        });
                      }
                    }
                  },
                  onPanEnd: (_) {
                    _panStart = null;
                    Future<void>.delayed(const Duration(milliseconds: 60), () {
                      if (mounted) {
                        _swiped = false;
                      }
                    });
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: switch (_pane) {
                      1 => const _LyricsPane(key: ValueKey('lyr')),
                      2 => const _QueuePane(key: ValueKey('q')),
                      _ => _PlayPane(
                          key: const ValueKey('play'),
                          snap: snap,
                          cur: cur,
                          edge: edge,
                          dragValue: _dragValue,
                          onSeek: (v) => setState(() => _dragValue = v),
                          onSeekEnd: (v) {
                            ref
                                .read(playbackProvider.notifier)
                                .seekTo((v * snap.durationMs).round());
                            setState(() => _dragValue = null);
                          },
                        ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ── 页头：Zune pivot ─────────────────────────────────────────────── */

class _NpHeader extends StatelessWidget {
  const _NpHeader({
    required this.pane,
    required this.edge,
    required this.index,
    required this.total,
    required this.onPick,
  });

  final int pane;
  final EdgeInsets edge;
  final int index;
  final int total;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return Padding(
      padding: EdgeInsets.fromLTRB(edge.left, 8, edge.right, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _NowPlayingPageState._panes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: IaSpacing.l),
                  child: InkWell(
                    onTap: () => onPick(i),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _NowPlayingPageState._panes[i],
                          style: TextStyle(
                            fontSize:
                                pane == i ? IaType.page : IaType.pivotIdle,
                            height: 1,
                            fontWeight:
                                pane == i ? IaType.light : IaType.regular,
                            color: pane == i
                                ? IaColors.textHi
                                : IaColors.textMid,
                          ),
                        ),
                        const SizedBox(height: 9),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: pane == i ? 28 : 0,
                          height: 2,
                          color: p.accent,
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${(index + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                      color: IaColors.textLow,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ── 播放屏 ───────────────────────────────────────────────────────── */

class _PlayPane extends ConsumerWidget {
  const _PlayPane({
    required this.snap,
    required this.cur,
    required this.edge,
    required this.dragValue,
    required this.onSeek,
    required this.onSeekEnd,
    super.key,
  });

  final PlaybackSnapshot snap;
  final Track cur;
  final EdgeInsets edge;
  final double? dragValue;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSeekEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final pos = (dragValue ??
            (snap.durationMs > 0 ? snap.positionMs / snap.durationMs : 0.0))
        .clamp(0.0, 1.0);
    final cover = math.min(
      MediaQuery.sizeOf(context).width - edge.horizontal - 12,
      IaSpacing.coverHeroMax,
    );
    final liked = ref.watch(favoriteProvider(cur.id)).value ?? false;
    final next = snap.queue.isEmpty
        ? null
        : snap.queue[(snap.index + 1) % snap.queue.length];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(edge.left, 16, edge.right, 20),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: GestureDetector(
              key: ValueKey('art-${cur.id}'),
              onTap: () => ref
                  .read(playbackProvider.notifier)
                  .togglePlay(),
              child: AlbumArt(track: cur, size: cover, reflection: true),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            cur.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              height: 1.18,
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
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: IaColors.textMid),
          ),
          const SizedBox(height: 22),
          ZuneSeekBar(
            value: pos,
            onSeek: snap.durationMs > 0 ? onSeek : null,
            onSeekEnd: snap.durationMs > 0 ? onSeekEnd : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Text(_fmt(snap.positionMs),
                    style:
                        const TextStyle(fontSize: 11, color: IaColors.textLow)),
                const Spacer(),
                Text(_fmt(snap.durationMs),
                    style:
                        const TextStyle(fontSize: 11, color: IaColors.textLow)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () =>
                    ref.read(playbackProvider.notifier).toggleShuffle(),
                icon: Icon(Icons.shuffle,
                    size: 20,
                    color: snap.shuffle ? p.accent : IaColors.textMid),
              ),
              IconButton(
                onPressed: () => ref.read(playbackProvider.notifier).previous(),
                icon: const Icon(Icons.skip_previous,
                    size: 34, color: IaColors.textHi),
              ),
              InkWell(
                onTap: () =>
                    ref.read(playbackProvider.notifier).togglePlay(),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: p.accent, width: 1.2),
                  ),
                  child: Icon(
                    snap.playing ? Icons.pause : Icons.play_arrow,
                    size: 34,
                    color: IaColors.textHi,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => ref.read(playbackProvider.notifier).next(),
                icon:
                    const Icon(Icons.skip_next, size: 34, color: IaColors.textHi),
              ),
              IconButton(
                onPressed: () async {
                  final nextMode = snap.repeat == RepeatMode.off
                      ? RepeatMode.all
                      : snap.repeat == RepeatMode.all
                          ? RepeatMode.one
                          : RepeatMode.off;
                  await ref
                      .read(playbackProvider.notifier)
                      .setRepeatMode(nextMode);
                },
                icon: Icon(
                  snap.repeat == RepeatMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                  size: 20,
                  color:
                      snap.repeat != RepeatMode.off ? p.accent : IaColors.textMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await ref.read(dbActionsProvider).setFavorite(cur.id, !liked);
                },
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_outline,
                  size: 18,
                  color: liked ? p.accent : IaColors.textMid,
                ),
                label: Text(
                  liked ? '已喜欢' : '喜欢',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: liked ? p.accent : IaColors.textMid,
                  ),
                ),
              ),
              const SizedBox(width: IaSpacing.l),
              TextButton(
                onPressed: () => _sleepMenu(context, ref),
                child: Text(
                  snap.sleepEndsAt != null
                      ? '睡眠定时 · 至 ${snap.sleepEndsAt!.hour}:${snap.sleepEndsAt!.minute.toString().padLeft(2, '0')}'
                      : '睡眠定时',
                  style: const TextStyle(
                      fontSize: 12.5, color: IaColors.textMid),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            child: next == null || next.id == cur.id
                ? null
                : Text(
                    '下一首   ${next.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      color: IaColors.textLow,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 睡眠定时：WP 菜单（15 / 30 / 60 分钟 / 取消）。
  void _sleepMenu(BuildContext context, WidgetRef ref) {
    final snap = ref.read(playbackProvider);
    showWpMenu(context, title: '睡眠定时', items: [
      for (final min in const [15, 30, 60])
        (
          '$min 分钟（淡出）',
          () => ref.read(playbackProvider.notifier).setSleepTimer(min),
        ),
      if (snap.sleepEndsAt != null)
        (
          '取消定时',
          () => ref.read(playbackProvider.notifier).cancelSleepTimer(),
        ),
    ]);
  }

  String _fmt(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/* ── 歌词屏 ───────────────────────────────────────────────────────── */

class _LyricsPane extends ConsumerStatefulWidget {
  const _LyricsPane({super.key});

  @override
  ConsumerState<_LyricsPane> createState() => _LyricsPaneState();
}

class _LyricsPaneState extends ConsumerState<_LyricsPane> {
  final _scroll = ScrollController();
  int? _lastLine;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final snap = ref.watch(playbackProvider);
    final cur = snap.current;
    final edge = edgeInsets(context);
    if (cur == null) {
      return const SizedBox.shrink();
    }
    final result = ref.watch(trackLyricsProvider(cur.id)).value;
    final doc = result?.doc;

    if (doc == null || doc.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(IaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('无词',
                  style: TextStyle(
                      fontSize: IaType.display,
                      fontWeight: IaType.light,
                      letterSpacing: IaType.titleTracking,
                      color: IaColors.textLow)),
              const SizedBox(height: IaSpacing.m),
              const Text('这首歌还没有歌词 —— 之后可在设置中补全',
                  style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            ],
          ),
        ),
      );
    }

    final offset = result?.offsetMs ?? 0;
    final line = doc.lineIndexAt(snap.positionMs - offset);

    // 当前行滚动定位
    if (line != null && line != _lastLine && _scroll.hasClients) {
      _lastLine = line;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) {
          return;
        }
        const extent = 46.0;
        final target = (line * extent - _scroll.position.viewportDimension / 3)
            .clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.animateTo(target,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic);
      });
    }

    return Column(
      children: [
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.13, 0.82, 1],
              colors: [
                Color(0x00FFFFFF),
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
            ).createShader(bounds),
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                  edge.left, 64, edge.right, 40),
              itemCount: doc.lines.length,
              itemExtent: 46,
              itemBuilder: (_, i) {
                final active = i == line;
                return InkWell(
                  onTap: () => ref
                      .read(playbackProvider.notifier)
                      .seekTo(doc.lines[i].tMs + offset),
                  onLongPress: () => _offsetMenu(context, cur.id, offset),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      doc.lines[i].text.isEmpty ? '· · ·' : doc.lines[i].text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            active ? IaType.pivotCur : IaType.list,
                        fontWeight:
                            active ? IaType.light : IaType.regular,
                        letterSpacing: active ? 0.2 : 0,
                        color: active ? p.accent : IaColors.lyricIdle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
              left: edge.left, right: edge.right, bottom: IaSpacing.m),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (label, delta) in const [
                ('−0.5s', -500),
                ('重置', 0),
                ('+0.5s', 500),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ZuneChip(
                    label: label,
                    active: delta == 0 && offset != 0,
                    onTap: () => ref
                        .read(lyricsActionsProvider)
                        .setOffset(cur.id, delta == 0 ? 0 : offset + delta),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 歌词偏移 WP 菜单（PRODUCT：长按调偏移）。
  void _offsetMenu(BuildContext context, int trackId, int offset) {
    showWpMenu(context, title: '歌词偏移', items: [
      ('偏移 −0.5s',
          () => ref.read(lyricsActionsProvider).setOffset(trackId, offset - 500)),
      ('重置（0）',
          () => ref.read(lyricsActionsProvider).setOffset(trackId, 0)),
      ('偏移 +0.5s',
          () => ref.read(lyricsActionsProvider).setOffset(trackId, offset + 500)),
    ]);
  }
}

/* ── 队列屏 ───────────────────────────────────────────────────────── */

class _QueuePane extends ConsumerWidget {
  const _QueuePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final snap = ref.watch(playbackProvider);
    final edge = edgeInsets(context);

    if (snap.queue.isEmpty) {
      return const Center(
          child: Text('队列为空',
              style: TextStyle(
                  fontSize: IaType.menu,
                  fontWeight: IaType.light,
                  color: IaColors.textLow)));
    }

    return ReorderableListView.builder(
      // 长按整行拖拽重排；tap（跳播）与 close（移除）不受影响。
      buildDefaultDragHandles: false,
      header: Padding(
        padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 0),
        child: Row(
          children: [
            Text('队列 · ${snap.queue.length} 首',
                style: const TextStyle(fontSize: 12.5, color: IaColors.textMid)),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  ref.read(playbackProvider.notifier).clearQueue(),
              child: const Text('清空',
                  style:
                      TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            ),
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.s, edge.right, 40),
      itemCount: snap.queue.length,
      onReorderItem: (oldIndex, newIndex) =>
          ref.read(playbackProvider.notifier).reorderQueue(oldIndex, newIndex),
      proxyDecorator: (child, _, anim) => Material(
        color: Colors.black,
        child: DecoratedBox(
          decoration: BoxDecoration(
              border: Border(left: BorderSide(color: p.accent, width: 2))),
          child: child,
        ),
      ),
      itemBuilder: (_, i) {
        final t = snap.queue[i];
        final active = i == snap.index;
        return ReorderableDelayedDragStartListener(
          key: ValueKey('q-$i-${t.id}'),
          index: i,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref
                  .read(playbackProvider.notifier)
                  .playTracks(snap.queue, startIndex: i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.s, vertical: 9),
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: IaColors.hairline))),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        active ? '♪' : '${i + 1}'.padLeft(2, '0'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            color: active ? p.accent : IaColors.textLow),
                      ),
                    ),
                    const SizedBox(width: IaSpacing.m),
                    CoverArt(track: t, size: 36),
                    const SizedBox(width: IaSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: IaType.list,
                                  color:
                                      active ? p.accent : IaColors.textHi)),
                          const SizedBox(height: 2),
                          Text(t.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: IaColors.textLow)),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close,
                          size: 15, color: IaColors.textLow),
                      onPressed: () => ref
                          .read(playbackProvider.notifier)
                          .removeFromQueue(i),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
