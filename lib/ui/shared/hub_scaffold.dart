/// Hub 页骨架与排版基线：曲面屏边距 / 小节标签 / 页头 / 固定骨架 / 分区头。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';
import 'wp_motion.dart';

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

/// Hub 页固定骨架（sliver 版）：需要列表虚拟化的屏用这个变体——
/// 固定页头 + CustomScrollView，网格/长列表按可视区构建（不再
/// shrinkWrap 全量 eager build）。
class HubSliverPage extends StatelessWidget {
  const HubSliverPage({required this.header, required this.slivers, super.key});

  final PageHeader header;
  final List<Widget> slivers;

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
          child: CustomScrollView(slivers: slivers),
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
