/// 设置页（菜单 → 各项独立子页）：主题色 / 存储 / 收集 / 关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/settings_controller.dart';
import '../shared/ui_kit.dart';
import 'subpages.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(settingsProvider);
    final edge = edgeInsets(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
      children: [
        const SizedBox(height: IaSpacing.xl),
        const SectionLabel('应用'),
        const SizedBox(height: IaSpacing.s),
        Text('设置',
            style: TextStyle(
                fontSize: IaType.page,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        const SizedBox(height: IaSpacing.s),
        const Text('个性化 · 存储与收集 · 关于',
            style: TextStyle(fontSize: 12, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.m),
        BigRow(
          title: '主题色',
          subtitle: 'WP 经典色板',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ThemeSubPage())),
        ),
        BigRow(
          title: '存储',
          subtitle: '${ref.watch(trackCountProvider).value ?? 0} 首',
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StorageSubPage())),
        ),
        BigRow(
          title: '收集',
          subtitle: '登录平台 · 链接提取 · 进度',
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CollectSubPage())),
        ),
        BigRow(
          title: '关于',
          subtitle: '语言 · 开箱仪式',
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutSubPage())),
        ),
        const SizedBox(height: IaSpacing.xl),
        const Text(
          '设置 · 左缘右滑返回',
          style: TextStyle(fontSize: 11, color: IaColors.textLow),
        ),
      ],
    );
  }
}

/// 主题色子页。
class ThemeSubPage extends ConsumerWidget {
  const ThemeSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(settingsProvider);
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);
    final current = kWpPalette
        .where((w) => w.value.value == st.accent.value)
        .map((w) => w.name)
        .firstOrNull;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: IaSpacing.m),
            Text('主题色',
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            const SizedBox(height: IaSpacing.m),
            const Text('WP 经典色板 · 点一下，全 App 立即变色',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final w in kWpPalette)
                  InkWell(
                    onTap: () => ref.read(settingsProvider.notifier).setAccent(w.value),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: w.value,
                        border: st.accent.value == w.value.value
                            ? Border.all(color: IaColors.textHi, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: st.accent.value == w.value.value
                          ? const Icon(Icons.check,
                              size: 20, color: IaColors.onAccent)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: IaSpacing.l),
            Text('当前：${current ?? '自定义'}',
                style: const TextStyle(fontSize: 12.5, color: IaColors.textLow)),
          ],
        ),
      ),
    );
  }
}

/// 收集子页（A 层登录 + B 层链接提取 + 提取与补全进度入口）。
class CollectSubPage extends ConsumerWidget {
  const CollectSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);
    final queueN =
        0; // 提取队列在 v3 首版为占位（真实提取引擎在二期接入）；进度页仍可打开

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: IaSpacing.m),
            Text('收集',
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            const SizedBox(height: IaSpacing.m),
            const Text('所有音乐统一收入同一个目录、同一个曲库，不分来源。',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('A 层 · 深度支持（登录 + 站内搜索 + 批量提取）'),
            const SizedBox(height: IaSpacing.m),
            for (final platform in const ['B 站', 'YouTube'])
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.m, vertical: IaSpacing.l),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: IaColors.hairline))),
                child: Row(
                  children: [
                    Text(platform,
                        style: const TextStyle(
                            fontSize: IaType.list, color: IaColors.textHi)),
                    const Spacer(),
                    Text('二期接入',
                        style:
                            TextStyle(fontSize: 12, color: IaColors.textLow)),
                  ],
                ),
              ),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('B 层 · 任意链接提取'),
            const SizedBox(height: IaSpacing.m),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.s),
              decoration: BoxDecoration(
                  border: Border.all(color: IaColors.hairlineStrong)),
              child: TextField(
                style: const TextStyle(fontSize: 13, color: IaColors.textHi),
                decoration: const InputDecoration(
                  hintText: '粘贴任意视频/音频链接…（二期接入）',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) {},
              ),
            ),
            const SizedBox(height: IaSpacing.s),
            const Text('底层走 yt-dlp · 覆盖数百个站点 · 字幕自动转歌词（二期）',
                style: TextStyle(fontSize: 11, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            Container(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline))),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提取与补全进度',
                    style: TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
                subtitle: Text('$queueN 项进行中（占位）',
                    style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
                trailing: const Icon(Icons.chevron_right, color: IaColors.textLow),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ExtractPage())),
              ),
            ),
            Text('占位说明',
                style: TextStyle(
                    fontSize: 11,
                    color: p.textLow,
                    decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }
}
