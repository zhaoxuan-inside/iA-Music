/// 歌词屏：同步滚动高亮 + 点击行跳播；无词时的诚实空态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../state/media_providers.dart';
import '../../../state/playback_controller.dart';
import '../../shared/hub_scaffold.dart';

/// 歌词屏（pivot 第 1 屏）。
class NpLyricsPane extends ConsumerStatefulWidget {
  const NpLyricsPane({super.key});

  @override
  ConsumerState<NpLyricsPane> createState() => _NpLyricsPaneState();
}

class _NpLyricsPaneState extends ConsumerState<NpLyricsPane> {
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
              Text(
                '无词',
                style: TextStyle(
                  fontSize: IaType.display,
                  fontWeight: IaType.light,
                  letterSpacing: IaType.titleTracking,
                  color: IaColors.textLow,
                ),
              ),
              const SizedBox(height: IaSpacing.m),
              const Text(
                '这首歌还没有歌词 —— 之后可在设置中补全',
                style: TextStyle(fontSize: 12, color: IaColors.textLow),
              ),
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
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
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
              padding: EdgeInsets.fromLTRB(edge.left, 64, edge.right, 40),
              itemCount: doc.lines.length,
              itemExtent: 46,
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
                        fontSize: active ? IaType.pivotCur : IaType.list,
                        fontWeight: active ? IaType.light : IaType.regular,
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
      ],
    );
  }
}
