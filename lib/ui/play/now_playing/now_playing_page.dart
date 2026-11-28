/// 沉浸播放页：pivot（播放|歌词|队列）+ 三屏横滑换页 + 播放屏竖滑切歌。
///
/// Zune HD 的做法：不套一层「播放器卡片」，而是让封面、倒影、环境光
/// 直接成为页面；控制只保留细线、细字与一个 accent 圆环。
/// 三个 pane 拆在同目录（np_play_pane / np_lyrics_pane / np_queue_pane）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../state/playback_controller.dart';
import '../../layout/hub_scaffold.dart';
import 'np_lyrics_pane.dart';
import 'np_play_pane.dart';
import 'np_queue_pane.dart';

/// 打开沉浸播放页：从底部上浮 + 淡入（Zune 磁贴升起）。
Future<void> openNowPlaying(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
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
    ),
  );
}

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  int _pane = 0; // 0 播放 1 歌词 2 队列
  Offset? _panStart;
  bool _swiped = false;

  static const _panes = ['播放', '歌词', '队列'];

  @override
  Widget build(BuildContext context) {
    // select：进度心跳不进本页——切歌（current 引用变化）才重建壳层。
    final cur = ref.watch(playbackProvider.select((s) => s.current));
    final edge = edgeInsets(context);

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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NpHeader(
              pane: _pane,
              edge: edge,
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
                    // 播放屏竖滑切歌：上滑下一首，下滑上一首（退出走系统返回）。
                    if (_pane == 0 &&
                        dy.abs() > 70 &&
                        dy.abs() > dx.abs() * 1.4) {
                      _swiped = true;
                      dy < 0
                          ? ref.read(playbackProvider.notifier).next()
                          : ref.read(playbackProvider.notifier).previous();
                      return;
                    }
                    // 三屏统一：左右横滑切换 播放/歌词/队列。
                    if (dx.abs() > 72 && dx.abs() > dy.abs() * 1.5) {
                      _swiped = true;
                      setState(() {
                        _pane = (_pane + (dx < 0 ? 1 : -1)).clamp(0, 2);
                      });
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
                      1 => const NpLyricsPane(key: ValueKey('lyr')),
                      2 => const NpQueuePane(key: ValueKey('q')),
                      _ => NpPlayPane(
                        key: const ValueKey('play'),
                        cur: cur,
                        edge: edge,
                      ),
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

/* ── 页头：Zune pivot ─────────────────────────────────────────────── */

class _NpHeader extends StatelessWidget {
  const _NpHeader({
    required this.pane,
    required this.edge,
    required this.onPick,
  });

  final int pane;
  final EdgeInsets edge;
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
                        // DESIGN「Pivot 横滑」：当前项 Light 放大过渡。
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: pane == i
                                ? IaType.page
                                : IaType.pivotIdle,
                            height: 1,
                            fontWeight: pane == i
                                ? IaType.light
                                : IaType.regular,
                            color: pane == i
                                ? IaColors.textHi
                                : IaColors.textMid,
                          ),
                          child: Text(_NowPlayingPageState._panes[i]),
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
            ],
          ),
        ],
      ),
    );
  }
}
