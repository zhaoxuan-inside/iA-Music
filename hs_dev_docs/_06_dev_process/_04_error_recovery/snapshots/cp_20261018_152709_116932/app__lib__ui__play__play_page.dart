/// 沉浸播放页（S4 · DEC-004「第一参照页=胶片式」；REQ-PLAY-01/03/06/07/04）。
///
/// 视觉锚（playback_prd §3.1 随机会话条款 / main_prototype #p-film）：
/// * 外框 `#0D0F11` r18 + 画面 r10 的**胶片帧**；框底**打孔带**（≤ 真实锚）。
/// * 封面素材来源=CoverChain（S5）；**本片终态=色块占位**（DoD1 明示）。
/// * 标题左对齐 + 心动于右、歌手行（⋯ 展开队列）、进度条白色圆点。
/// * 三键（上一首/播放暂停/下一首）+ 垃圾桶（REQ-PLAY-04 页级锚）。
///
/// 纪律：本页只经 [PlaybackService]/[PlaylistService]/DAO 门面取数（禁直读他域表）；
/// 每帧 Future 重读快照（IMPL-S2 §4-L3 跨 zone 不成帧）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/playlists/playlist_service.dart';
import 'package:ia_music/ui/play/eq_page.dart';
import 'package:ia_music/ui/play/playback_dock.dart';
import 'package:ia_music/ui/play/queue_page.dart';

/// 胶片帧外框色（playback_prd §3.1 / DEC-006 轮 16 终稿）。
const kFilmFrameColor = Color(0xFF0D0F11);

/// 封面缺失时的占位色块（S5 前终态；非「坏图」语义）。
const kCoverPlaceholderColor = Color(0xFF2A3138);

final class PlayPage extends StatefulWidget {
  const PlayPage({super.key, required this.service, required this.data});

  final PlaybackService service;
  final DataAccess data;

  @override
  State<PlayPage> createState() => PlayPageState();
}

class PlayPageState extends State<PlayPage> {
  PlaylistService get _playlists => PlaylistService(widget.data);

  bool _fav = false;
  int _favCount = 0;
  bool _favInflight = false;
  final Map<int, String> _albumMemo = {};

  static const _modeIcons = {
    PlaybackMode.loops: Icons.repeat,
    PlaybackMode.single: Icons.repeat_one,
    PlaybackMode.sequence: Icons.playlist_play,
    PlaybackMode.random: Icons.shuffle,
  };
  static const _modeLabels = {
    PlaybackMode.loops: '列表循环',
    PlaybackMode.single: '单曲循环',
    PlaybackMode.sequence: '顺序播放',
    PlaybackMode.random: '随机播放',
  };

  /// 红心状态刷新（真库读；每帧面调用——幂等廉价，带并发守卫）。
  Future<void> refreshFav() async {
    if (_favInflight) {
      return;
    }
    _favInflight = true;
    try {
      final cur = widget.service.snapshot.currentTrack;
      if (cur == null) {
        return;
      }
      final fav = await _playlists.isFavorite(cur.id);
      final cnt = await _playlists.favoriteCount();
      if (mounted) {
        setState(() {
          _fav = fav;
          _favCount = cnt;
        });
      }
    } finally {
      _favInflight = false;
    }
  }

  /// 红心切换（REQ-PL-01：图标即时变红 + 系统歌单计数同步）；true=已加入。
  Future<bool> toggleHeart() async {
    final cur = widget.service.snapshot.currentTrack;
    if (cur == null) {
      return false;
    }
    final added = await _playlists.toggleFavorite(
      cur.id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (mounted) {
      setState(() {
        _fav = added;
      });
      // 系统歌单计数同步面（页内 chip；我的页卡另读同库计数）
      final cnt = await _playlists.favoriteCount();
      if (mounted) {
        setState(() => _favCount = cnt);
      }
    }
    return added;
  }

  Future<void> refreshFavCount() async {
    // 计数已随 refreshFav 同读（单缝）；保留方法面供壳层外显式刷新。
    await refreshFav();
  }

  Future<void> dislike() => widget.service.dislikeThenNext();
  Future<void> nextTrack() => widget.service.next();
  Future<void> prevTrack() => widget.service.previous();
  Future<void> togglePlay() async {
    final s = widget.service.snapshot;
    if (s.playing) {
      await widget.service.pause();
    } else {
      await widget.service.play();
    }
  }

  /// 模式循环：列表循环 → 单曲 → 顺序 → 随机 → 列表循环（REQ-PLAY-03）。
  void cycleMode() {
    const order = [
      PlaybackMode.loops,
      PlaybackMode.single,
      PlaybackMode.sequence,
      PlaybackMode.random,
    ];
    final cur = widget.service.mode;
    final next = order[(order.indexOf(cur) + 1) % order.length];
    widget.service.setMode(next);
    setState(() {});
  }

  Future<void> openQueue() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QueuePage(service: widget.service, data: widget.data),
      ),
    );
  }

  Future<void> openEq() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EqPage(service: widget.service)),
    );
  }

  Future<void> seekToEnd(int ms) => widget.service.seekTo(ms);

  /// 专辑名（TrackLite 无专辑位；经 DAO 门面单行读并缓存）。
  Future<String> _albumOf(int id) async {
    final memo = _albumMemo[id];
    if (memo != null) {
      return memo;
    }
    final row = await widget.data.library.rowById(id);
    final album = row?.albumDisplay ?? '';
    _albumMemo[id] = album;
    return album;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlaybackSnapshot>(
      future: (() async => widget.service.snapshot)(),
      builder: (context, snap) {
        final s = snap.data;
        final cur = s?.currentTrack;
        if (s == null || cur == null) {
          return Scaffold(
            key: const ValueKey('play_page'),
            appBar: AppBar(title: const Text('播放')),
            body: const Center(child: Text('暂无播放内容')),
          );
        }
        unawaited(refreshFav());
        final duration = cur.durationMs > 0 ? cur.durationMs : 1;
        final pos = s.positionMs.clamp(0, duration);
        return Scaffold(
          key: const ValueKey('play_page'),
          backgroundColor: const Color(0xFF101418),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text(_modeLabels[s.mode]!),
            actions: [
              IconButton(
                key: const ValueKey('play_eq_entry'),
                tooltip: '音效（均衡器）',
                onPressed: () => unawaited(openEq()),
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                key: const ValueKey('play_queue_entry'),
                tooltip: '播放队列',
                onPressed: () => unawaited(openQueue()),
                icon: const Icon(Icons.queue_music),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 出错/跳过提示态（服务提示面：缺失/损坏/异常原话；REQ-PLAY-08 页内可见）
              PlaybackNoticeBar(service: widget.service),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _filmFrame(cur.id),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cur.title,
                                    key: const ValueKey('play_title'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cur.artistDisplay.isEmpty
                                        ? '未知歌手'
                                        : cur.artistDisplay,
                                    key: const ValueKey('play_artist'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  FutureBuilder<String>(
                                    future: _albumOf(cur.id),
                                    builder: (context, a) => Text(
                                      a.data ?? '',
                                      key: const ValueKey('play_album'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('play_heart'),
                              tooltip: _fav ? '取消红心' : '红心（加入「我喜欢的音乐」）',
                              onPressed: () => unawaited(toggleHeart()),
                              icon: Icon(
                                _fav ? Icons.favorite : Icons.favorite_border,
                                color: _fav
                                    ? const Color(0xFFE53935)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 进度条（白色圆点；拖动松手=seek）
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            key: const ValueKey('play_progress'),
                            value: pos.toDouble(),
                            max: duration.toDouble(),
                            onChanged: (_) {},
                            onChangeEnd: (v) => unawaited(seekToEnd(v.round())),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _mmss(pos),
                              style: const TextStyle(color: Colors.white54),
                            ),
                            Text(
                              _mmss(duration),
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 三键（REQ-PLAY-01）+ 垃圾桶（REQ-PLAY-04）
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            key: const ValueKey('play_dislike'),
                            tooltip: '垃圾桶（减少推荐）',
                            iconSize: 26,
                            onPressed: () => unawaited(dislike()),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const ValueKey('play_prev'),
                            tooltip: '上一首',
                            iconSize: 34,
                            onPressed: () => unawaited(prevTrack()),
                            icon: const Icon(
                              Icons.skip_previous,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            key: const ValueKey('play_toggle'),
                            tooltip: s.playing ? '暂停' : '播放',
                            iconSize: 38,
                            onPressed: () => unawaited(togglePlay()),
                            icon: Icon(
                              s.playing ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const ValueKey('play_next'),
                            tooltip: '下一首',
                            iconSize: 34,
                            onPressed: () => unawaited(nextTrack()),
                            icon: const Icon(
                              Icons.skip_next,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          key: const ValueKey('play_mode'),
                          onPressed: cycleMode,
                          icon: Icon(
                            _modeIcons[widget.service.mode],
                            size: 18,
                            color: Colors.white70,
                          ),
                          label: Text(
                            _modeLabels[widget.service.mode]!,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '我喜欢的音乐 · $_favCount',
                          key: const ValueKey('play_fav_count'),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 胶片帧：外框 `#0D0F11` r18 + 画面 r10 + 框底打孔带（DEC-006 终稿锚）。
  Widget _filmFrame(int trackId) {
    return Container(
      key: const ValueKey('film_frame'),
      decoration: BoxDecoration(
        color: kFilmFrameColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232A30)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              key: ValueKey('film_cover_$trackId'),
              decoration: BoxDecoration(
                // S5 前：封面缺失→色块为终态占位（DoD1 明示）
                color: kCoverPlaceholderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.album, size: 56, color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 打孔带（下缘）：两排小孔=胶片观感
          SizedBox(
            key: const ValueKey('film_perforation'),
            height: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 14; i++)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A444C),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _mmss(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
