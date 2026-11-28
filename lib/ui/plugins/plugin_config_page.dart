/// 插件配置页：磁贴点入——清单信息 / 启停 / 音频源登录态 / 卸载。
/// 名称与版本分行显示；卸载成功后插件从注册表消失，本页自动退回。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';
import '../../state/plugin_providers.dart';
import '../routing/app_routes.dart' show openPlatformSearch;
import '../shared/ui_kit.dart';
import 'plugin_login_pages.dart';

class PluginConfigPage extends ConsumerStatefulWidget {
  const PluginConfigPage({required this.pluginId, super.key});

  final String pluginId;

  @override
  ConsumerState<PluginConfigPage> createState() => _PluginConfigPageState();
}

class _PluginConfigPageState extends ConsumerState<PluginConfigPage> {
  bool _popped = false;

  /// 动作行：细体大字 + 箭头（BigRow 变体，支持 error 色 / busy 失效）。
  Widget _actionRow(String title, {required VoidCallback? onTap, Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: IaColors.hairline))),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: IaType.light,
                      color: color ?? IaColors.textHi)),
            ),
            const SizedBox(width: IaSpacing.m),
            Icon(Icons.chevron_right, size: 18, color: IaColors.textLow),
          ],
        ),
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
        () => openPlatformSearch(context, handle.id, handle.name),
      ),
      (
        '退出登录',
        () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: IaColors.canvas,
              title: Text('退出登录',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: IaType.light,
                      color: IaColors.textHi)),
              content: Text('退出后本机保存的登录凭据会被清除，需要重新登录。',
                  style: TextStyle(fontSize: 14.5, color: IaColors.textMid)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('取消',
                      style: TextStyle(fontSize: 14.5, color: IaColors.textMid)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('退出登录',
                      style: TextStyle(fontSize: 14.5, color: IaColors.error)),
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

  /// 卸载（确认后执行）；插件从注册表消失 → build 检测不到即自动退回。
  Future<void> _uninstall(InstalledPlugin p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IaColors.canvas,
        title: Text('卸载 ${p.manifest.name}',
            style: TextStyle(
                fontSize: 22,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        content: Text('插件文件与登录凭据沙箱都会被删除。',
            style: TextStyle(fontSize: 14.5, color: IaColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消',
                style: TextStyle(fontSize: 14.5, color: IaColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('卸载',
                style: TextStyle(fontSize: 14.5, color: IaColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await ref.read(pluginsProvider.notifier).uninstall(p.manifest.id);
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(pluginsProvider);
    final p = st.installed
        .where((x) => x.manifest.id == widget.pluginId)
        .firstOrNull;
    if (p == null) {
      // 已卸载（或刚进页数据未就绪）：等一帧仍在再退回，避免误弹
      if (!_popped && st.installed.isNotEmpty) {
        _popped = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
      return Scaffold(backgroundColor: IaColors.canvas);
    }
    final palette = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);
    final isSource = p.manifest.activeCapabilities.contains('source');
    final auth = isSource
        ? ref.watch(sourceAuthStatusProvider(p.manifest.id)).value
        : null;
    final kind =
        isSource ? ref.watch(sourceAuthKindProvider(p.manifest.id)).value ?? 'none' : 'none';
    final loggedIn = auth?.loggedIn ?? false;
    final account = auth?.account ?? '';

    final meta = <(String, String)>[
      ('ID', p.manifest.id),
      ('能力', p.manifest.capabilities.join(' / ')),
      if (p.manifest.author.isNotEmpty) ('作者', p.manifest.author),
      ('装于', p.installedAt.toLocal().toString().split('.').first),
    ];

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            PageHeader(
              kicker: '插件',
              title: p.manifest.name,
              subtitle: 'v${p.manifest.version} · API ${p.manifest.api}',
            ),
            const SizedBox(height: IaSpacing.xl),
            // ── 清单信息 ──
            const SectionLabel('信息'),
            const SizedBox(height: IaSpacing.s),
            for (final (k, v) in meta)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(k,
                          style: TextStyle(
                              fontSize: 13.5, color: IaColors.textLow)),
                    ),
                    Expanded(
                      child: Text(v,
                          style: TextStyle(
                              fontSize: 14, color: IaColors.textHi)),
                    ),
                  ],
                ),
              ),
            // ── 音频源登录（source 插件专属；登录是插件能力，宿主只做入口）──
            if (isSource && p.enabled) ...[
              const SizedBox(height: IaSpacing.xl),
              const SectionLabel('音频源'),
              const SizedBox(height: IaSpacing.s),
              Text(
                loggedIn
                    ? (account.isEmpty ? '已登录' : '已登录 · $account')
                    : (kind == 'none' ? '无需登录' : '未登录'),
                style: TextStyle(
                    fontSize: 14,
                    color: loggedIn ? palette.accent : IaColors.textLow),
              ),
              const SizedBox(height: IaSpacing.s),
              _actionRow(
                loggedIn ? '管理' : (kind == 'none' ? '站内搜索' : '登录'),
                onTap: st.busy
                    ? null
                    : () => loggedIn || kind == 'none'
                        ? unawaited(_sourceManage(p))
                        : unawaited(_sourceLogin(p)),
              ),
            ],
            // ── 启停 ──
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('启停'),
            const SizedBox(height: IaSpacing.s),
            Container(
              padding: const EdgeInsets.symmetric(vertical: IaSpacing.m),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline))),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.enabled ? '已启用' : '已禁用',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: IaType.light,
                          color: IaColors.textHi),
                    ),
                  ),
                  WpSwitch(
                    value: p.enabled,
                    onChanged: st.busy
                        ? null
                        : (v) => ref
                            .read(pluginsProvider.notifier)
                            .setEnabled(p.manifest.id, v),
                  ),
                ],
              ),
            ),
            // ── 卸载 ──
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('危险区'),
            const SizedBox(height: IaSpacing.s),
            _actionRow(
              '卸载插件',
              color: IaColors.error,
              onTap: st.busy ? null : () => unawaited(_uninstall(p)),
            ),
          ],
        ),
      ),
    );
  }
}
