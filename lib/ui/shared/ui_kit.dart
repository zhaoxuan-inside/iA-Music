/// 共享 UI 组件：曲面屏边距 / 分区标签 / 大字行 / 歌曲行 / 字母轨 / WP 菜单与通知 / 空态。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';

/// Zune 页面路由：WP「turnstile」翻入转场（demo .scr.enter）。
///
/// 进入：rotateX 62°→0 · scale .96→1 · 透明度 .25→1，0.36s，origin 50% 62%；
/// 返回：同动画倒放（= demo flipOut 0.28s）。黑底画布下底层页不可见也无妨。
PageRouteBuilder<T> zuneRoute<T>({required WidgetBuilder builder}) =>
    PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => builder(context),
      transitionsBuilder: (_, anim, secondary, child) {
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return AnimatedBuilder(
          animation: t,
          builder: (_, _) {
            final v = t.value;
            final angle = (1 - v) * 62 * math.pi / 180; // 62° → 0
            final scale = 0.96 + 0.04 * v; // .96 → 1
            return Opacity(
              opacity: 0.25 + 0.75 * v,
              child: Transform(
                alignment: const Alignment(0, 0.24), // origin 50% 62%
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018) // 透视（轻微近大远小）
                  ..rotateX(angle)
                  ..scaleByDouble(scale, scale, scale, 1),
                child: child,
              ),
            );
          },
        );
      },
    );


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

/// 状态栏高度（edge-to-edge 下 Hub 页内容首行需要让开）。
double topInset(BuildContext context) => MediaQuery.of(context).padding.top;

/// Hub 页内容外边距：左右曲面安全区 + 顶部状态栏让位 + 底部迷你条让位。
/// 各页 ListView 统一取此边距，杜绝与状态栏/迷你条重叠。
EdgeInsets hubPadding(BuildContext context) {
  final e = edgeInsets(context);
  return EdgeInsets.fromLTRB(
      e.left, topInset(context) + IaSpacing.l, e.right, 140);
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

/// 页头：kicker（accent 全大写）+ 细体大标题 + 副题 + accent 短横。
///
/// Hub 七屏与子页统一使用它，让每一次横滑都落在同一条排版基线上。
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.kicker,
    required this.title,
    this.subtitle,
    this.trailing,
    this.hero = false,
    super.key,
  });

  final String kicker;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// true = Hub 主标题（44 Light）；false = 页面标题（34 Light）。
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                kicker.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: IaType.semibold,
                  letterSpacing: IaType.kickerTracking,
                  color: p.accent,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: hero ? IaType.hero : IaType.hub,
            height: 1.02,
            fontWeight: IaType.light,
            letterSpacing: IaType.titleTracking,
            color: IaColors.textHi,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 9),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: IaColors.textLow,
            ),
          ),
        ],
        const SizedBox(height: 15),
        Container(width: 32, height: 2, color: p.accent),
      ],
    );
  }
}

/// 分区头：accent 小节标签 + 弱计数 + 右侧操作。
class SectionHead extends StatelessWidget {
  const SectionHead({
    required this.label,
    this.meta,
    this.trailing,
    super.key,
  });

  final String label;
  final String? meta;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SectionLabel(label),
        if (meta != null) ...[
          const SizedBox(width: IaSpacing.m),
          Expanded(
            child: Text(
              meta!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: IaColors.textLow),
            ),
          ),
        ] else
          const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// WP 直角 chip：细线描边，选中时 accent 描边 + accent 字。
///
/// 替代 Material 的圆角 tonal chip，避免破坏纯黑画布。
class ZuneChip extends StatelessWidget {
  const ZuneChip({
    required this.label,
    this.onTap,
    this.active = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: IaSpacing.m, vertical: IaSpacing.s),
        decoration: BoxDecoration(
          border: Border.all(
              color: active ? p.accent : IaColors.hairlineStrong),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? p.accent : IaColors.textMid,
            fontWeight: active ? IaType.semibold : IaType.regular,
          ),
        ),
      ),
    );
  }
}

/// 大字行（细体标题 + 副题 + 箭头），分类菜单与页内跳转的标准行。
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
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration:
              const BoxDecoration(border: Border(bottom: BorderSide(color: IaColors.hairline))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: IaType.light,
                            color: IaColors.textHi)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: IaColors.textLow)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: IaSpacing.m),
              const Icon(Icons.chevron_right, size: 18, color: IaColors.textLow),
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
    this.leading,
    this.isPlaying = false,
    this.isLiked = false,
    super.key,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? leading;
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
              if (leading != null) ...[
                leading!,
                const SizedBox(width: IaSpacing.m),
              ],
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
    builder: (sheetContext) => Container(
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
              onTap: () {
                Navigator.of(sheetContext).pop();
                action();
              },
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
/// WP toast：顶部整宽横条从顶边滑入（来源标题 accent 小字 + 消息），直角无气泡。
///
/// 普通通知约 2.6s 自动收回；[isError] 时红色标识、**不自动收回**，
/// 点按任意处关闭，完整展示错误内容（长文换行）。
void showWpToast(BuildContext context,
    {required String title, required String message, bool isError = false}) {
  if (!context.mounted) {
    return;
  }
  final p = Theme.of(context).extension<IaPalette>()!;
  // 先取状态栏高度：OverlayEntry 的生命周期可能长于调用方 context，
  // 且调用方可能被 SafeArea 去掉了 padding；用 root view 的 viewPadding，
  // 保证 toast 永远从状态栏下方开始，不盖住状态栏。
  final topInset = MediaQueryData.fromView(View.of(context)).viewPadding.top;
  final overlay = Overlay.of(context, rootOverlay: true);
  final ctrl = AnimationController(vsync: overlay, duration: const Duration(milliseconds: 300));
  final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
  late final OverlayEntry entry;
  var closed = false;
  void close() async {
    if (closed) {
      return;
    }
    closed = true;
    if (ctrl.isAnimating) {
      await ctrl.reverse();
    }
    if (entry.mounted) {
      entry.remove();
    }
    ctrl.dispose();
  }

  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: topInset,
      left: 0,
      right: 0,
      child: ClipRect(
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(anim),
          child: Material(
          color: Colors.black.withValues(alpha: 0.96),
          child: InkWell(
            onTap: isError ? close : null, // 错误条点按关闭
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: isError ? IaColors.error : IaColors.hairline)),
              ),
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
                          color: isError ? IaColors.error : p.accent)),
                  const SizedBox(height: IaSpacing.xs),
                  Text(message,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: IaType.light,
                          color: isError ? IaColors.error : IaColors.textHi)),
                  if (isError) ...[
                    const SizedBox(height: IaSpacing.xs),
                    const Text('点按关闭',
                        style:
                            TextStyle(fontSize: 10.5, color: IaColors.textLow)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    ),
  );
  overlay.insert(entry);
  ctrl.forward();
  if (!isError) {
    Future<void>.delayed(const Duration(milliseconds: 2600), () async {
      if (!entry.mounted) {
        ctrl.dispose();
        return;
      }
      await ctrl.reverse();
      if (entry.mounted) {
        entry.remove();
      }
      ctrl.dispose();
    });
  }
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
