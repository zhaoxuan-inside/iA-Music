/// 关于子页：语言（置顶）+ 应用信息（版本读安装包元数据）+
/// 诊断日志（全 App 唯一日志出口）。
///
/// 唯一入口 = 设置页直达；风格与 Hub 页同基线（PageHeader 固定页头，
/// 无返回钮——返回走系统手势）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_info.dart';
import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../state/diagnostics.dart';
import '../../state/settings_controller.dart';
import '../shared/ui_kit.dart';

/// 关于子页。
class AboutSubPage extends ConsumerWidget {
  const AboutSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 版本读安装包元数据（pubspec version 的构建产物）；加载未完成显示占位
    final pkg = ref.watch(packageInfoProvider).value;
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: HubPage(
        header: const PageHeader(
          kicker: '应用',
          title: '关于',
          subtitle: '语言 · 版本 · 日志',
        ),
        children: [
          Text(kAppName,
              style: TextStyle(
                  fontSize: IaType.page,
                  fontWeight: IaType.light,
                  letterSpacing: IaType.titleTracking,
                  color: IaColors.textHi)),
          const SizedBox(height: IaSpacing.s),
          Text(kAppTagline,
              style: TextStyle(
                  fontSize: 14, height: 1.5, color: IaColors.textMid)),
          const SizedBox(height: IaSpacing.xl),
          InkWell(
            onTap: () => _languageMenu(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.l),
              decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: IaColors.hairline))),
              child: Row(
                children: [
                  Text('语言',
                      style: TextStyle(
                          fontSize: IaType.list, color: IaColors.textHi)),
                  const Spacer(),
                  Text(_localeName(ref.watch(settingsProvider).locale),
                      style:
                          TextStyle(fontSize: 13.5, color: IaColors.textLow)),
                  const SizedBox(width: IaSpacing.xs),
                  Icon(Icons.chevron_right,
                      size: 14, color: IaColors.textLow),
                ],
              ),
            ),
          ),
          _InfoRow(
              label: '版本',
              value: pkg == null
                  ? '…'
                  : 'v${pkg.version} (${pkg.buildNumber})'),
          _InfoRow(label: '平台', value: kAppPlatform),
          const SizedBox(height: IaSpacing.xl),
          // ── 诊断日志（全 App 唯一出口）：日志开关 + 条数 + 复制/清除 ──
          const _LogBlock(),
          const SizedBox(height: IaSpacing.xl),
        ],
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
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: IaColors.hairline))),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: IaType.list, color: IaColors.textHi)),
          const Spacer(),
          Text(value,
              style:
                  TextStyle(fontSize: 13.5, color: IaColors.textLow)),
        ],
      ),
    );
  }
}

/// 诊断日志区块（关于页 · 全 App 唯一日志出口）：日志开关 + 条数 +
/// 复制/清除（唯一一套按钮；不展示日志详情——详情随「复制」带走）。
/// 有未清除错误时边框转红提示。
class _LogBlock extends ConsumerWidget {
  const _LogBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trace = ref.watch(traceLogProvider);
    final hasError = ref.watch(diagnosticsProvider) != null;
    final p = Theme.of(context).extension<IaPalette>()!;

    return Container(
      padding: const EdgeInsets.all(IaSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(
            color: hasError
                ? IaColors.error.withValues(alpha: 0.5)
                : trace.enabled
                    ? p.accent.withValues(alpha: 0.5)
                    : IaColors.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('日志',
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
          if (trace.enabled) ...[
            const SizedBox(height: IaSpacing.m),
            Row(
              children: [
                Text('${trace.entries.length} 条日志',
                    style: TextStyle(fontSize: 13.5, color: p.accent)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final text =
                        ref.read(traceLogProvider.notifier).copyText();
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      showWpToast(context,
                          title: '日志', message: '已复制全部错误日志');
                    }
                  },
                  child: Text('复制',
                      style: TextStyle(fontSize: 13.5, color: p.accent)),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(traceLogProvider.notifier).clear(),
                  child: Text('清除',
                      style: TextStyle(fontSize: 13.5, color: IaColors.textLow)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
