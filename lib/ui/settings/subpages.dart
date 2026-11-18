/// 设置子页：存储 / 收集（平台登录与站内搜索）/ 关于。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../services/collect/platform_store.dart';
import '../../state/collect_providers.dart';
import '../../state/diagnostics.dart';
import '../../state/library_providers.dart';
import '../../state/scan_controller.dart';
import '../../state/settings_controller.dart';
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

/// 收集子页：平台登录 + 站内搜索提取。
class CollectSubPage extends ConsumerWidget {
  const CollectSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '收集'),
            const SizedBox(height: IaSpacing.m),
            const Text('登录平台后可站内搜索、批量提取。',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('平台登录'),
            const SizedBox(height: IaSpacing.m),
            _PlatformRow(platform: PlatformId.bilibili, label: 'B 站'),
            _PlatformRow(platform: PlatformId.youtube, label: 'YouTube'),
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
