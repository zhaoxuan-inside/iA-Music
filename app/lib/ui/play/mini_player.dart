/// 迷你播放器双形态（Harmonoid · DEC-012 D12-3）：
/// * [SidebarMiniPlayer] 桌面=侧栏底部通栏（封面 48 + 信息 + 三键 + 进度线）。
/// * [CapsuleMiniPlayer] 移动=悬浮胶囊（封面 44 + 歌名–歌手 + 播放/下一首）。
library;

import 'dart:async';

import 'package:contracts/contracts.dart';
import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// 可见面（同曲同播放态=同帧；过滤位置 tick）。
(bool, TrackLite?) _face(PlaybackSnapshot s) => (s.playing, s.currentTrack);

Widget _title(TextStyle main, TextStyle sub, TrackLite cur, String shuffling) =>
    Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cur.title,
          key: const ValueKey('mini_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: main,
        ),
        Text(
          cur.artistDisplay.isEmpty ? shuffling : cur.artistDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: sub,
        ),
      ],
    );

class _PlayToggle extends StatelessWidget {
  const _PlayToggle({required this.service, required this.playing, this.size = 34});

  final PlaybackService service;
  final bool playing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return IconButton(
      key: const ValueKey('mini_play'),
      tooltip: playing ? t.pauseTooltip : t.playTooltip,
      onPressed: () => unawaited(playing ? service.pause() : service.play()),
      icon: Icon(
        playing ? IaIcon.pause : IaIcon.play,
        size: size,
        fill: 1.0,
        color: p.mainText,
      ),
    );
  }
}

/// 桌面侧栏底部迷你播放器。
final class SidebarMiniPlayer extends StatelessWidget {
  const SidebarMiniPlayer({
    super.key,
    required this.service,
    required this.data,
    required this.covers,
    this.onOpen,
    this.onNext,
  });

  final PlaybackService service;
  final DataAccess data;
  final CoverChain covers;
  final VoidCallback? onOpen;
  final Future<void> Function()? onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return StreamBuilder<(bool, TrackLite?)>(
      initialData: _face(service.snapshot),
      stream: service.status.map(_face).distinct(),
      builder: (context, snap) {
        final cur = snap.data?.$2;
        if (cur == null) return const SizedBox.shrink();
        return Column(
          key: const ValueKey('mini_player'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: p.separator),
            InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                child: Row(
                  children: [
                    CoverArt(
                      trackId: cur.id,
                      title: cur.title,
                      data: data,
                      chain: covers,
                      size: 44,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _title(
                        TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.mainText,
                        ),
                        TextStyle(fontSize: 11, color: p.secondaryText),
                        cur,
                        t.shufflingSubtitle,
                      ),
                    ),
                    IconButton(
                      tooltip: t.previousTooltip,
                      onPressed: () => unawaited(service.previous()),
                      icon: Icon(IaIcon.previous,
                          size: 20, color: p.secondaryText),
                    ),
                    _PlayToggle(
                        service: service, playing: snap.data!.$1, size: 24),
                    IconButton(
                      key: const ValueKey('mini_next'),
                      tooltip: t.nextTooltip,
                      onPressed:
                          onNext == null ? null : () => unawaited(onNext!()),
                      icon:
                          Icon(IaIcon.next, size: 20, color: p.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
            _EdgeProgress(service: service),
          ],
        );
      },
    );
  }
}

/// 移动悬浮胶囊迷你条（Tab 栏上方）。
final class CapsuleMiniPlayer extends StatelessWidget {
  const CapsuleMiniPlayer({
    super.key,
    required this.service,
    required this.data,
    required this.covers,
    this.onOpen,
    this.onNext,
  });

  final PlaybackService service;
  final DataAccess data;
  final CoverChain covers;
  final VoidCallback? onOpen;
  final Future<void> Function()? onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return StreamBuilder<(bool, TrackLite?)>(
      initialData: _face(service.snapshot),
      stream: service.status.map(_face).distinct(),
      builder: (context, snap) {
        final cur = snap.data?.$2;
        if (cur == null) return const SizedBox.shrink();
        return Container(
          key: const ValueKey('mini_player'),
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          decoration: BoxDecoration(
            color: p.lifted,
            borderRadius: BorderRadius.circular(IaRadius.pill),
            border: Border.all(color: p.separator),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(IaRadius.pill),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Row(
                  children: [
                    CoverArt(
                      trackId: cur.id,
                      title: cur.title,
                      data: data,
                      chain: covers,
                      size: 40,
                      radius: IaRadius.pill / 2,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _title(
                        TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.mainText,
                        ),
                        TextStyle(fontSize: 11, color: p.secondaryText),
                        cur,
                        t.shufflingSubtitle,
                      ),
                    ),
                    _PlayToggle(service: service, playing: snap.data!.$1),
                    IconButton(
                      key: const ValueKey('mini_next'),
                      tooltip: t.nextTooltip,
                      onPressed:
                          onNext == null ? null : () => unawaited(onNext!()),
                      icon:
                          Icon(IaIcon.next, size: 22, color: p.mainText),
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

/// 底缘一线进度（accent；随位置流推进）。
final class _EdgeProgress extends StatelessWidget {
  const _EdgeProgress({required this.service});

  final PlaybackService service;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return StreamBuilder<PlaybackSnapshot>(
      initialData: service.snapshot,
      stream: service.status,
      builder: (context, snap) {
        final s = snap.data;
        final dur = s?.currentTrack?.durationMs ?? 0;
        final frac =
            dur > 0 ? ((s?.positionMs ?? 0) / dur).clamp(0.0, 1.0) : 0.0;
        return SizedBox(
          height: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: frac,
              child: ColoredBox(color: p.accent),
            ),
          ),
        );
      },
    );
  }
}
