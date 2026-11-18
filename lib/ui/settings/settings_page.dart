/// 设置页（菜单 → 各项独立子页）：主题色 / 存储 / 收集 / 关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../services/collect/platform_store.dart';
import '../../state/collect_providers.dart';
import '../../state/library_providers.dart';
import '../../state/settings_controller.dart';
import '../shared/ui_kit.dart';
import 'subpages.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(settingsProvider);
    final accentName = kWpPalette
        .where((w) => w.value.toARGB32() == st.accent.toARGB32())
        .map((w) => w.name)
        .firstOrNull;
    final trackCount = ref.watch(trackCountProvider).value ?? 0;
    final biliIn = ref.watch(platformLoginProvider(PlatformId.bilibili)).value ?? false;
    final ytIn = ref.watch(platformLoginProvider(PlatformId.youtube)).value ?? false;
    final loggedCount = (biliIn ? 1 : 0) + (ytIn ? 1 : 0);

    return HubPage(
      header: const PageHeader(
        kicker: '应用',
        title: '设置',
        subtitle: '个性化 · 存储与收集 · 关于',
      ),
      children: [
        BigRow(
          title: '主题色',
          subtitle: '当前：${accentName ?? '自定义'}',
          onTap: () => Navigator.of(context).push(zuneRoute<void>(
              builder: (_) => const ThemeSubPage())),
        ),
        BigRow(
          title: '存储',
          subtitle: '目录 · $trackCount 首',
          onTap: () => Navigator.of(context).push(
              zuneRoute<void>(builder: (_) => const StorageSubPage())),
        ),
        BigRow(
          title: '收集',
          subtitle: '登录 · 站内搜索 · 已登录 $loggedCount/2',
          onTap: () => Navigator.of(context).push(
              zuneRoute<void>(builder: (_) => const CollectSubPage())),
        ),
        BigRow(
          title: '关于',
          subtitle: '语言 · 开箱仪式',
          onTap: () => Navigator.of(context).push(
              zuneRoute<void>(builder: (_) => const AboutSubPage())),
        ),
        const SizedBox(height: IaSpacing.xl),
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
    final edge = edgeInsets(context);
    final current = kWpPalette
        .where((w) => w.value.toARGB32() == st.accent.toARGB32())
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
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: IaSpacing.s),
            const PageHeader(
              kicker: '个性化',
              title: '主题色',
              subtitle: 'WP 经典色板 · 点一下，全 App 立即变色',
            ),
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
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: w.value,
                        border: st.accent.toARGB32() == w.value.toARGB32()
                            ? Border.all(color: IaColors.textHi, width: 2)
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      alignment: Alignment.center,
                      child: st.accent.toARGB32() == w.value.toARGB32()
                          ? const Icon(Icons.check,
                              size: 20, color: IaColors.onAccent)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: IaSpacing.xl),
            Text('当前：${current ?? '自定义'}',
                style: const TextStyle(fontSize: 12.5, color: IaColors.textLow)),
          ],
        ),
      ),
    );
  }
}

/// 收集子页见 subpages.dart（登录 / 链接提取 / 进度的唯一实现）。
