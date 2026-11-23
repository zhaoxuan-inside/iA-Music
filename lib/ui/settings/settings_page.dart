/// 设置页（菜单 → 各项独立子页）：主题色 / 存储 / 插件 / 关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
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
    final taskCount = ref.watch(collectTasksProvider).value?.length ?? 0;

    return HubPage(
      header: const PageHeader(
        kicker: '应用',
        title: '设置',
        subtitle: '个性化 · 存储 · 提取 · 关于',
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
          title: '提取与补全进度',
          subtitle: taskCount > 0 ? '$taskCount 项任务' : '后台自动运行',
          onTap: () => Navigator.of(context).push(
              zuneRoute<void>(builder: (_) => const ExtractPage())),
        ),
        BigRow(
          title: '插件',
          subtitle: '市场 · 本地导入 · 外部平台能力',
          onTap: () => Navigator.of(context).push(
              zuneRoute<void>(builder: (_) => const PluginsPage())),
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
    final accentName = kWpPalette
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
                // 自定义取色入口：彩虹圆盘；accent 不在色板时即当前自定义色
                InkWell(
                  onTap: () => Navigator.of(context).push(zuneRoute<void>(
                      builder: (_) => const AccentPickerPage())),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFE51400),
                          Color(0xFFA4C400),
                          Color(0xFF008A00),
                          Color(0xFF00ABA9),
                          Color(0xFF1BA1E2),
                          Color(0xFFA200FF),
                          Color(0xFFF472D0),
                          Color(0xFFE51400),
                        ],
                      ),
                      border: accentName == null
                          ? Border.all(color: IaColors.textHi, width: 2)
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    alignment: Alignment.center,
                    child: accentName == null
                        ? const Icon(Icons.check,
                            size: 20, color: IaColors.onAccent)
                        : const Icon(Icons.colorize,
                            size: 18, color: IaColors.onAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: IaSpacing.xl),
            Text('当前：${accentName ?? '自定义'}',
                style: const TextStyle(fontSize: 12.5, color: IaColors.textLow)),
          ],
        ),
      ),
    );
  }
}

/// 自定义主题色：SV 色域 + 色相条，任意色即时生效（拖动预览、松手落盘）。
class AccentPickerPage extends ConsumerStatefulWidget {
  const AccentPickerPage({super.key});

  @override
  ConsumerState<AccentPickerPage> createState() => _AccentPickerPageState();
}

class _AccentPickerPageState extends ConsumerState<AccentPickerPage> {
  late HSVColor _hsv =
      HSVColor.fromColor(ref.read(settingsProvider).accent);

  void _applyDrag(HSVColor hsv) {
    setState(() => _hsv = hsv);
    ref.read(settingsProvider.notifier).previewAccent(hsv.toColor());
  }

  void _applyFinal(HSVColor hsv) {
    setState(() => _hsv = hsv);
    ref.read(settingsProvider.notifier).setAccent(hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final edge = edgeInsets(context);
    final color = _hsv.toColor();

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
              title: '自定义颜色',
              subtitle: '色域内点按或拖动，全局即时变色',
            ),
            const SizedBox(height: IaSpacing.xl),
            // SV 色域：底色 = 当前色相；白→透明横渐 + 透明→黑竖渐
            AspectRatio(
              aspectRatio: 1.6,
              child: LayoutBuilder(
                builder: (context, box) {
                  void pick(Offset local, {required bool persist}) {
                    final hsv = _hsv
                        .withSaturation((local.dx / box.maxWidth).clamp(0.0, 1.0))
                        .withValue(1 - (local.dy / box.maxHeight).clamp(0.0, 1.0));
                    if (persist) {
                      _applyFinal(hsv);
                    } else {
                      _applyDrag(hsv);
                    }
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => pick(d.localPosition, persist: true),
                    onPanStart: (d) => pick(d.localPosition, persist: false),
                    onPanUpdate: (d) => pick(d.localPosition, persist: false),
                    onPanEnd: (_) => _applyFinal(_hsv),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: HSVColor.fromColor(_hsv.toColor()).withSaturation(1).withValue(1).toColor()),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Colors.white, Colors.transparent],
                            ),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black],
                            ),
                          ),
                        ),
                        // 当前取色点
                        Align(
                          alignment: Alignment(
                            _hsv.saturation * 2 - 1,
                            (1 - _hsv.value) * 2 - 1,
                          ),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(color: IaColors.onAccent, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: IaSpacing.xl),
            // 色相条
            LayoutBuilder(
              builder: (context, box) {
                void pickHue(Offset local, {required bool persist}) {
                  final hsv = _hsv.withHue((local.dx / box.maxWidth).clamp(0.0, 0.9999));
                  if (persist) {
                    _applyFinal(hsv);
                  } else {
                    _applyDrag(hsv);
                  }
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => pickHue(d.localPosition, persist: true),
                  onPanStart: (d) => pickHue(d.localPosition, persist: false),
                  onPanUpdate: (d) => pickHue(d.localPosition, persist: false),
                  onPanEnd: (_) => _applyFinal(_hsv),
                  child: SizedBox(
                    height: 36,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  for (var h = 0; h <= 360; h += 30)
                                    HSVColor.fromAHSV(1, h / 360, 1, 1)
                                        .toColor(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(_hsv.hue * 2 - 1, 0),
                          child: Container(
                            width: 4,
                            height: 36,
                            color: IaColors.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: IaSpacing.xl),
            // 当前色预览 + hex
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: IaColors.hairlineStrong),
                  ),
                ),
                const SizedBox(width: IaSpacing.m),
                Text(
                  '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                  style: const TextStyle(fontSize: 12.5, color: IaColors.textMid),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
