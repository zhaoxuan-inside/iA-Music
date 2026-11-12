/// 两步 onboarding：选仓库即扫即显 → 可跳过。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../state/scan_controller.dart';
import '../../state/settings_controller.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.ia;
    final scan = ref.watch(scanProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(IaSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.graphic_eq, size: 64, color: p.accent),
                const SizedBox(height: IaSpacing.xl),
                Text(s.onboardingTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: p.mainText)),
                const SizedBox(height: IaSpacing.m),
                Text(s.onboardingSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: p.secondaryText, height: 1.6)),
                const SizedBox(height: IaSpacing.xxl),
                if (scan.scanning) ...[
                  LinearProgressIndicator(
                      value: scan.total > 0 ? scan.done / scan.total : null,
                      color: p.accent,
                      backgroundColor: p.lifted),
                  const SizedBox(height: IaSpacing.m),
                  Text(s.scanning(scan.done, scan.total),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: p.secondaryText)),
                  const SizedBox(height: IaSpacing.l),
                  FilledButton(
                    onPressed: scan.total == 0 || scan.done >= scan.total
                        ? _finish
                        : null,
                    child: Text(S.of(context).confirm),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickAndScan,
                    icon: const Icon(Icons.folder_open),
                    label: Text(s.onboardingPickFolder),
                  ),
                  const SizedBox(height: IaSpacing.s),
                  TextButton(
                    onPressed: _finish,
                    child: Text(s.onboardingSkip,
                        style: TextStyle(color: p.secondaryText)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndScan() async {
    setState(() => _busy = true);
    final ctrl = ref.read(scanProvider.notifier);
    var path = await ctrl.pickFolder();
    if (path == null) {
      final granted = await ctrl.ensureAudioPermission();
      if (granted) {
        final presets = await ctrl.androidPresetFolders();
        path = presets.isNotEmpty ? presets.first : null;
      }
    }
    if (path != null && path.trim().isNotEmpty) {
      await ctrl.addRoot(path.trim());
      // 扫描启动即返回：完成态由 scan.scanning/total 驱动 UI
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
  }
}
