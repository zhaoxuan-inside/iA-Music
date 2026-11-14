/// 两步开箱仪式：选主题色（点一下全局变色）→ 音乐目录确认 → 进入 Hub。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/settings_controller.dart';
import '../shared/ui_kit.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final edge = edgeInsets(context);
    final body = switch (_step) {
      0 => _stepTheme(edge),
      _ => _stepFolder(edge),
    };

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.xl, edge.right, IaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SingleChildScrollView(child: body)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _finish(context),
                    child: const Text('跳过',
                        style: TextStyle(
                            fontSize: 13, color: IaColors.textLow)),
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
                        style: const TextStyle(
                            fontSize: 14, color: IaColors.onAccent)),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        const Text('WP 的老仪式：颜色是这台机器的性格',
            style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
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
                    border: st.accent.value == w.value.value
                        ? Border.all(color: IaColors.textHi, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: st.accent.value == w.value.value
                      ? const Icon(Icons.check, size: 20, color: IaColors.onAccent)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: IaSpacing.l),
        const Text('点一下，全 App 立即变色',
            style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
      ],
    );
  }

  Widget _stepFolder(EdgeInsets edge) {
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
        const Text('所有音乐统一存放在系统音乐目录（可在 设置 · 存储与收集 交互式更改），不分来源',
            style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.xl),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: IaSpacing.m, vertical: IaSpacing.l),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: IaColors.hairline))),
          child: Row(
            children: const [
              Expanded(
                child: Text('/storage/emulated/0/Music',
                    style:
                        TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
              ),
              Text('✓ 默认音乐目录',
                  style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            ],
          ),
        ),
      ],
    );
  }

  void _finish(BuildContext context) {
    ref.read(settingsProvider.notifier).completeOnboarding();
  }
}
