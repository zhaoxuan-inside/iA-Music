/// 沉浸播放页（Harmonoid 形态 · DEC-012：近满屏大封面 + 五键控制排 + 工具排）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:contracts/contracts.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/playlists/playlist_service.dart';
import 'package:ia_music/ui/play/eq_page.dart';
import 'package:ia_music/ui/play/lyrics_page.dart';
import 'package:ia_music/ui/play/playback_notice.dart';
import 'package:ia_music/ui/play/queue_page.dart';
import 'package:ia_music/ui/play/shuffle_page.dart';
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({
    super.key,
    required this.service,
    required this.data,
    this.covers,
  });

  final PlaybackService service;
  final DataAccess data;
  final CoverChain? covers;

  @override
  State<NowPlayingPage> createState() => NowPlayingPageState();
}

class NowPlayingPageState extends State<NowPlayingPage> {
  PlaylistService get _playlists => PlaylistService(widget.data);

  bool _fav = false;
  int? _favForTrack;
  bool _favInflight = false;

  static const _modeLabels = {
    PlaybackMode.loops: '列表循环',
    PlaybackMode.single: '单曲循环',
    PlaybackMode.sequence: '顺序播放',
    PlaybackMode.random: '随机播放',
  };

  Future<void> refreshFav() async {
    if (_favInflight) return;
    _favInflight = true;
    try {
      while (true) {
        final cur = widget.service.snapshot.currentTrack;
        if (cur == null) return;
        final wanted = cur.id;
        final fav = await _playlists.isFavorite(wanted);
        if (!mounted) return;
        setState(() {
          _favForTrack = wanted;
          _fav = fav;
        });
        final now = widget.service.snapshot.currentTrack;
        if (now == null || now.id == wanted) return;
      }
    } finally {
      _favInflight = false;
    }
  }

  Future<bool> toggleHeart() async {
    final cur = widget.service.snapshot.currentTrack;
    if (cur == null) return false;
    final added = await _playlists.toggleFavorite(
      cur.id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (mounted) setState(() => _fav = added);
    return added;
  }

  Future<void> dislike() => widget.service.dislikeThenNext();
  Future<void> togglePlay() async {
    final s = widget.service.snapshot;
    if (s.playing) {
      await widget.service.pause();
    } else {
      await widget.service.play();
    }
  }

  /// 五键左：随机 ⇄ 顺序。
  Future<void> toggleShuffle() async {
    final cur = widget.service.mode;
    widget.service.setMode(cur == PlaybackMode.random
        ? PlaybackMode.sequence
        : PlaybackMode.random);
  }

  /// 五键右：循环族切换（列表 → 单曲 → 顺序）。
  Future<void> cycleRepeat() async {
    final cur = widget.service.mode;
    widget.service.setMode(switch (cur) {
      PlaybackMode.loops => PlaybackMode.single,
      PlaybackMode.single => PlaybackMode.sequence,
      _ => PlaybackMode.loops,
    });
  }

  Future<void> openLyrics() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LyricsPage(
        service: widget.service,
        data: widget.data,
        covers: widget.covers,
      ),
    ));
    unawaited(refreshFav());
  }

  Future<void> openQueue() async {
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => QueuePage(service: widget.service)));
  }

  Future<void> openEq() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => EqPage(service: widget.service)));
  }

  Future<void> openWheel() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ShufflePage(
        service: widget.service,
        data: widget.data,
        covers: widget.covers,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackSnapshot>(
      initialData: widget.service.snapshot,
      stream: widget.service.status,
      builder: (context, snap) {
        final s = snap.data;
        final cur = s?.currentTrack;
        if (s == null || cur == null) {
          return Scaffold(
            key: const ValueKey('now_playing'),
            appBar: AppBar(title: const Text('播放')),
            body: const Center(child: Text('暂无播放内容')),
          );
        }
        if (_favForTrack != cur.id) unawaited(refreshFav());
        final duration = cur.durationMs > 0 ? cur.durationMs : 1;
        final pos = s.positionMs.clamp(0, duration);
        return Scaffold(
          key: const ValueKey('now_playing'),
          appBar: AppBar(
            title: Text(
              _modeLabels[s.mode]!,
              key: const ValueKey('play_mode'),
            ),
            actions: [
              if (s.mode == PlaybackMode.random)
                IconButton(
                  key: const ValueKey('play_wheel_entry'),
                  tooltip: '随机轮盘',
                  onPressed: () => unawaited(openWheel()),
                  icon: Icon(IaIcon.shuffle),
                ),
              IconButton(
                key: const ValueKey('play_eq_entry'),
                tooltip: '音效',
                onPressed: () => unawaited(openEq()),
                icon: Icon(IaIcon.tune),
              ),
              IconButton(
                key: const ValueKey('play_queue_entry'),
                tooltip: '播放队列',
                onPressed: () => unawaited(openQueue()),
                icon: Icon(IaIcon.playlist),
              ),
            ],
          ),
          body: LayoutBuilder(builder: (context, cons) {
            final wide = cons.maxWidth >= 720;
            final cover = ClipRRect(
              borderRadius: BorderRadius.circular(IaRadius.cover),
              child: Builder(builder: (context) {
                final side = wide
                    ? 360.0
                    : (cons.maxWidth - 48).clamp(0.0, 520.0).toDouble();
                return SizedBox(
                  width: side,
                  height: side,
                  child: CoverArt(
                    trackId: cur.id,
                    title: cur.title,
                    data: widget.data,
                    chain: widget.covers,
                    size: side,
                  ),
                );
              }),
            );
            final controls = _Controls(
              service: widget.service,
              playing: s.playing,
              mode: s.mode,
              pos: pos,
              duration: duration,
              fav: _fav,
              onDislike: () => unawaited(dislike()),
              onTogglePlay: () => unawaited(togglePlay()),
              onShuffle: () => unawaited(toggleShuffle()),
              onRepeat: () => unawaited(cycleRepeat()),
              onHeart: () => unawaited(toggleHeart()),
              onLyrics: () => unawaited(openLyrics()),
              onQueue: () => unawaited(openQueue()),
            );
            return Column(
              children: [
                PlaybackNoticeBar(service: widget.service),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: cover,
                            ),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  child: _Details(
                                    service: widget.service,
                                    data: widget.data,
                                    cur: cur,
                                    controls: controls,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                cover,
                                const SizedBox(height: 20),
                                _Details(
                                  service: widget.service,
                                  data: widget.data,
                                  cur: cur,
                                  controls: controls,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

/// 标题/歌手/专辑信息列。
final class _Details extends StatelessWidget {
  _Details({
    required this.service,
    required this.data,
    required this.cur,
    required this.controls,
  });

  final PlaybackService service;
  final DataAccess data;
  final TrackLite cur;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return Column(
      key: const ValueKey('play_details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cur.title,
          key: const ValueKey('play_title'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          cur.artistDisplay.isEmpty ? '未知歌手' : cur.artistDisplay,
          key: const ValueKey('play_artist'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, color: p.secondaryText),
        ),
        FutureBuilder<String>(
          future: _albumOf(cur.id),
          builder: (context, a) => a.data == null || a.data!.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  a.data!,
                  key: const ValueKey('play_album'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.secondaryText),
                ),
        ),
        const SizedBox(height: 20),
        controls,
        const SizedBox(height: 8),
      ],
    );
  }

  final Map<int, String> _albumMemo = {};

  Future<String> _albumOf(int id) async {
    final memo = _albumMemo[id];
    if (memo != null) return memo;
    final row = await data.library.rowById(id);
    final album = row?.albumDisplay ?? '';
    _albumMemo[id] = album;
    return album;
  }
}

/// 五键控制排 + 进度 + 工具排（Harmonoid 签名形态）。
final class _Controls extends StatelessWidget {
  const _Controls({
    required this.service,
    required this.playing,
    required this.mode,
    required this.pos,
    required this.duration,
    required this.fav,
    required this.onDislike,
    required this.onTogglePlay,
    required this.onShuffle,
    required this.onRepeat,
    required this.onHeart,
    required this.onLyrics,
    required this.onQueue,
  });

  final PlaybackService service;
  final bool playing;
  final PlaybackMode mode;
  final int pos;
  final int duration;
  final bool fav;
  final VoidCallback onDislike;
  final VoidCallback onTogglePlay;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback onHeart;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 五键排：随机 | 上一首 | 大圆播放 | 下一首 | 循环
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('play_shuffle_key'),
                  tooltip: mode == PlaybackMode.random ? '随机中（点按改顺序）' : '随机播放',
                  onPressed: onShuffle,
                  icon: Icon(
                    IaIcon.shuffle,
                    size: 24,
                    color: mode == PlaybackMode.random ? p.accent : p.secondaryText,
                  ),
                ),
                const SizedBox(width: 14),
                IconButton(
                  key: const ValueKey('play_prev'),
                  tooltip: '上一首',
                  iconSize: 30,
                  constraints:
                      const BoxConstraints(minWidth: 52, minHeight: 52),
                  onPressed: () => unawaited(service.previous()),
                  icon: Icon(IaIcon.previous, color: p.mainText),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 68,
                  height: 68,
                  child: FilledButton(
                    key: const ValueKey('play_toggle'),
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: onTogglePlay,
                    child: Icon(
                      playing ? IaIcon.pause : IaIcon.play,
                      size: 34,
                      fill: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  key: const ValueKey('play_next'),
                  tooltip: '下一首',
                  iconSize: 30,
                  constraints:
                      const BoxConstraints(minWidth: 52, minHeight: 52),
                  onPressed: () => unawaited(service.next()),
                  icon: Icon(IaIcon.next, color: p.mainText),
                ),
                const SizedBox(width: 14),
                IconButton(
                  key: const ValueKey('play_repeat_key'),
                  tooltip: switch (mode) {
                    PlaybackMode.loops => '列表循环',
                    PlaybackMode.single => '单曲循环',
                    _ => '顺序播放',
                  },
                  onPressed: onRepeat,
                  icon: Icon(
                    mode == PlaybackMode.single ? IaIcon.repeatOne : IaIcon.repeat,
                    size: 24,
                    color: (mode == PlaybackMode.loops || mode == PlaybackMode.single)
                        ? p.accent
                        : p.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 进度 + 双侧时间
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      key: const ValueKey('play_progress'),
                      value: pos.toDouble(),
                      max: duration.toDouble(),
                      onChanged: (_) {},
                      onChangeEnd: (v) => unawaited(service.seekTo(v.round())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          iaMmss(pos),
                          style: TextStyle(
                            fontSize: 11,
                            color: p.secondaryText,
                            fontFeatures: kIaNumericFeatures,
                          ),
                        ),
                        Text(
                          iaMmss(duration),
                          style: TextStyle(
                            fontSize: 11,
                            color: p.secondaryText,
                            fontFeatures: kIaNumericFeatures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 工具排：垃圾桶 | 歌词 | 红心
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('play_dislike'),
                  tooltip: '垃圾桶（减少推荐）',
                  onPressed: onDislike,
                  icon: Icon(IaIcon.delete, size: 22, color: p.secondaryText),
                ),
                IconButton(
                  key: const ValueKey('play_lyrics_entry'),
                  tooltip: '歌词',
                  onPressed: onLyrics,
                  icon: Icon(IaIcon.lyrics, size: 24, color: p.secondaryText),
                ),
                IconButton(
                  key: const ValueKey('play_heart'),
                  tooltip: fav ? '取消红心' : '红心（加入「我喜欢的音乐」）',
                  onPressed: onHeart,
                  icon: Icon(
                    fav ? IaIcon.heart : IaIcon.heart,
                    fill: fav ? 1.0 : 0.0,
                    size: 24,
                    color: fav ? p.heart : p.secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
