/// 队列屏：拖拽重排 + 跳播 + 移除 + 清空。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../state/playback_controller.dart';
import '../../components/mapped/cover.dart';
import '../../layout/hub_scaffold.dart';

/// 队列屏（pivot 第 2 屏）。
class NpQueuePane extends ConsumerWidget {
  const NpQueuePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    // select：进度心跳不动队列与索引——只有队列编辑/切歌才重建整屏列表。
    final (queue, index) = ref
        .watch(playbackProvider.select((s) => (s.queue, s.index)));
    final edge = edgeInsets(context);

    if (queue.isEmpty) {
      return Center(
        child: Text(
          '队列为空',
          style: TextStyle(
            fontSize: IaType.menu,
            fontWeight: IaType.light,
            color: IaColors.textLow,
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      // 长按整行拖拽重排；tap（跳播）与 close（移除）不受影响。
      buildDefaultDragHandles: false,
      header: Padding(
        padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 0),
        child: Row(
          children: [
            Text(
              '队列 · ${queue.length} 首',
              style: TextStyle(fontSize: 14, color: IaColors.textMid),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(playbackProvider.notifier).clearQueue(),
              child: Text(
                '清空',
                style: TextStyle(fontSize: 14, color: IaColors.textLow),
              ),
            ),
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.s, edge.right, 40),
      itemCount: queue.length,
      onReorderItem: (oldIndex, newIndex) =>
          ref.read(playbackProvider.notifier).reorderQueue(oldIndex, newIndex),
      proxyDecorator: (child, _, anim) => Material(
        color: Colors.black,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: p.accent, width: 2)),
          ),
          child: child,
        ),
      ),
      itemBuilder: (_, i) {
        final t = queue[i];
        final active = i == index;
        return ReorderableDelayedDragStartListener(
          key: ValueKey('q-$i-${t.id}'),
          index: i,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref
                  .read(playbackProvider.notifier)
                  .playTrack(queue[i], queue: queue),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.s,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        active ? '♪' : '${i + 1}'.padLeft(2, '0'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: active ? p.accent : IaColors.textLow,
                        ),
                      ),
                    ),
                    const SizedBox(width: IaSpacing.m),
                    CoverArt(track: t, size: 36),
                    const SizedBox(width: IaSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: IaType.list,
                              color: active ? p.accent : IaColors.textHi,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: IaColors.textLow,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close,
                        size: 15,
                        color: IaColors.textLow,
                      ),
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
