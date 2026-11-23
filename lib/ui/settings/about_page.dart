/// 关于子页：应用信息（版本读安装包元数据）+ 日志追踪 + 语言 + 重播开箱。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_info.dart';
import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../state/diagnostics.dart';
import '../../state/settings_controller.dart';
import '../shared/sub_header.dart';
import '../shared/ui_kit.dart';

/// 关于子页。
class AboutSubPage extends ConsumerWidget {
  const AboutSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);
    // 版本读安装包元数据（pubspec version 的构建产物）；加载未完成显示占位
    final pkg = ref.watch(packageInfoProvider).value;
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const SubHeader(title: '关于'),
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
            _InfoRow(
                label: '版本',
                value: pkg == null
                    ? '…'
                    : 'v${pkg.version} (${pkg.buildNumber})'),
            _InfoRow(label: '版本号', value: pkg?.buildNumber ?? '…'),
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
              WpSwitch(
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
            const SizedBox(height: IaSpacing.s),
            Builder(builder: (context) {
              final path = ref.watch(logFilePathProvider).value;
              return Text(
                path == null ? '日志文件准备中…' : '文件：$path（≤100MB 滚动）',
                style: const TextStyle(
                    fontSize: 10.5, color: IaColors.textLow),
              );
            }),
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
