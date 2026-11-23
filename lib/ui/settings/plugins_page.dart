/// 插件子页：市场安装 / 本地导入 / 启停 / 卸载（docs/PLUGIN.md）。
/// 宿主零平台代码——外部平台能力全部来自这里安装的插件。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';
import '../../state/plugin_providers.dart';
import '../shared/sub_header.dart';
import '../shared/ui_kit.dart';
import 'platform_search_page.dart';
import 'plugin_login_pages.dart';

/// 插件子页：市场安装 / 本地导入 / 启停 / 卸载（docs/PLUGIN.md）。
/// 宿主零平台代码——外部平台能力全部来自这里安装的插件。
class PluginsPage extends ConsumerStatefulWidget {
  const PluginsPage({super.key});

  @override
  ConsumerState<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends ConsumerState<PluginsPage> {
  final _marketCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(marketUrlProvider.future).then((url) {
      if (mounted && url.isNotEmpty && _marketCtrl.text.isEmpty) {
        _marketCtrl.text = url;
        ref.read(pluginsProvider.notifier).refreshMarket(url);
      }
    });
  }

  @override
  void dispose() {
    _marketCtrl.dispose();
    super.dispose();
  }

  /// 已安装插件行：名称/版本 + 能力行 + 启停/卸载；音频源插件（启用中）
  /// 额外显示登录态 + 登录/管理/站内搜索（登录是插件能力，宿主只做入口）。
  Widget _installedRow(BuildContext context, InstalledPlugin p, PluginsState st) {
    final isSource =
        p.enabled && p.manifest.activeCapabilities.contains('source');
    final auth =
        isSource ? ref.watch(sourceAuthStatusProvider(p.manifest.id)).value : null;
    final kind = isSource
        ? ref.watch(sourceAuthKindProvider(p.manifest.id)).value ?? 'none'
        : 'none';
    final loggedIn = auth?.loggedIn ?? false;
    final account = auth?.account ?? '';
    final palette = Theme.of(context).extension<IaPalette>()!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.manifest.name} ${p.manifest.version}',
                    style: const TextStyle(
                        fontSize: IaType.list, color: IaColors.textHi)),
                const SizedBox(height: 2),
                Text(
                  '${p.manifest.id} · ${p.manifest.capabilities.join("/")}'

                  '${p.manifest.author.isEmpty ? '' : ' · ${p.manifest.author}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: IaColors.textLow),
                ),
                if (isSource) ...[
                  const SizedBox(height: 2),
                  Text(
                    loggedIn
                        ? (account.isEmpty ? '已登录' : '已登录 · $account')
                        : (kind == 'none' ? '无需登录' : '未登录'),
                    style: TextStyle(
                        fontSize: 11,
                        color: loggedIn ? palette.accent : IaColors.textLow),
                  ),
                ],
              ],
            ),
          ),
          if (isSource)
            TextButton(
              onPressed: st.busy
                  ? null
                  : () => loggedIn || kind == 'none'
                      ? unawaited(_sourceManage(p))
                      : unawaited(_sourceLogin(p)),
              child: Text(
                  loggedIn
                      ? '管理'
                      : (kind == 'none' ? '站内搜索' : '登录'),
                  style: TextStyle(fontSize: 12, color: palette.accent)),
            ),
          WpSwitch(
            value: p.enabled,
            onChanged: st.busy
                ? null
                : (v) => ref
                    .read(pluginsProvider.notifier)
                    .setEnabled(p.manifest.id, v),
          ),
          TextButton(
            onPressed: st.busy
                ? null
                : () => ref
                    .read(pluginsProvider.notifier)
                    .uninstall(p.manifest.id),
            child: const Text('卸载',
                style: TextStyle(fontSize: 12, color: IaColors.error)),
          ),
        ],
      ),
    );
  }

  /// 按 id 取音频源 handle（启用的 source 插件；缺失返回 null）。
  Future<SourcePluginHandle?> _handleOf(String pluginId) async {
    final handles = await ref.read(sourceHandlesProvider.future);
    for (final h in handles) {
      if (h.id == pluginId) {
        return h;
      }
    }
    return null;
  }

  /// 音频源登录：按 authKind 打开 QR/Cookie 登录页，回来后刷新登录态。
  Future<void> _sourceLogin(InstalledPlugin p) async {
    final kind = await ref.read(sourceAuthKindProvider(p.manifest.id).future);
    if (!mounted) {
      return;
    }
    final page = switch (kind) {
      'cookie' => PluginCookieLoginPage(pluginId: p.manifest.id),
      _ => PluginQrLoginPage(pluginId: p.manifest.id),
    };
    await Navigator.of(context).push(zuneRoute<bool>(builder: (_) => page));
    if (!mounted) {
      return;
    }
    ref.read(sourceEpochProvider.notifier).bump();
    final st = await ref.read(sourceAuthStatusProvider(p.manifest.id).future);
    if (!mounted) {
      return;
    }
    showWpToast(context,
        title: p.manifest.name,
        message: st.loggedIn ? '登录成功 · 凭据已入插件沙箱' : '未保存登录态');
  }

  /// 音频源管理：站内搜索提取 + 退出登录。
  Future<void> _sourceManage(InstalledPlugin p) async {
    final handle = await _handleOf(p.manifest.id);
    if (!mounted) {
      return;
    }
    if (handle == null) {
      showWpToast(context,
          title: p.manifest.name,
          message: '插件未启用——先打开开关',
          isError: true);
      return;
    }
    await showWpMenu(context, title: handle.name, items: [
      (
        '站内搜索 · 提取',
        () => Navigator.of(context).push(zuneRoute<void>(
            builder: (_) => PlatformSearchPage(
                pluginId: handle.id, name: handle.name))),
      ),
      (
        '退出登录',
        () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: IaColors.canvas,
              title: const Text('退出登录',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: IaType.light,
                      color: IaColors.textHi)),
              content: const Text('退出后本机保存的登录凭据会被清除，需要重新登录。',
                  style: TextStyle(fontSize: 13, color: IaColors.textMid)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消',
                      style: TextStyle(fontSize: 13, color: IaColors.textMid)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('退出登录',
                      style: TextStyle(fontSize: 13, color: IaColors.error)),
                ),
              ],
            ),
          );
          if (ok != true) {
            return;
          }
          await handle.authLogout();
          ref.read(sourceEpochProvider.notifier).bump();
          if (mounted) {
            showWpToast(context, title: handle.name, message: '已退出登录');
          }
        },
      ),
    ]);
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
            const SubHeader(title: '插件'),
            const SizedBox(height: IaSpacing.xl),
            const Text('外部平台能力全部来自插件——宿主不内置任何平台调用',
                style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            if (st.message.isNotEmpty) ...[
              Text(st.message,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .extension<IaPalette>()!
                          .accent)),
              const SizedBox(height: IaSpacing.s),
            ],
            // ── 已安装 ──
            const SectionLabel('已安装'),
            if (st.installed.isEmpty)
              const Text('还没有插件——从市场安装、粘贴 URL，或把 .plugin.js 放进插件目录后点「扫描导入」',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            for (final p in st.installed) _installedRow(context, p, st),
            const SizedBox(height: IaSpacing.s),
            Row(
              children: [
                TextButton(
                  onPressed: st.busy
                      ? null
                      : () =>
                          ref.read(pluginsProvider.notifier).importLocal(),
                  child: Text(st.busy ? '处理中…' : '扫描导入',
                      style: TextStyle(
                          fontSize: 12.5, color: Theme.of(context).extension<IaPalette>()!.accent)),
                ),
              ],
            ),
            const SizedBox(height: IaSpacing.l),
            // ── 插件市场 ──
            const SectionLabel('插件市场'),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.s),
              decoration: BoxDecoration(
                  border: Border.all(color: IaColors.hairlineStrong)),
              child: TextField(
                controller: _marketCtrl,
                style: const TextStyle(
                    fontSize: 12.5, color: IaColors.textHi),
                decoration: const InputDecoration(
                  hintText: '市场索引 JSON 的 URL（可自建仓库）',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: IaSpacing.s),
            TextButton(
              onPressed: st.busy
                  ? null
                  : () => ref
                      .read(pluginsProvider.notifier)
                      .refreshMarket(_marketCtrl.text),
              child: Text('刷新市场',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).extension<IaPalette>()!.accent)),
            ),
            for (final e in st.market) ...[
              const SizedBox(height: IaSpacing.s),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.name} ${e.version}',
                            style: const TextStyle(
                                fontSize: IaType.list,
                                color: IaColors.textHi)),
                        if (e.notes.isNotEmpty)
                          Text(e.notes,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: IaColors.textLow)),
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
                        style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: IaSpacing.l),
            // ── 本地导入 ──
            const SectionLabel('本地导入'),
            const Text('粘贴单个 .plugin.js 文件的 URL 安装；或把文件放进插件目录后点上方「扫描导入」',
                style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.s),
            TextButton(
              onPressed: st.busy
                  ? null
                  : () {
                      final ctrl = TextEditingController();
                      showDialog<void>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          backgroundColor: IaColors.canvas,
                          title: const Text('从 URL 安装插件',
                              style: TextStyle(fontSize: 15)),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            style: const TextStyle(
                                fontSize: 12.5, color: IaColors.textHi),
                            decoration: const InputDecoration(
                                hintText: 'https://…/xxx.plugin.js'),
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
                                    .installFromUrl(ctrl.text);
                              },
                              child: const Text('安装'),
                            ),
                          ],
                        ),
                      );
                    },
              child: Text('从 URL 安装…',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).extension<IaPalette>()!.accent)),
            ),
          ],
        ),
      ),
    );
  }
}
