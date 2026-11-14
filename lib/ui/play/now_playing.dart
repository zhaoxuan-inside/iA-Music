/// 沉浸播放页：pivot（播放|歌词|队列）+ 整页横滑切歌 + 歌词沉浸 + 队列编辑。
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playback.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/media_providers.dart';
import '../../state/playlist_providers.dart';
import '../../state/playback_controller.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

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

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(playbackProvider);
    final p = Theme.of(context).extension<IaPalette>()!;
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

    final panes = ['播放', '歌词', '队列'];

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // pivot 头部（点击/横滑切换；播放屏上横滑=切歌）
            Padding(
              padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 0),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  for (var i = 0; i < panes.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _pane = i),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: IaSpacing.m),
                        child: Text(panes[i],
                            style: TextStyle(
                                fontSize: _pane == i
                                    ? IaType.pivotCur
                                    : IaType.pivotIdle,
                                fontWeight: _pane == i
                                    ? IaType.light
                                    : IaType.regular,
                                color: _pane == i
                                    ? IaColors.textHi
                                    : IaColors.textMid)),
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.s),
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
                  // 播放屏：横滑切歌；其它屏：横滑换屏
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
                  duration: const Duration(milliseconds: 220),
                  child: switch (_pane) {
                    1 => const _LyricsPane(key: ValueKey('lyr')),
                    2 => const _QueuePane(key: ValueKey('q')),
                    _ => _PlayPane(key: const ValueKey('play'), snap: snap, cur: cur, p: p, edge: edge, dragValue: _dragValue, onSeek: (v) => setState(() => _dragValue = v), onSeekEnd: (v) { ref.read(playbackProvider.notifier).seekTo((v * (snap.durationMs)).round()); setState(() => _dragValue = null); }),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ── 播放屏 ───────────────────────────────────────────────────────── */

class _PlayPane extends ConsumerWidget {
  const _PlayPane({
    required this.snap,
    required this.cur,
    required this.p,
    required this.edge,
    required this.dragValue,
    required this.onSeek,
    required this.onSeekEnd,
    super.key,
  });

  final PlaybackSnapshot snap;
  final Track cur;
  final IaPalette p;
  final EdgeInsets edge;
  final double? dragValue;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSeekEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favoriteProvider(cur.id)).value ?? false;
    final pos = (dragValue ?? (snap.durationMs > 0 ? snap.positionMs / snap.durationMs : 0.0))
        .clamp(0.0, 1.0);

    return ListView(
      padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.xl, edge.right, IaSpacing.xl),
      children: [
        Center(
          child: SizedBox(
            width: IaSpacing.coverNp,
            height: IaSpacing.coverNp,
            child: CoverArt(track: cur, size: IaSpacing.coverNp),
          ),
        ),
        const SizedBox(height: IaSpacing.xl),
        Center(
          child: Text(cur.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: IaType.light,
                  color: IaColors.textHi)),
        ),
        const SizedBox(height: IaSpacing.s),
        Center(
          child: Text(cur.artistDisplay,
              style: const TextStyle(fontSize: 13, color: IaColors.textMid)),
        ),
        const SizedBox(height: IaSpacing.xl),
        Row(
          children: [
            Text(_fmt(snap.positionMs),
                style: const TextStyle(fontSize: 11.5, color: IaColors.textLow)),
            Expanded(
              child: Slider(
                value: pos,
                onChanged: snap.durationMs > 0 ? onSeek : null,
                onChangeEnd: snap.durationMs > 0 ? onSeekEnd : null,
              ),
            ),
            Text(_fmt(snap.durationMs),
                style: const TextStyle(fontSize: 11.5, color: IaColors.textLow)),
          ],
        ),
        const SizedBox(height: IaSpacing.l),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
                onPressed: () async {
                  final next =
                      snap.repeat == RepeatMode.off ? RepeatMode.all : snap.repeat == RepeatMode.all ? RepeatMode.one : RepeatMode.off;
                  await ref.read(playbackProvider.notifier).setRepeatMode(next);
                },
                icon: Icon(Icons.repeat,
                    size: 22,
                    color: snap.repeat != RepeatMode.off ? p.accent : p.textMid)),
            IconButton(
                onPressed: () => ref.read(playbackProvider.notifier).previous(),
                icon: const Icon(Icons.skip_previous,
                    size: 32, color: IaColors.textHi)),
            InkWell(
              onTap: () => ref.read(playbackProvider.notifier).togglePlay(),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: p.accent)),
                child: Icon(
                  snap.playing ? Icons.pause : Icons.play_arrow,
                  size: 30,
                  color: IaColors.textHi,
                ),
              ),
            ),
            IconButton(
                onPressed: () => ref.read(playbackProvider.notifier).next(),
                icon: const Icon(Icons.skip_next, size: 32, color: IaColors.textHi)),
            IconButton(
                onPressed: () async {
                  final favNow = !(ref.watch(favoriteProvider(cur.id)).value ?? false);
                  await ref.read(dbActionsProvider).setFavorite(cur.id, favNow);
                },
                icon: Icon(
                    (ref.watch(favoriteProvider(cur.id)).value ?? false)
                        ? Icons.favorite
                        : Icons.favorite_outline,
                    color: (ref.watch(favoriteProvider(cur.id)).value ?? false)
                        ? p.accent
                        : p.textMid)),
          ],
        ),
        const SizedBox(height: IaSpacing.l),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => ref.read(playbackProvider.notifier).setSleepTimer(30),
              child: const Text('睡眠 30′',
                  style: TextStyle(fontSize: 12, color: IaColors.textMid)),
            ),
            if (snap.sleepEndsAt != null)
              Text(
                  '至 ${snap.sleepEndsAt!.hour}:${snap.sleepEndsAt!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 12, color: IaColors.textLow)),
            const SizedBox(width: IaSpacing.m),
            TextButton(
              onPressed: () => ref.read(playbackProvider.notifier).cancelSleepTimer(),
              child: const Text('取消',
                  style: TextStyle(fontSize: 12, color: IaColors.textLow)),
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
    if (cur == null) {
      return const SizedBox.shrink();
    }
    final result = ref.watch(trackLyricsProvider(cur.id)).value;
    final doc = result?.doc;

    if (doc == null || doc.isEmpty) {
      return Center(
        child: Text('这首歌还没有歌词',
            style: TextStyle(
                fontSize: IaType.menu,
                fontWeight: IaType.light,
                color: IaColors.textLow)),
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
        const extent = 44.0;
        final target = (line * extent - _scroll.position.viewportDimension / 3)
            .clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.animateTo(target,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic);
      });
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.xl, vertical: IaSpacing.xl),
      itemCount: doc.lines.length,
      itemExtent: 44,
      itemBuilder: (_, i) {
        final active = i == line;
        return InkWell(
          onTap: () => ref
              .read(playbackProvider.notifier)
              .seekTo(doc.lines[i].tMs + offset),
          child: Container(
            alignment: Alignment.centerLeft,
            child: Text(
              doc.lines[i].text.isEmpty ? '· · ·' : doc.lines[i].text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: active ? IaType.lyricCur : IaType.list,
                fontWeight: active ? IaType.light : IaType.regular,
                color: active ? p.accent : IaColors.lyricIdle,
              ),
            ),
          ),
        );
      },
    );
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

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 40),
      itemCount: snap.queue.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Row(
            children: [
              Text('当前队列 · ${snap.queue.length} 首',
                  style: const TextStyle(fontSize: 12.5, color: IaColors.textMid)),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(playbackProvider.notifier).clearQueue(),
                child: const Text('清空',
                    style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
              ),
            ],
          );
        }
        final idx = i - 1;
        final t = snap.queue[idx];
        final active = idx == snap.index;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => ref
                .read(playbackProvider.notifier)
                .playTracks(snap.queue, startIndex: idx),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: IaSpacing.m, vertical: IaSpacing.m),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline))),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(active ? '♪' : '${idx + 1}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            color: active ? p.accent : IaColors.textLow)),
                  ),
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
                                color: active ? p.accent : IaColors.textHi)),
                        Text(t.artistDisplay,
                            style: const TextStyle(
                                fontSize: 11, color: IaColors.textLow)),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, size: 16, color: IaColors.textLow),
                    onPressed: () =>
                        ref.read(playbackProvider.notifier).removeFromQueue(idx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
