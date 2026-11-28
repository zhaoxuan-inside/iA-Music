/// 插件子页：已装磁贴墙 + 添加磁贴 + 市场安装（docs/PLUGIN.md）。
/// 宿主零平台代码——外部平台能力全部来自这里安装的插件。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/plugin_providers.dart';
import '../layout/sub_header.dart';
import '../shared/ui_kit.dart';
import 'plugin_config_page.dart';

/// 插件子页：磁贴墙（已装插件 + 添加磁贴）+ 市场列表。
/// 磁贴点击进配置页；添加磁贴收口扫描导入 / URL 安装 / 市场索引。
class PluginsPage extends ConsumerStatefulWidget {
  const PluginsPage({super.key});

  @override
  ConsumerState<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends ConsumerState<PluginsPage> {
  @override
  void initState() {
    super.initState();
    // 已存市场索引则自动拉取（磁贴墙下方的市场列表直接就绪）
    ref.read(marketUrlProvider.future).then((url) {
      if (mounted && url.isNotEmpty) {
        ref.read(pluginsProvider.notifier).refreshMarket(url);
      }
    });
  }

  /// 磁贴墙：两列 1:1 磁贴（已装 + 末位添加磁贴），零圆角零阴影。
  Widget _tileWall(BuildContext context, PluginsState st) {
    const spacing = 14.0;
    return LayoutBuilder(
      builder: (context, box) {
        final tile = (box.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: IaSpacing.l,
          children: [
            for (final p in st.installed)
              _PluginTile(
                p: p,
                size: tile,
                onTap: () => Navigator.of(context).push(zuneRoute<void>(
                    builder: (_) =>
                        PluginConfigPage(pluginId: p.manifest.id))),
              ),
            _AddTile(size: tile, onTap: () => _addActions(st)),
          ],
        );
      },
    );
  }

  /// 添加磁贴菜单：扫描导入 / 从 URL 安装 / 市场索引。
  void _addActions(PluginsState st) {
    showWpMenu(context, title: '添加插件', items: [
      (
        '扫描导入',
        () => ref.read(pluginsProvider.notifier).importLocal(),
      ),
      ('从 URL 安装…', _installFromUrlDialog),
      ('市场索引…', _marketDialog),
    ]);
  }

  /// 从单个 .plugin.js 的 URL 安装。
  void _installFromUrlDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: IaColors.canvas,
        title: const Text('从 URL 安装插件', style: TextStyle(fontSize: 16.5)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 14, color: IaColors.textHi),
          decoration:
              const InputDecoration(hintText: 'https://…/xxx.plugin.js'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ref
                  .read(pluginsProvider.notifier)
                  .installFromUrl(ctrl.text.trim());
            },
            child: const Text('安装'),
          ),
        ],
      ),
    );
  }

  /// 市场索引 URL 配置 + 刷新（URL 记住为默认市场）。
  Future<void> _marketDialog() async {
    final ctrl = TextEditingController(text: await ref.read(marketUrlProvider.future));
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: IaColors.canvas,
        title: const Text('市场索引 URL', style: TextStyle(fontSize: 16.5)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 14, color: IaColors.textHi),
          decoration: const InputDecoration(
              hintText: '市场索引 JSON 的 URL（可自建仓库）'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ref.read(pluginsProvider.notifier).refreshMarket(ctrl.text);
            },
            child: const Text('刷新'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(pluginsProvider);
    final edge = edgeInsets(context);

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const SubHeader(title: '插件', showBack: false),
            const SizedBox(height: IaSpacing.xl),
            if (st.message.isNotEmpty) ...[
              Text(st.message,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: Theme.of(context)
                          .extension<IaPalette>()!
                          .accent)),
              const SizedBox(height: IaSpacing.s),
            ],
            // ── 已安装磁贴墙 ──
            const SectionLabel('已安装'),
            const SizedBox(height: IaSpacing.m),
            _tileWall(context, st),
            if (st.installed.isEmpty) ...[
              const SizedBox(height: IaSpacing.s),
              Text('还没有插件——点上方「+」磁贴添加',
                  style: TextStyle(fontSize: 13.5, color: IaColors.textLow)),
            ],
            // ── 插件市场（刷新出条目才出现）──
            if (st.market.isNotEmpty) ...[
              const SizedBox(height: IaSpacing.xl),
              SectionHead(
                  label: '插件市场',
                  meta: st.marketName.isEmpty
                      ? '${st.market.length} 项'
                      : '${st.marketName} · ${st.market.length} 项'),
              const SizedBox(height: IaSpacing.s),
              for (final e in st.market)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 名称与版本分行显示
                            Text(e.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: IaType.list,
                                    color: IaColors.textHi)),
                            Text('v${e.version}',
                                style: TextStyle(
                                    fontSize: 12.5, color: IaColors.textLow)),
                            if (e.notes.isNotEmpty)
                              Text(e.notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: IaColors.textLow)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: st.busy
                            ? null
                            : () => ref
                                .read(pluginsProvider.notifier)
                                .installFromMarket(e),
                        child: const Text('安装',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 已装插件磁贴：accent 色块 + 能力图标（禁用压暗），名称/版本在磁贴下方分行。
class _PluginTile extends StatelessWidget {
  const _PluginTile({required this.p, required this.size, required this.onTap});

  final InstalledPlugin p;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).extension<IaPalette>()!.accent;
    final isSource =
        p.enabled && p.manifest.activeCapabilities.contains('source');

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              // 禁用插件整块压暗——WP 式「关掉的磁贴」
              opacity: p.enabled ? 1 : 0.35,
              child: Container(
                width: size,
                height: size,
                color: accent,
                alignment: Alignment.center,
                child: Icon(
                  p.manifest.activeCapabilities.contains('source')
                      ? Icons.music_note
                      : Icons.extension,
                  size: 30,
                  color: IaColors.onAccent,
                ),
              ),
            ),
            const SizedBox(height: IaSpacing.s),
            Text(p.manifest.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSource ? IaType.semibold : IaType.regular,
                    color: IaColors.textHi)),
            Text('v${p.manifest.version}${p.enabled ? '' : ' · 已禁用'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
          ],
        ),
      ),
    );
  }
}

/// 添加磁贴：细线描边空磁贴 + accent「+」，点开添加菜单。
class _AddTile extends StatelessWidget {
  const _AddTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).extension<IaPalette>()!.accent;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  border: Border.all(color: IaColors.hairlineStrong)),
              alignment: Alignment.center,
              child: Icon(Icons.add, size: 30, color: accent),
            ),
            const SizedBox(height: IaSpacing.s),
            Text('添加插件',
                style: TextStyle(fontSize: 14, color: IaColors.textHi)),
            Text('扫描 · URL · 市场',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
          ],
        ),
      ),
    );
  }
}
