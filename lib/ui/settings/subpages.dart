/// 设置子页：存储 / 收集（含 GitHub 歌单拉取入口与提取进度）/ 关于。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_info.dart';
import '../../app/theme/design_tokens.dart';
import '../../data/daos/collect_dao.dart';
import '../../services/collect/bilibili_client.dart';
import '../../services/collect/platform_store.dart';
import '../../services/collect/youtube_client.dart';
import '../../state/collect_providers.dart';
import '../../state/diagnostics.dart';
import '../../state/enrich_controller.dart';
import '../../state/library_providers.dart';
import '../../state/scan_controller.dart';
import '../../state/settings_controller.dart';
import '../playlists/github/github_page.dart';
import '../shared/ui_kit.dart';
import 'bilibili_login_page.dart';
import 'directory_picker_page.dart';
import 'platform_search_page.dart';
import 'youtube_login_page.dart';

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

String _statusLabel(CollectStatusCol status) => switch (status) {
      CollectStatusCol.pending => '等待',
      CollectStatusCol.running => '提取中',
      CollectStatusCol.done => '完成',
      CollectStatusCol.blocked => '待处理',
      CollectStatusCol.failed => '失败',
    };

/// 提取与补全进度子页：任务实时流（真实 CollectTasks）。
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
            const _SubHeader(title: '提取进度'),
            const SizedBox(height: IaSpacing.s),
            Row(
              children: [
                Text('${tasks.length} 项任务 · 完成后自动入库',
                    style:
                        const TextStyle(fontSize: 12, color: IaColors.textLow)),
              ],
            ),
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
              const Text('当前没有进行中的任务——回到「收集」粘贴链接或拉取歌单开始',
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
            // ── 元数据补全区块（demo：音频指纹 → 在线匹配 → 封面/歌词 → 写入标签）──
            const SizedBox(height: IaSpacing.l),
            const SectionLabel('元数据补全'),
            const SizedBox(height: IaSpacing.s),
            Text('音频指纹 → 在线匹配 → 封面/歌词 → 写入标签',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            _EnrichSection(),
            const SizedBox(height: IaSpacing.l),
          ],
        ),
      ),
    );
  }
}

/// 补全运行区块：进度条 + 当前曲目 + 手动「开始补全」（扫描后亦自动驱动）。
class _EnrichSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(enrichProvider);
    final p = Theme.of(context).extension<IaPalette>()!;

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
            Text(st.running ? '${st.done}/${st.total}' : '',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
          ],
        ),
        const SizedBox(height: IaSpacing.s),
        Stack(
          children: [
            Container(height: 2, color: IaColors.hairlineStrong),
            FractionallySizedBox(
              widthFactor: st.running && st.total > 0
                  ? (st.done / st.total).clamp(0.05, 1.0)
                  : (st.running ? 0.05 : 0.0),
              child: Container(height: 2, color: p.accent),
            ),
          ],
        ),
        const SizedBox(height: IaSpacing.s),
        TextButton(
          onPressed: st.running
              ? null
              : () => ref.read(enrichProvider.notifier).runOnce(),
          child: Text(st.running ? '补全中…' : '开始补全',
              style: TextStyle(
                  fontSize: 12.5,
                  color: st.running ? IaColors.textLow : p.accent)),
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
            const SizedBox(height: IaSpacing.m),
            const Text('音乐目录可随时更改；扫描后自动入库。',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
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

/// 收集子页：A 层登录 + 站内搜索 + B 层链接提取 + 提取与补全进度入口。
class CollectSubPage extends ConsumerWidget {
  const CollectSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(collectTasksProvider).value ?? const [];
    final edge = edgeInsets(context);
    final running = tasks
        .where((t) =>
            t.status == CollectStatusCol.pending ||
            t.status == CollectStatusCol.running)
        .length;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '收集'),
            const SizedBox(height: IaSpacing.m),
            const Text('登录平台后可站内搜索；也可以直接粘贴链接提取。',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('平台登录'),
            const SizedBox(height: IaSpacing.m),
            _PlatformRow(platform: PlatformId.bilibili, label: 'B 站'),
            _PlatformRow(platform: PlatformId.youtube, label: 'YouTube'),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('GitHub 歌单'),
            const SizedBox(height: IaSpacing.m),
            BigRow(
              title: '拉取 GitHub 歌单',
              subtitle: 'JSON 契约',
              onTap: () => Navigator.of(context).push(
                  zuneRoute<void>(builder: (_) => const GithubPage())),
            ),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('粘贴链接提取'),
            const SizedBox(height: IaSpacing.m),
            const _LinkExtractForm(),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('进度'),
            const SizedBox(height: IaSpacing.m),
            Container(
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: IaColors.hairline))),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提取与补全进度',
                    style:
                        TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
                subtitle: Text(running > 0
                    ? '$running 项进行中'
                    : '当前没有进行中的任务',
                    style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
                trailing:
                    const Icon(Icons.chevron_right, color: IaColors.textLow),
                onTap: () => Navigator.of(context).push(
                    zuneRoute<void>(builder: (_) => const ExtractPage())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 独立的「提取链接」页：设置页一键直达，不必先进收集页再往下滚。
class LinkExtractPage extends ConsumerWidget {
  const LinkExtractPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(collectTasksProvider).value ?? const [];
    final edge = edgeInsets(context);
    final running = tasks
        .where((t) =>
            t.status == CollectStatusCol.pending ||
            t.status == CollectStatusCol.running)
        .length;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '提取链接'),
            const SizedBox(height: IaSpacing.m),
            const Text(
              '粘贴 B 站 / YouTube / 直链音频地址，提取完成后统一入曲库。',
              style: TextStyle(fontSize: 12.5, color: IaColors.textLow),
            ),
            const SizedBox(height: IaSpacing.xl),
            const _LinkExtractForm(),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('进度'),
            const SizedBox(height: IaSpacing.s),
            Container(
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: IaColors.hairline))),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提取与补全进度',
                    style: TextStyle(
                        fontSize: IaType.list, color: IaColors.textHi)),
                subtitle: Text(
                    running > 0 ? '$running 项进行中' : '当前没有进行中的任务',
                    style: const TextStyle(
                        fontSize: 12, color: IaColors.textLow)),
                trailing:
                    const Icon(Icons.chevron_right, color: IaColors.textLow),
                onTap: () => Navigator.of(context).push(
                    zuneRoute<void>(builder: (_) => const ExtractPage())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 平台行：登录态 + 登录/退出/站内搜索。
class _PlatformRow extends ConsumerWidget {
  const _PlatformRow({required this.platform, required this.label});

  final PlatformId platform;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(platformLoginProvider(platform)).value ?? false;
    final cookieLen =
        ref.watch(platformCookieLengthProvider(platform)).value ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.m, vertical: IaSpacing.m),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: IaColors.hairline))),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
          const Spacer(),
          Text(loggedIn ? '已登录 · ${cookieLen}B' : '未登录 · ${cookieLen}B',
              style: TextStyle(
                  fontSize: 11.5,
                  color: loggedIn
                      ? Theme.of(context).extension<IaPalette>()!.accent
                      : IaColors.textLow)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '刷新登录态',
            icon: const Icon(Icons.refresh, size: 16),
            color: IaColors.textLow,
            onPressed: () {
              ref.read(platformLoginEpochProvider.notifier).bump();
              ref.invalidate(platformLoginProvider(platform));
            },
          ),
          const SizedBox(width: IaSpacing.xs),
          OutlinedButton(
            onPressed: () =>
                loggedIn ? _manage(context, ref) : _login(context, ref),
            child: Text(loggedIn ? '管理' : '登录',
                style: const TextStyle(fontSize: 12, color: IaColors.textHi)),
          ),
        ],
      ),
    );
  }

  Future<void> _login(BuildContext context, WidgetRef ref) async {
    final page = platform == PlatformId.bilibili
        ? const BilibiliLoginPage()
        : const YoutubeLoginPage();
    await Navigator.of(context).push(zuneRoute<bool>(builder: (_) => page));
    if (!context.mounted) {
      return;
    }
    // 直接从存储读一次：区分「cookie 没落库」和「界面没刷新」。
    final len =
        (await ref.read(platformStoreProvider).cookies(platform))?.length ?? 0;
    ref.read(platformLoginEpochProvider.notifier).bump();
    ref.invalidate(platformLoginProvider(platform));
    if (context.mounted) {
      showWpToast(context,
          title: label,
          message: len > 0 ? '登录成功 · 登录态已保存' : '未保存登录态');
    }
  }

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    await showWpMenu(context, title: label, items: [
      (
        '站内搜索 · 提取',
        () => Navigator.of(context).push(zuneRoute<void>(
            builder: (_) => PlatformSearchPage(platform: platform))),
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
              content: const Text('退出后本机保存的登录凭据会被清除，需要重新扫码登录。',
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
          final store = ref.read(platformStoreProvider);
          await store.clearCookies(platform);
          await store.clearAccount(platform);
          ref.read(platformLoginEpochProvider.notifier).bump();
          ref.invalidate(platformLoginProvider(platform));
          if (context.mounted) {
            showWpToast(context, title: label, message: '已退出登录');
          }
        },
      ),
    ]);
  }
}

/// B 层粘贴链接提取：链接逐条解析 → 任务落库 → 驱动执行器。
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
              hintText: '粘贴 B 站 / YouTube / 直链音频…（多行批量）',
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
        const SizedBox(height: IaSpacing.s),
        const Text('支持：bilibili 视频页 · YouTube 视频页 · 直链音频文件。识别不了的链接会明确报错。',
            style: TextStyle(fontSize: 11, color: IaColors.textLow)),
      ],
    );
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      if (mounted) {
        showWpToast(context, title: '收集', message: '先粘贴链接');
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
        final source = _detectSource(url);
        if (source == null) {
          rejected++;
          continue;
        }
        // 标题/歌手留空——提取引擎运行时用平台协议补全真实元数据
        await api.enqueue(source, url);
        added++;
      }
      if (added > 0) {
        // 100 P 合集可能有上百个任务：只入队，下载在后台跑，避免提交按钮卡死。
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
        title: '收集',
        message: added > 0
            ? '$added 个链接进入提取队列${rejected > 0 ? ' · $rejected 个无法识别' : ''}'
            : '没有可识别的链接');
  }

  String? _detectSource(String url) {
    final u = url.toLowerCase();
    if (u.contains('bilibili.com/') ||
        u.contains('b23.tv/') ||
        BilibiliClient.bvidFrom(url) != null) {
      return 'bilibili';
    }
    if (u.contains('youtube.com/') ||
        u.contains('youtu.be/') ||
        YoutubeClient.videoIdFrom(url) != null) {
      return 'youtube';
    }
    if (u.startsWith('http') &&
        RegExp(r'\.(mp3|m4a|flac|wav|ogg|opus|aac)(\?|$)').hasMatch(u)) {
      return 'direct';
    }
    return null;
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
            const SizedBox(height: IaSpacing.m),
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
            Text(kAppVersionLabel,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: IaColors.textMid,
                    letterSpacing: 0.3)),
            const SizedBox(height: IaSpacing.xs),
          ],
        ),
      ),
    );
  }

  static String _localeName(String mode) => switch (mode) {
        LocaleMode.zh => '中文（简体）',
        LocaleMode.en => 'English',
        _ => '跟随系统',
      };

  /// 语言选择（WP 菜单）：跟随系统 / 中文（简体）/ English。
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
