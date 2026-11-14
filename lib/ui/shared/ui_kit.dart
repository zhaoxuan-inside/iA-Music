/// 共享 UI 组件：曲面屏边距 / 分区标签 / 大字行 / 歌曲行 / 字母轨 / WP 菜单与通知 / 空态。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';

/// 曲面屏安全边距：内容水平边距 = max(基准, 左右曲面安全区)。
/// 顶部喂状态栏（透明 edge-to-edge），底部交给各页自行处理导航条。
EdgeInsets edgeInsets(BuildContext context, {double base = IaSpacing.gutter}) {
  final mq = MediaQuery.of(context);
  return EdgeInsets.only(
    left: base > mq.padding.left ? base : mq.padding.left,
    right: base > mq.padding.right ? base : mq.padding.right,
  );
}

/// 底部手势条高度（无手势条设备为 0）。
double bottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.padding.bottom > 6 ? mq.padding.bottom : 0;
}

/// 小节标签（accent 小字 + 宽字距）。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: IaType.semibold,
        letterSpacing: 1.4,
        color: Theme.of(context).extension<IaPalette>()!.accent,
      ),
    );
  }
}

/// 大字行（细体标题 + 计数/摘要 + 箭头），分类菜单与页内跳转的标准行。
class BigRow extends StatelessWidget {
  const BigRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: IaSpacing.l),
          decoration:
              const BoxDecoration(border: Border(bottom: BorderSide(color: IaColors.hairline))),
          child: Row(
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: IaType.pivotCur,
                      fontWeight: IaType.light,
                      color: IaColors.textHi)),
              const Spacer(),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 12, color: IaColors.textLow)),
              const SizedBox(width: IaSpacing.s),
              Icon(Icons.chevron_right, size: 20, color: IaColors.textLow),
            ],
          ),
        ),
      ),
    );
  }
}

/// 歌曲行（封面 + 歌名 + 歌手·专辑 + 时长；点击开播，长按 WP 菜单）。
class SongRow extends StatelessWidget {
  const SongRow({
    required this.track,
    required this.onTap,
    required this.onLongPress,
    this.isPlaying = false,
    this.isLiked = false,
    super.key,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isPlaying;
  final bool isLiked;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final ms = track.durationMs;
    final sec = (ms / 1000).round();
    final dur = '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: IaSpacing.m, vertical: IaSpacing.m),
          decoration:
              const BoxDecoration(border: Border(bottom: BorderSide(color: IaColors.hairline))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: IaType.list,
                                color: isPlaying ? p.accent : IaColors.textHi,
                                fontWeight:
                                    isPlaying ? IaType.semibold : IaType.regular)),
                      ),
                      if (isLiked)
                        Padding(
                          padding: const EdgeInsets.only(left: IaSpacing.s),
                          child: Text('♥', style: TextStyle(fontSize: 12, color: p.accent)),
                        ),
                    ]),
                    const SizedBox(height: IaSpacing.xs),
                    Text('${track.artistDisplay} · ${track.albumDisplay}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12, color: IaColors.textLow)),
                  ],
                ),
              ),
              const SizedBox(width: IaSpacing.m),
              Text(dur,
                  style:
                      const TextStyle(fontSize: 12, color: IaColors.textLow)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 右缘字母导航轨（拖动定位到分组；回调返回字母）。
class LetterRail extends StatelessWidget {
  const LetterRail({
    required this.letters,
    required this.onPick,
    this.onEnd,
    super.key,
  });

  final List<String> letters;
  final ValueChanged<String> onPick;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) {
        final box = context.findRenderObject()! as RenderBox;
        final y = d.localPosition.dy.clamp(0.0, box.size.height - 1);
        final i = (y / box.size.height * letters.length).floor();
        onPick(letters[i.clamp(0, letters.length - 1)]);
      },
      onVerticalDragEnd: (_) => onEnd?.call(),
      onTapUp: (d) {
        final box = context.findRenderObject()! as RenderBox;
        final i = (d.localPosition.dy / box.size.height * letters.length).floor();
        onPick(letters[i.clamp(0, letters.length - 1)]);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final l in letters)
            SizedBox(
              height: 15,
              child: Text(l,
                  style: const TextStyle(
                      fontSize: IaSpacing.railLetter, color: IaColors.textMid)),
            ),
        ],
      ),
    );
  }
}

/// WP 式长按上下文菜单（黑底横条升起 + accent 上缘；细体大字）。
Future<void> showWpMenu(
  BuildContext context, {
  required String title,
  required List<(String, VoidCallback)> items,
}) {
  final p = Theme.of(context).extension<IaPalette>()!;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    shape: const RoundedRectangleBorder(),
    builder: (_) => Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.accent, width: 2))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(IaSpacing.xl, IaSpacing.l, IaSpacing.xl, IaSpacing.s),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: IaType.semibold,
                      letterSpacing: 1.2,
                      color: p.accent)),
            ),
          ),
          for (final (label, action) in items)
            InkWell(
              onTap: action,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.xl, vertical: IaSpacing.l),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: IaColors.hairline))),
                child: Text(label,
                    style: TextStyle(
                        fontSize: IaType.menu,
                        fontWeight: IaType.light,
                        color: IaColors.textHi)),
              ),
            ),
          const SizedBox(height: IaSpacing.xl),
        ],
      ),
    ),
  );
}

/// WP toast：顶部整宽横条（来源标题 accent 小字 + 消息细体），2.6s 自动收回。
void showWpToast(BuildContext context,
    {required String title, required String message}) {
  final p = Theme.of(context).extension<IaPalette>()!;
  final overlay = Overlay.of(context, rootOverlay: true);
  final ctrl = AnimationController(vsync: overlay, duration: const Duration(milliseconds: 300));
  final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(anim),
        child: Material(
          color: Colors.black.withValues(alpha: 0.96),
          child: Container(
            decoration:
                BoxDecoration(border: Border(bottom: BorderSide(color: IaColors.hairline))),
            padding:
                const EdgeInsets.fromLTRB(IaSpacing.xl, IaSpacing.l, IaSpacing.xl, IaSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: IaType.semibold,
                        letterSpacing: 1.2,
                        color: p.accent)),
                const SizedBox(height: IaSpacing.xs),
                Text(message,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: IaType.light,
                        color: IaColors.textHi)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  ctrl.forward();
  Future<void>.delayed(const Duration(milliseconds: 2600), () async {
    await ctrl.reverse();
    entry.remove();
    ctrl.dispose();
  });
}

/// 空态：细体大字 + 弱提示（无插画——内容即界面）。
class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(IaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: IaSpacing.m),
                child: Text(subtitle!,
                    style:
                        const TextStyle(fontSize: 12.5, color: IaColors.textLow)),
              ),
          ],
        ),
      ),
    );
  }
}
