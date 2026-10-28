/// 「随机」轮盘页（DEC-006 D6-7 语义保留，Harmonoid 视觉重绘）：
/// 卡片轮盘层叠、仅上滑切歌（手动/播完自动）、垃圾桶移出随机池。
library;

import 'dart:async';

import 'package:flutter/material.dart';


import 'package:ia_music/data/daos.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/playlists/playlist_service.dart';
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class ShufflePage extends StatefulWidget {
  const ShufflePage({
    super.key,
    required this.service,
    required this.data,
    this.covers,
  });

  final PlaybackService service;
  final DataAccess data;
  final CoverChain? covers;

  @override
  State<ShufflePage> createState() => _ShufflePageState();
}

class _ShufflePageState extends State<ShufflePage> {
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshFav());
  }

  Future<void> _refreshFav() async {
    final cur = widget.service.snapshot.currentTrack;
    if (cur == null) return;
    final fav = await PlaylistService(widget.data).isFavorite(cur.id);
    if (mounted) setState(() => _fav = fav);
  }

  Future<void> _next() => widget.service.next();

  Future<void> _dislike() => widget.service.dislikeThenNext();

  Future<void> _toggleHeart() async {
    final cur = widget.service.snapshot.currentTrack;
    if (cur == null) return;
    await PlaylistService(widget.data).toggleFavorite(
      cur.id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _refreshFav();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return Scaffold(
      key: const ValueKey('shuffle_page'),
      backgroundColor: p.canvas,
      body: SafeArea(
        child: StreamBuilder<PlaybackSnapshot>(
          initialData: widget.service.snapshot,
          stream: widget.service.status,
          builder: (context, snap) {
            final s = snap.data;
            final cur = s?.currentTrack;
            if (s == null || cur == null) {
              return const Center(child: Text('随机会话未开始'));
            }
            if (s.currentTrack?.id != null) unawaited(_refreshFav());
            final duration = cur.durationMs > 0 ? cur.durationMs : 1;
            final pos = s.positionMs.clamp(0, duration);
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    key: const ValueKey('shuffle_back'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(IaIcon.back),
                  ),
                ),
                Expanded(
                  // 轮盘：当前曲大卡 + 下一曲预览卡；整盘上滑=切歌。
                  child: GestureDetector(
                    key: const ValueKey('shuffle_wheel'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < -180) {
                        unawaited(_next()); // 仅上滑
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (s.queue.length > 1)
                            Padding(
                              key: const ValueKey('shuffle_next_card'),
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Opacity(
                                opacity: 0.45,
                                child: _WheelCard(
                                  title: _nextTitle(s),
                                  data: widget.data,
                                  covers: widget.covers,
                                  trackId: _nextId(s) ?? cur.id,
                                ),
                              ),
                            ),
                          _WheelCard(
                            title: cur.title,
                            data: widget.data,
                            covers: widget.covers,
                            trackId: cur.id,
                            hero: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                  child: Column(
                    children: [
                      Text(
                        '随机',
                        key: const ValueKey('shuffle_label'),
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cur.title,
                        key: const ValueKey('shuffle_title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        cur.artistDisplay.isEmpty ? '未知歌手' : cur.artistDisplay,
                        style:
                            TextStyle(fontSize: 13, color: p.secondaryText),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${iaMmss(pos)} / ${iaMmss(duration)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: p.secondaryText,
                          fontFeatures: kIaNumericFeatures,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            key: const ValueKey('shuffle_dislike'),
                            tooltip: '移出随机池（少播）',
                            onPressed: () => unawaited(_dislike()),
                            icon: Icon(IaIcon.delete,
                                size: 24, color: p.secondaryText),
                          ),
                          const SizedBox(width: 22),
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: FilledButton(
                              key: const ValueKey('shuffle_toggle'),
                              style: FilledButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => unawaited(
                                  s.playing ? widget.service.pause() : widget.service.play()),
                              child: Icon(
                                s.playing ? IaIcon.pause : IaIcon.play,
                                size: 32,
                                fill: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 22),
                          IconButton(
                            key: const ValueKey('shuffle_heart'),
                            tooltip: _fav ? '取消红心' : '红心',
                            onPressed: () => unawaited(_toggleHeart()),
                            icon: Icon(
                              IaIcon.heart,
                              fill: _fav ? 1.0 : 0.0,
                              size: 24,
                              color: _fav ? p.heart : p.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '上滑切歌 · 单轮内不重复',
                        style: TextStyle(fontSize: 11, color: p.secondaryText),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _nextTitle(PlaybackSnapshot s) {
    final i = s.currentIndex + 1;
    if (i >= 0 && i < s.queue.length) return s.queue[i].title;
    return '…';
  }

  int? _nextId(PlaybackSnapshot s) {
    final i = s.currentIndex + 1;
    if (i >= 0 && i < s.queue.length) return s.queue[i].id;
    return null;
  }
}

final class _WheelCard extends StatelessWidget {
  const _WheelCard({
    required this.title,
    required this.data,
    required this.trackId,
    this.covers,
    this.hero = false,
  });

  final String title;
  final DataAccess data;
  final CoverChain? covers;
  final int trackId;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(IaRadius.cover),
        child: Hero(
          tag: 'wheel_$trackId',
          child: CoverArt(
            trackId: trackId,
            title: title,
            data: data,
            chain: covers,
            size: double.infinity,
          ),
        ),
      ),
    );
  }
}
