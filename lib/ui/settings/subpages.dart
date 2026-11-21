/// 设置子页：存储 / 收集（平台登录与站内搜索）/ 提取与补全进度 / 关于。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_info.dart';
import '../../app/theme/design_tokens.dart';
import '../../data/daos/collect_dao.dart';
import '../../domain/entities/track.dart';
import '../../services/collect/source_plugins.dart';
import '../../state/collect_providers.dart';
import '../../state/diagnostics.dart';
import '../../state/enrich_controller.dart';
import '../../state/library_providers.dart';
import '../../state/plugin_providers.dart';
import '../../state/scan_controller.dart';
import '../../state/settings_controller.dart';
import '../shared/ui_kit.dart';
import 'directory_picker_page.dart';
import 'platform_search_page.dart';
import 'plugin_login_pages.dart';

/// 页头（返回 + 大标题 + accent 短横），四子页共用。
class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: IaSpacing.xs),
            Text(
              title,
              style: const TextStyle(
                fontSize: IaType.page,
                fontWeight: IaType.light,
                letterSpacing: IaType.titleTracking,
                color: IaColors.textHi,
              ),
            ),
          ],
        ),
        const SizedBox(height: IaSpacing.s),
        Container(
          width: 26,
          height: 2,
          color: Theme.of(context).extension<IaPalette>()!.accent,
        ),
      ],
    );
  }
}

/// 存储子页：音乐目录交互式管理（添加/移除/重扫）+ 曲库统计 + 索引状态。
class StorageSubPage extends ConsumerStatefulWidget {
  const StorageSubPage({super.key});

  @override
  ConsumerState<StorageSubPage> createState() => _StorageSubPageState();
}

class _StorageSubPageState extends ConsumerState<StorageSubPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(trackCountProvider).value ?? 0;
    final roots = ref.watch(rootsProvider).value ?? const [];
    final scan = ref.watch(scanProvider);
    final edge = edgeInsets(context);
    final p = Theme.of(context).extension<IaPalette>()!;

    Future<void> add() async {
      final ok =
          await ref.read(scanProvider.notifier).ensureAudioPermission();
      if (!ok) {
        if (context.mounted) {
          showWpToast(context, title: '存储', message: '存储权限未授予——先在系统设置中允许', isError: true);
        }
        return;
      }
      if (!context.mounted) {
        return;
      }
      final picked = await Navigator.of(context).push<String>(
          zuneRoute(builder: (_) => const DirectoryPickerPage()));
      if (picked == null) {
        return;
      }
      setState(() => _busy = true);
      String result;
      try {
        result = await ref.read(scanProvider.notifier).addRoot(picked);
      } on Object catch (e, st) {
        result = '';
        if (context.mounted) {
          // 常驻错误条：真实原因完整可读，点按关闭
          showWpToast(context, title: '存储', message: '添加目录失败：$e', isError: true);
          unawaited(ref
              .read(diagnosticsProvider.notifier)
              .record('添加目录', e, st));
        }
      }
      if (!context.mounted) {
        return;
      }
      setState(() => _busy = false);
      final err = ref.read(scanProvider).lastError;
      if (err != null) {
        showWpToast(context,
            title: '存储 · 扫描失败', message: err, isError: true);
        return;
      }
      showWpToast(context,
          title: '存储',
          message: result == 'exists'
              ? '目录已存在 · 已重新扫描'
              : '已添加目录并完成扫描');
    }

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '存储'),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('音乐目录'),
            const SizedBox(height: IaSpacing.m),
            for (final r in roots)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onLongPress: () => showWpMenu(context, title: r.path, items: [
                    (
                      '移除此目录',
                      () async {
                        await ref.read(scanProvider.notifier).removeRoot(r.id);
                        if (context.mounted) {
                          showWpToast(context, title: '存储', message: '已移除：${r.path}');
                        }
                      },
                    ),
                    (
                      '立即重扫此目录',
                      () async {
                        setState(() => _busy = true);
                        try {
                          await ref
                              .read(scanProvider.notifier)
                              .addRoot(r.path); // 已存在路径 = 重扫
                        } on Object catch (e) {
                          if (context.mounted) {
                            showWpToast(context,
                                title: '存储 · 重扫失败', message: '$e', isError: true);
                          }
                        }
                        if (!context.mounted) {
                          return;
                        }
                        setState(() => _busy = false);
                        final err = ref.read(scanProvider).lastError;
                        if (err != null) {
                          showWpToast(context,
                              title: '存储 · 扫描失败', message: err, isError: true);
                        } else {
                          showWpToast(context, title: '存储', message: '扫描完成');
                        }
                      },
                    ),
                  ]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: IaSpacing.m, vertical: IaSpacing.l),
                    decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: IaColors.hairline))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(r.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: IaType.list, color: IaColors.textHi)),
                        ),
                        const Text('音乐目录',
                            style:
                                TextStyle(fontSize: 12, color: IaColors.textLow)),
                      ],
                    ),
                  ),
                ),
              ),
            if (roots.isEmpty)
              const Text('尚未添加音乐目录——点下方按钮手动选择',
                  style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : add,
                child: Text(_busy ? '扫描中…' : '＋ 添加音乐目录',
                    style: const TextStyle(fontSize: 13, color: IaColors.textHi)),
              ),
            ),
            if (scan.scanning) ...[
              const SizedBox(height: IaSpacing.m),
              Text(scan.total > 0
                  ? '扫描中 ${scan.done}/${scan.total}'
                  : '扫描中…',
                  style: TextStyle(fontSize: 12, color: p.accent)),
              const SizedBox(height: IaSpacing.s),
              Stack(
                children: [
                  Container(height: 2, color: IaColors.hairlineStrong),
                  FractionallySizedBox(
                    widthFactor: scan.total > 0
                        ? (scan.done / scan.total).clamp(0.0, 1.0)
                        : 0.0,
                    child: Container(height: 2, color: p.accent),
                  ),
                ],
              ),
            ],
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('曲库统计'),
            const SizedBox(height: IaSpacing.m),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.l),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline))),
              child: Row(
                children: [
                  const Text('可用曲目',
                      style:
                          TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
                  const Spacer(),
                  Text('$count 首',
                      style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.s),
            Text(scan.lastSummary.isEmpty
                ? 'FTS 拼音索引就绪'
                : '上次扫描：${scan.lastSummary}',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy || scan.scanning
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await ref.read(scanProvider.notifier).rescanAll();
                        } on Object catch (e) {
                          if (context.mounted) {
                            showWpToast(context,
                                title: '存储 · 重扫失败', message: '$e', isError: true);
                          }
                        }
                        if (!context.mounted) {
                          return;
                        }
                        setState(() => _busy = false);
                        final err = ref.read(scanProvider).lastError;
                        if (err != null) {
                          showWpToast(context,
                              title: '存储 · 扫描失败', message: err, isError: true);
                        } else {
                          showWpToast(context, title: '存储', message: '全量重扫完成');
                        }
                      },
                child: const Text('⟳ 全量重扫',
                    style: TextStyle(fontSize: 13, color: IaColors.textHi)),
              ),
            ),
            // ── 诊断（常驻）：任何来源的最近错误都钉在这里，可复制/清除 ──
            const _DiagnosticsBlock(),
          ],
        ),
      ),
    );
  }
}

/// 最近错误常驻区块（跨重启持久化）：完整文本 + 复制 + 清除。
class _DiagnosticsBlock extends ConsumerWidget {
  const _DiagnosticsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(diagnosticsProvider);
    if (entry == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: IaSpacing.xl),
      padding: const EdgeInsets.all(IaSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: IaColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('诊断 · 最近一次错误',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: IaType.semibold,
                  letterSpacing: 1.2,
                  color: IaColors.error)),
          const SizedBox(height: IaSpacing.xs),
          Text(
              '${entry.at.month}-${entry.at.day} '
              '${entry.at.hour}:${entry.at.minute.toString().padLeft(2, '0')}'
              ' · ${entry.source}',
              style: const TextStyle(fontSize: 11, color: IaColors.textLow)),
          const SizedBox(height: IaSpacing.s),
          SelectableText(entry.detail,
              style: const TextStyle(
                  fontSize: 12, color: IaColors.textHi, height: 1.5)),
          const SizedBox(height: IaSpacing.m),
          Row(children: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: '${entry.source}: ${entry.detail}'));
                if (context.mounted) {
                  showWpToast(context, title: '诊断', message: '已复制到剪贴板');
                }
              },
              child: const Text('复制',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textHi)),
            ),
            const SizedBox(width: IaSpacing.m),
            TextButton(
              onPressed: () => ref.read(diagnosticsProvider.notifier).clear(),
              child: const Text('清除',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            ),
          ]),
          const SizedBox(height: IaSpacing.xs),
        ],
      ),
    );
  }
}

String _statusLabel(CollectStatusCol status) => switch (status) {
      CollectStatusCol.pending => '等待',
      CollectStatusCol.running => '提取中',
      CollectStatusCol.done => '完成',
      CollectStatusCol.blocked => '待处理',
      CollectStatusCol.failed => '失败',
    };

/// 提取与补全进度子页：任务实时流 + 元数据补全（唯一入口 = 设置页直达）。
class ExtractPage extends ConsumerWidget {
  const ExtractPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(collectTasksProvider).value ?? const [];
    final edge = edgeInsets(context);
    final p = Theme.of(context).extension<IaPalette>()!;
    final failed =
        tasks.where((t) => t.status == CollectStatusCol.failed).length;
    final pending =
        tasks.where((t) => t.status == CollectStatusCol.pending).length;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '提取与补全进度'),
            const SizedBox(height: IaSpacing.s),
            const SectionLabel('提取进度'),
            const SizedBox(height: IaSpacing.s),
            Text('${tasks.length} 项任务 · 完成后自动入库',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
            if (pending > 0 || failed > 0)
              Row(
                children: [
                  if (pending > 0)
                    TextButton(
                      onPressed: () =>
                          unawaited(ref.read(collectTasksApiProvider).drive()),
                      child: Text('继续 $pending',
                          style: TextStyle(fontSize: 12, color: p.accent)),
                    ),
                  if (failed > 0)
                    TextButton(
                      onPressed: () async {
                        final api = ref.read(collectTasksApiProvider);
                        final n = await api.retryFailed();
                        unawaited(api.drive());
                        if (context.mounted) {
                          showWpToast(context,
                              title: '提取', message: '已重试 $n 个失败任务');
                        }
                      },
                      child: Text('重试失败 $failed',
                          style: TextStyle(fontSize: 12, color: p.accent)),
                    ),
                ],
              ),
            const SizedBox(height: IaSpacing.l),
            if (tasks.isEmpty)
              const Text('当前没有进行中的任务——提取与补全都在后台自动运行',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            for (final t in tasks) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.m, vertical: IaSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.title.isEmpty ? t.url : t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: IaType.list,
                                  color: t.status == CollectStatusCol.failed
                                      ? IaColors.error
                                      : IaColors.textHi)),
                        ),
                        Text(
                            '${t.source} · ${_statusLabel(t.status)} · '
                            '${t.status == CollectStatusCol.done ? 100 : t.progress}%',
                            style: TextStyle(
                                fontSize: 12,
                                color: t.status == CollectStatusCol.failed
                                    ? IaColors.error
                                    : t.status == CollectStatusCol.done
                                        ? p.accent
                                        : IaColors.textLow)),
                      ],
                    ),
                    const SizedBox(height: IaSpacing.s),
                    Stack(
                      children: [
                        Container(height: 2, color: IaColors.hairlineStrong),
                        FractionallySizedBox(
                          widthFactor: (t.progress / 100).clamp(0.0, 1.0),
                          child: Container(
                            height: 2,
                            color: t.status == CollectStatusCol.failed
                                ? IaColors.error
                                : p.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: IaSpacing.m),
            ],
            // ── 补全进度区块：歌名/歌手/歌词 三条独立阶段进度（持久化） ──
            const SizedBox(height: IaSpacing.l),
            const SectionLabel('补全进度（元数据三阶段）'),
            const SizedBox(height: IaSpacing.s),
            Text('缺失歌名 / 歌手的曲目自动入队，逐条给出三阶段结论；进度已落库，中断重启不从头',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            const _EnrichSection(),
            const SizedBox(height: IaSpacing.l),
          ],
        ),
      ),
    );
  }
}

/// 补全进度区块：三条独立阶段进度条（歌名/歌手/歌词）+ 当前曲目 +
/// 手动「开始补全」（清零失败计数重试）。进度数据 = tracks 行直读（持久化）。
class _EnrichSection extends ConsumerWidget {
  const _EnrichSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(enrichProvider);
    final stages = ref.watch(enrichStagesProvider).value ?? const <EnrichStage>[];
    final p = Theme.of(context).extension<IaPalette>()!;

    Widget stageRow(EnrichStage s) {
      final complete = s.total > 0 && s.done >= s.total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.label,
                      style: const TextStyle(
                          fontSize: IaType.list, color: IaColors.textHi)),
                ),
                Text('${s.done}/${s.total}',
                    style: TextStyle(
                        fontSize: 12,
                        color: complete ? p.accent : IaColors.textLow)),
              ],
            ),
            const SizedBox(height: IaSpacing.s),
            Stack(
              children: [
                Container(height: 2, color: IaColors.hairlineStrong),
                FractionallySizedBox(
                  widthFactor: s.fraction,
                  child: Container(height: 2, color: p.accent),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                st.running
                    ? (st.currentTitle.isEmpty ? '补全中…' : '补全中 · ${st.currentTitle}')
                    : (st.lastSummary.isEmpty ? '队列空闲 · 扫描完成后自动运行' : st.lastSummary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: IaType.list, color: IaColors.textHi),
              ),
            ),
          ],
        ),
        const SizedBox(height: IaSpacing.m),
        if (stages.isEmpty)
          const Text('进度读取中…',
              style: TextStyle(fontSize: 12, color: IaColors.textLow)),
        for (final s in stages) stageRow(s),
        const SizedBox(height: IaSpacing.s),
        TextButton(
          onPressed: st.running
              ? null
              : () => ref.read(enrichProvider.notifier).runOnce(reset: true),
          child: Text(st.running ? '补全中…' : '开始补全（重试全部失败项）',
              style: TextStyle(
                  fontSize: 12.5,
                  color: st.running ? IaColors.textLow : p.accent)),
        ),
      ],
    );
  }
}

/// 收集子页：音频源插件登录 + 站内搜索提取。
class CollectSubPage extends ConsumerWidget {
  const CollectSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);
    final handles = ref.watch(sourceHandlesProvider).value ?? const [];
    final p = Theme.of(context).extension<IaPalette>()!;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '收集'),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('音频源插件'),
            if (handles.isEmpty) ...[
              const Text('还没有启用的音频源插件——外部平台能力全部来自插件',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
              const SizedBox(height: IaSpacing.m),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                    zuneRoute<void>(builder: (_) => const PluginsPage())),
                child: Text('去「插件」安装',
                    style: TextStyle(fontSize: 12.5, color: p.accent)),
              ),
            ],
            for (final h in handles) _SourceRow(plugin: h),
            const SizedBox(height: IaSpacing.l),
            const Text(
                '平台知识 100% 在插件里：安装/卸载/启停都在「设置 · 插件」，凭据只存在插件沙箱。',
                style: TextStyle(fontSize: 11, color: IaColors.textLow)),
          ],
        ),
      ),
    );
  }
}

/// 音频源插件行：登录态 + 登录/退出/站内搜索（按 authKind 打开对应登录页）。
class _SourceRow extends ConsumerWidget {
  const _SourceRow({required this.plugin});

  final SourcePluginHandle plugin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth =
        ref.watch(sourceAuthStatusProvider(plugin.id)).value;
    final loggedIn = auth?.loggedIn ?? false;
    final account = auth?.account ?? '';
    final kind = ref.watch(sourceAuthKindProvider(plugin.id)).value ?? 'none';

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.m, vertical: IaSpacing.m),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: IaColors.hairline))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plugin.name,
                    style: const TextStyle(
                        fontSize: IaType.list, color: IaColors.textHi)),
                const SizedBox(height: 2),
                Text(
                  loggedIn
                      ? (account.isEmpty ? '已登录' : '已登录 · $account')
                      : (kind == 'none' ? '无需登录' : '未登录'),
                  style: TextStyle(
                      fontSize: 11.5,
                      color: loggedIn
                          ? Theme.of(context).extension<IaPalette>()!.accent
                          : IaColors.textLow),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => loggedIn
                ? _manage(context, ref)
                : (kind == 'none'
                    ? _manage(context, ref)
                    : _login(context, ref)),
            child: Text(
                loggedIn
                    ? '管理'
                    : (kind == 'none' ? '站内搜索' : '登录'),
                style: const TextStyle(fontSize: 12, color: IaColors.textHi)),
          ),
        ],
      ),
    );
  }

  Future<void> _login(BuildContext context, WidgetRef ref) async {
    final kind = await ref.read(sourceAuthKindProvider(plugin.id).future);
    if (!context.mounted) {
      return;
    }
    final page = switch (kind) {
      'cookie' => PluginCookieLoginPage(pluginId: plugin.id),
      _ => PluginQrLoginPage(pluginId: plugin.id),
    };
    await Navigator.of(context).push(zuneRoute<bool>(builder: (_) => page));
    if (!context.mounted) {
      return;
    }
    ref.read(sourceEpochProvider.notifier).bump();
    final st = await ref.read(sourceAuthStatusProvider(plugin.id).future);
    if (!context.mounted) {
      return;
    }
    showWpToast(context,
        title: plugin.name,
        message: st.loggedIn ? '登录成功 · 凭据已入插件沙箱' : '未保存登录态');
  }

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    await showWpMenu(context, title: plugin.name, items: [
      (
        '站内搜索 · 提取',
        () => Navigator.of(context).push(zuneRoute<void>(
            builder: (_) => PlatformSearchPage(
                pluginId: plugin.id, name: plugin.name))),
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
          await plugin.authLogout();
          ref.read(sourceEpochProvider.notifier).bump();
          if (context.mounted) {
            showWpToast(context, title: plugin.name, message: '已退出登录');
          }
        },
      ),
    ]);
  }
}

/// 日志追踪区块（关于页）：开关 + 一键复制追踪期全部错误日志。
class _TraceLogBlock extends ConsumerWidget {
  const _TraceLogBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trace = ref.watch(traceLogProvider);
    final p = Theme.of(context).extension<IaPalette>()!;

    return Container(
      padding: const EdgeInsets.all(IaSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(
            color: trace.enabled
                ? p.accent.withValues(alpha: 0.5)
                : IaColors.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('日志追踪',
                    style: TextStyle(
                        fontSize: IaType.list, color: IaColors.textHi)),
              ),
              Switch(
                value: trace.enabled,
                onChanged: (v) =>
                    ref.read(traceLogProvider.notifier).setEnabled(v),
              ),
            ],
          ),
          Text(
            trace.enabled
                ? '开启中——所有错误（框架 / 未捕获 / 链路）实时入册，上限 200 条，跨重启保留'
                : '开启后记录所有错误日志，用于排查问题；关闭期间不采集',
            style: const TextStyle(fontSize: 11, color: IaColors.textLow),
          ),
          if (trace.enabled) ...[
            const SizedBox(height: IaSpacing.m),
            Row(
              children: [
                Text('${trace.entries.length} 条日志',
                    style: TextStyle(fontSize: 12, color: p.accent)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final text =
                        ref.read(traceLogProvider.notifier).copyText();
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      showWpToast(context,
                          title: '日志追踪', message: '已复制全部错误日志');
                    }
                  },
                  child: Text('一键复制',
                      style: TextStyle(fontSize: 12, color: p.accent)),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(traceLogProvider.notifier).clear(),
                  child: const Text('清除',
                      style: TextStyle(fontSize: 12, color: IaColors.textLow)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

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
            const _SubHeader(title: '插件'),
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
            for (final p in st.installed) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: IaSpacing.s),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p.manifest.name} ${p.manifest.version}',
                              style: const TextStyle(
                                  fontSize: IaType.list,
                                  color: IaColors.textHi)),
                          const SizedBox(height: 2),
                          Text(
                            '${p.manifest.id} · ${p.manifest.capabilities.join("/")}'
                            '${p.manifest.author.isEmpty ? '' : ' · ${p.manifest.author}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: IaColors.textLow),
                          ),
                        ],
                      ),
                    ),
                    Switch(
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
                          style: TextStyle(
                              fontSize: 12, color: IaColors.error)),
                    ),
                  ],
                ),
              ),
            ],
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

/// 独立的「从链接提取」页：搜索页直达，粘贴链接入提取队列
/// （进度统一在「设置 · 提取与补全进度」查看）。
class LinkExtractPage extends ConsumerWidget {
  const LinkExtractPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: const [
            _SubHeader(title: '从链接提取'),
            SizedBox(height: IaSpacing.xl),
            _LinkExtractForm(),
          ],
        ),
      ),
    );
  }
}

/// 关于子页。
class AboutSubPage extends ConsumerWidget {
  const AboutSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '关于'),
            const SizedBox(height: IaSpacing.xl),
            Text(kAppName,
                style: const TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    letterSpacing: IaType.titleTracking,
                    color: IaColors.textHi)),
            const SizedBox(height: IaSpacing.s),
            Text(kAppTagline,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.5, color: IaColors.textMid)),
            const SizedBox(height: IaSpacing.xl),
            _InfoRow(label: '版本', value: kAppVersionLabel),
            _InfoRow(label: '版本号', value: '$kAppVersionCode'),
            _InfoRow(label: '平台', value: kAppPlatform),
            const SizedBox(height: IaSpacing.xl),
            const _TraceLogBlock(),
            const SizedBox(height: IaSpacing.xl),
            InkWell(
              onTap: () => _languageMenu(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.m, vertical: IaSpacing.l),
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: IaColors.hairline))),
                child: Row(
                  children: [
                    const Text('语言',
                        style: TextStyle(
                            fontSize: IaType.list, color: IaColors.textHi)),
                    const Spacer(),
                    Text(_localeName(ref.watch(settingsProvider).locale),
                        style:
                            const TextStyle(fontSize: 12, color: IaColors.textLow)),
                    const SizedBox(width: IaSpacing.xs),
                    const Icon(Icons.chevron_right,
                        size: 14, color: IaColors.textLow),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => _replayOnboarding(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.m, vertical: IaSpacing.l),
                child: const Row(
                  children: [
                    Text('重播开箱仪式',
                        style: TextStyle(
                            fontSize: IaType.list, color: IaColors.textHi)),
                    Spacer(),
                    Text('选色 → 文件夹',
                        style: TextStyle(fontSize: 12, color: IaColors.textLow)),
                    SizedBox(width: IaSpacing.xs),
                    Icon(Icons.chevron_right,
                        size: 14, color: IaColors.textLow),
                  ],
                ),
              ),
            ),
            const SizedBox(height: IaSpacing.xl),
          ],
        ),
      ),
    );
  }

  static String _localeName(String mode) => switch (mode) {
        LocaleMode.zh => '中文（简体）',
        LocaleMode.en => 'English',
        _ => '跟随系统',
      };  /// 语言选择（WP 菜单）：跟随系统 / 中文（简体）/ English。
  void _languageMenu(BuildContext context, WidgetRef ref) {
    final cur = ref.read(settingsProvider).locale;
    showWpMenu(context, title: '语言', items: [
      for (final (mode, name) in const [
        (LocaleMode.system, '跟随系统'),
        (LocaleMode.zh, '中文（简体）'),
        (LocaleMode.en, 'English'),
      ])
        (
          mode == cur ? '✓ $name' : name,
          () => ref.read(settingsProvider.notifier).setLocale(mode),
        ),
    ]);
  }

  /// 重播开箱仪式：清守卫位并回到首页（根级 home 切换即回 OnboardingPage）。
  Future<void> _replayOnboarding(BuildContext context, WidgetRef ref) async {
    await ref.read(settingsProvider.notifier).resetOnboarding();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// 关于页信息行（label + value）。
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.m, vertical: IaSpacing.l),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: IaColors.hairline))),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: IaType.list, color: IaColors.textHi)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, color: IaColors.textLow)),
        ],
      ),
    );
  }
}

/// 从链接提取表单：链接逐条解析 → 任务落库 → 驱动执行器。
class _LinkExtractForm extends ConsumerStatefulWidget {
  const _LinkExtractForm();

  @override
  ConsumerState<_LinkExtractForm> createState() => _LinkExtractFormState();
}

class _LinkExtractFormState extends ConsumerState<_LinkExtractForm> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: IaSpacing.m, vertical: IaSpacing.s),
          decoration:
              BoxDecoration(border: Border.all(color: IaColors.hairlineStrong)),
          child: TextField(
            controller: _ctrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13, color: IaColors.textHi),
            decoration: const InputDecoration(
              hintText: '粘贴任意音频源插件支持的链接…（多行批量）',
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: IaSpacing.s),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '解析中…' : '提取',
                style: const TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      if (mounted) {
        showWpToast(context, title: '提取', message: '先粘贴链接');
      }
      return;
    }
    setState(() => _submitting = true);
    final api = ref.read(collectTasksApiProvider);
    var added = 0;
    var rejected = 0;
    try {
      for (final line in raw.split(RegExp(r'[\s]+'))) {
        final url = line.trim();
        if (url.isEmpty) {
          continue;
        }
        final source = await api.routeSource(url);
        if (source == null) {
          rejected++;
          continue;
        }
        // 标题/歌手留空——提取引擎运行时用插件协议补全真实元数据
        await api.enqueue(source, url);
        added++;
      }
      if (added > 0) {
        // 合集可能有上百个任务：只入队，下载在后台跑，避免提交按钮卡死。
        // 重复链接虽不重复入队，也要驱动一轮——僵尸 running 任务由此获得回收。
        unawaited(api.drive());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
    if (!mounted) {
      return;
    }
    if (added > 0) {
      _ctrl.clear();
    }
    showWpToast(context,
        title: '提取',
        message: added > 0
            ? '$added 个链接进入提取队列${rejected > 0 ? ' · $rejected 个无法识别' : ''}'
            : '没有可识别的链接');
  }
}
