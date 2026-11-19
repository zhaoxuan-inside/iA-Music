/// 共享 UI 组件：曲面屏边距 / 分区标签 / 大字行 / 歌曲行 / 字母轨 / WP 菜单与通知 / 空态。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import 'wp_motion.dart';

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
    e.left,
    topInset(context) + IaSpacing.l,
    e.right,
    140,
  );
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
/// **高度恒定**：kicker 行 / 标题槽 / 副题槽都是定高槽位——标题不会被
/// 内容顶高，多页之间的头部永远一样高（配合 [HubPage] 固定在页顶，
/// 不随内容滚动）。
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

  /// true = Hub 主标题（44 Light）；false = 页面标题（36 Light）。
  final bool hero;

  /// 固定页头总高（所有页一致；hero 与否只改字号不改槽位）。
  static const double height = 139;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // kicker 行：定高 40（与右上角 IconButton 同高，其余页仍等高）
        SizedBox(
          height: 40,
          child: Row(
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
              if (trailing != null)
                Align(alignment: Alignment.centerRight, child: trailing),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 标题槽：定高（hero 与普通标题同槽，保证各页头部一样高）
        SizedBox(
          height: 45,
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: hero ? IaType.hero : IaType.hub,
                height: 1.02,
                fontWeight: IaType.light,
                letterSpacing: IaType.titleTracking,
                color: IaColors.textHi,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        // 副题槽：定高占位（无副题也保留，保证基线一致）
        SizedBox(
          height: 18,
          child: subtitle == null
              ? null
              : Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: IaColors.textLow,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 15),
        Container(width: 32, height: 2, color: p.accent),
      ],
    );
  }
}

/// Hub 页固定骨架：**固定页头**（不随内容滚动、高度恒定）+ 内容列表。
///
/// 内容区自适应全宽；列表左右吃曲面安全区，底部给迷你条留位。
/// 条目按序 Turnstile Feather 翻入（WP8 pivot 页入场招牌，见 wp_motion.dart）。
class HubPage extends StatelessWidget {
  const HubPage({required this.header, required this.children, super.key});

  final PageHeader header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final edge = edgeInsets(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            edge.left,
            topInset(context) + IaSpacing.l,
            edge.right,
            0,
          ),
          child: header,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              edge.left,
              IaSpacing.xl,
              edge.right,
              140,
            ),
            children: [
              for (var i = 0; i < children.length; i++)
                FeatherIn(index: i, child: children[i]),
            ],
          ),
        ),
      ],
    );
  }
}

/// 分区头：accent 小节标签 + 弱计数 + 右侧操作。
class SectionHead extends StatelessWidget {
  const SectionHead({required this.label, this.meta, this.trailing, super.key});

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
          horizontal: IaSpacing.m,
          vertical: IaSpacing.s,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? p.accent : IaColors.hairlineStrong,
          ),
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
      child: TiltOnPress(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: IaColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: IaType.light,
                          color: IaColors.textHi,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: IaColors.textLow,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: IaSpacing.m),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: IaColors.textLow,
                ),
              ],
            ),
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
    this.missing = false,
    super.key,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? leading;
  final bool isPlaying;
  final bool isLiked;

  /// 文件缺失/已删除：诚实灰显（点击仍可播，播放器会跳过）。
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final ms = track.durationMs;
    final sec = (ms / 1000).round();
    final dur = '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
    return Material(
      color: Colors.transparent,
      child: TiltOnPress(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: IaSpacing.m,
              vertical: IaSpacing.m,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: IaColors.hairline)),
            ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: IaType.list,
                                color: missing
                                    ? IaColors.textLow
                                    : isPlaying
                                        ? p.accent
                                        : IaColors.textHi,
                                fontWeight: isPlaying
                                    ? IaType.semibold
                                    : IaType.regular,
                              ),
                            ),
                          ),
                          if (isLiked)
                            Padding(
                              padding: const EdgeInsets.only(left: IaSpacing.s),
                              child: Text(
                                '♥',
                                style: TextStyle(fontSize: 12, color: p.accent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: IaSpacing.xs),
                      Text(
                        '${track.artistDisplay} · ${track.albumDisplay}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: IaColors.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: IaSpacing.m),
                Text(
                  dur,
                  style: const TextStyle(fontSize: 12, color: IaColors.textLow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 右缘字母速查轨——复刻 Windows 11 跳转栏（jump bar）逻辑：
///
/// * **按下即定位**：手指落点对应字母立即生效（跳组 + 中央大字母弹出），
///   轨上该字母高亮放大，第一下就有振动确认；
/// * **拖动实时刷屏**：列表跟随手指即时跳组（无缓动等待），每越过一个
///   字母触发一次 `selectionClick` 振动，与 Win11 滑过刻度一致；
/// * **松手即停**：大字母消失、列表停在该组；横向滑出轨道仍按纵向位置
///   连续定位（ gesture 状态保留，手指不脱靶）。
class LetterRail extends StatefulWidget {
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
  State<LetterRail> createState() => _LetterRailState();
}

class _LetterRailState extends State<LetterRail> {
  int _active = -1;
  bool _pressed = false;

  void _locate(Offset local, {bool force = false}) {
    if (widget.letters.isEmpty) {
      return;
    }
    final box = context.findRenderObject()! as RenderBox;
    final y = local.dy.clamp(0.0, box.size.height - 1);
    final i = (y / box.size.height * widget.letters.length).floor().clamp(
      0,
      widget.letters.length - 1,
    );
    if (force || i != _active) {
      if (i != _active) {
        HapticFeedback.selectionClick(); // 越过一个字母 = 一次刻度振动
      }
      setState(() => _active = i);
      widget.onPick(widget.letters[i]);
    }
  }

  void _press(Offset local) {
    if (!_pressed) {
      _pressed = true;
      _active = -1; // 新一次按压：即使落在同一字母也要跳一次
    }
    _locate(local, force: true);
  }

  void _finish() {
    if (!_pressed) {
      return;
    }
    _pressed = false;
    if (_active != -1) {
      HapticFeedback.lightImpact(); // 松手确认
      setState(() => _active = -1);
    }
    widget.onEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).extension<IaPalette>()!.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 按下 / 拖动共用一套定位逻辑：触点在哪组，列表就在哪组
      onVerticalDragDown: (d) => _press(d.localPosition),
      onVerticalDragUpdate: (d) => _locate(d.localPosition),
      onVerticalDragEnd: (_) => _finish(),
      onVerticalDragCancel: _finish,
      onTapDown: (d) => _press(d.localPosition),
      onTapUp: (_) => _finish(),
      onTapCancel: _finish,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.letters.length; i++)
            SizedBox(
              height: 16,
              child: Center(
                child: Text(
                  widget.letters[i],
                  style: TextStyle(
                    fontSize: i == _active ? 13 : IaSpacing.railLetter,
                    fontWeight: i == _active ? IaType.semibold : IaType.regular,
                    color: i == _active ? accent : IaColors.textMid,
                  ),
                ),
              ),
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
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.accent, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IaSpacing.xl,
              IaSpacing.l,
              IaSpacing.xl,
              IaSpacing.s,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: IaType.semibold,
                  letterSpacing: 1.2,
                  color: p.accent,
                ),
              ),
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
                  horizontal: IaSpacing.xl,
                  vertical: IaSpacing.l,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: IaType.menu,
                    fontWeight: IaType.light,
                    color: IaColors.textHi,
                  ),
                ),
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
void showWpToast(
  BuildContext context, {
  required String title,
  required String message,
  bool isError = false,
}) {
  if (!context.mounted) {
    return;
  }
  final p = Theme.of(context).extension<IaPalette>()!;
  // 先取状态栏高度：OverlayEntry 的生命周期可能长于调用方 context，
  // 且调用方可能被 SafeArea 去掉了 padding；用 root view 的 viewPadding，
  // 保证 toast 永远从状态栏下方开始，不盖住状态栏。
  final topInset = MediaQueryData.fromView(View.of(context)).viewPadding.top;
  final overlay = Overlay.of(context, rootOverlay: true);
  final ctrl = AnimationController(
    vsync: overlay,
    duration: const Duration(milliseconds: 300),
  );
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
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(anim),
          child: Material(
            color: Colors.black.withValues(alpha: 0.96),
            child: InkWell(
              onTap: isError ? close : null, // 错误条点按关闭
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isError ? IaColors.error : IaColors.hairline,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  IaSpacing.xl,
                  IaSpacing.l,
                  IaSpacing.xl,
                  IaSpacing.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: IaType.semibold,
                        letterSpacing: 1.2,
                        color: isError ? IaColors.error : p.accent,
                      ),
                    ),
                    const SizedBox(height: IaSpacing.xs),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: IaType.light,
                        color: isError ? IaColors.error : IaColors.textHi,
                      ),
                    ),
                    if (isError) ...[
                      const SizedBox(height: IaSpacing.xs),
                      const Text(
                        '点按关闭',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: IaColors.textLow,
                        ),
                      ),
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
            Text(
              title,
              style: TextStyle(
                fontSize: IaType.page,
                fontWeight: IaType.light,
                color: IaColors.textHi,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: IaSpacing.m),
                child: Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: IaColors.textLow,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
