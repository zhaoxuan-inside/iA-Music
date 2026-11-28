/// 两步开箱仪式：选主题色（点一下全局变色）→ 音乐目录确认 → 进入 Hub。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/library_providers.dart';
import '../../state/scan_controller.dart';
import '../../state/settings_controller.dart';
import '../settings/directory_picker_page.dart';
import '../shared/ui_kit.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;
  List<String> _presets = const [];

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await ref.read(scanProvider.notifier).androidPresetFolders();
    if (mounted) {
      setState(() => _presets = presets);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edge = edgeInsets(context);
    final body = switch (_step) {
      0 => _stepTheme(edge),
      _ => _stepFolder(edge),
    };

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: Stack(
        children: [
          Positioned(
            right: -8,
            top: MediaQuery.of(context).padding.top + 20,
            child: IgnorePointer(
              child: Text(
                '0${_step + 1}',
                style: TextStyle(
                  fontSize: 168,
                  height: 1,
                  fontWeight: IaType.light,
                  letterSpacing: -8,
                  color: Colors.white.withValues(alpha: 0.035),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(edge.left, IaSpacing.xl, edge.right, IaSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SingleChildScrollView(child: body)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => _finish(context),
                        child: Text('跳过',
                            style: TextStyle(
                                fontSize: 14.5, color: IaColors.textLow)),
                      ),
                      FilledButton(
                        onPressed: () {
                          if (_step == 0) {
                            setState(() => _step = 1);
                          } else {
                            _finish(context);
                          }
                        },
                        child: Text(_step == 0 ? '下一步' : '完成',
                            style: const TextStyle(fontSize: 15.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTheme(EdgeInsets edge) {
    final st = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('WELCOME · 开箱仪式 1/2'),
        const SizedBox(height: IaSpacing.m),
        Text('选一支主题色',
            style: TextStyle(
                fontSize: IaType.hero,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        const SizedBox(height: IaSpacing.m),
        Text('WP 的老仪式：颜色是这台机器的性格',
            style: TextStyle(fontSize: 14, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.xl),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final w in kWpPalette)
              InkWell(
                onTap: () =>
                    ref.read(settingsProvider.notifier).setAccent(w.value),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: w.value,
                    border: st.accent.toARGB32() == w.value.toARGB32()
                        ? Border.all(color: IaColors.textHi, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: st.accent.toARGB32() == w.value.toARGB32()
                      ? Icon(Icons.check, size: 20, color: IaColors.onAccent)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: IaSpacing.l),
        Text('点一下，全 App 立即变色',
            style: TextStyle(fontSize: 14, color: IaColors.textLow)),
      ],
    );
  }

  Widget _stepFolder(EdgeInsets edge) {
    final scan = ref.watch(scanProvider);
    final roots = ref.watch(rootsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('开箱仪式 2/2'),
        const SizedBox(height: IaSpacing.m),
        Text('音乐放在哪？',
            style: TextStyle(
                fontSize: IaType.hero,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        const SizedBox(height: IaSpacing.m),
        Text('选择音乐所在目录；之后可随时在 设置 · 存储 更改',
            style: TextStyle(fontSize: 14, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.xl),
        for (final r in roots)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: IaSpacing.m, vertical: IaSpacing.l),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: IaColors.hairline))),
            child: Row(
              children: [
                Expanded(
                  child: Text(r.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: IaType.list, color: IaColors.textHi)),
                ),
                Text('✓ 已添加',
                    style: TextStyle(fontSize: 13.5, color: IaColors.textLow)),
              ],
            ),
          ),
        if (roots.isEmpty)
          Text('尚未选择目录——添加后立即扫描入库',
              style: TextStyle(fontSize: 13.5, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.l),
        Wrap(
          spacing: IaSpacing.m,
          runSpacing: IaSpacing.m,
          children: [
            for (final preset in _presets)
              if (!roots.any((r) => r.path == preset))
                OutlinedButton(
                  onPressed:
                      scan.scanning ? null : () => _addRoot(preset),
                  child: Text(preset.split('/').last,
                      style: TextStyle(
                          fontSize: 14.5, color: IaColors.textHi)),
                ),
            OutlinedButton(
              onPressed: scan.scanning ? null : _pickDirectory,
              child: Text('手动选择目录…',
                  style: TextStyle(fontSize: 14.5, color: IaColors.textHi)),
            ),
          ],
        ),
        if (scan.scanning) ...[
          const SizedBox(height: IaSpacing.l),
          Text(scan.total > 0 ? '扫描中 ${scan.done}/${scan.total}' : '扫描中…',
              style: TextStyle(fontSize: 13.5, color: IaColors.textMid)),
          const SizedBox(height: IaSpacing.s),
          Stack(
            children: [
              Container(height: 2, color: IaColors.hairlineStrong),
              FractionallySizedBox(
                widthFactor: scan.total > 0
                    ? (scan.done / scan.total).clamp(0.0, 1.0)
                    : 0.0,
                child: Container(height: 2, color: IaColors.textMid),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 授权 → 目录浏览器 → 添加并扫描。
  Future<void> _pickDirectory() async {
    final ok = await ref.read(scanProvider.notifier).ensureAudioPermission();
    if (!ok) {
      if (mounted) {
        showWpToast(context, title: '开箱仪式', message: '存储权限未授予——先在系统设置中允许');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final picked = await Navigator.of(context).push<String>(
        zuneRoute(builder: (_) => const DirectoryPickerPage()));
    if (picked == null) {
      return;
    }
    await _addRoot(picked);
  }

  Future<void> _addRoot(String path) async {
    String result = '';
    Object? failure;
    try {
      result = await ref.read(scanProvider.notifier).addRoot(path);
    } on Object catch (e) {
      failure = e;
    }
    if (!mounted) {
      return;
    }
    final err = ref.read(scanProvider).lastError;
    if (failure != null) {
      showWpToast(context,
          title: '开箱仪式 · 添加失败', message: '$failure', isError: true);
      return;
    }
    if (err != null) {
      showWpToast(context,
          title: '开箱仪式 · 扫描失败', message: err, isError: true);
      return;
    }
    showWpToast(context,
        title: '开箱仪式',
        message: result == 'exists' ? '目录已存在 · 已重新扫描' : '已添加并扫描：$path');
  }

  void _finish(BuildContext context) {
    ref.read(settingsProvider.notifier).completeOnboarding();
  }
}
