/// 设置页：音乐文件夹管理（含扫描进度）/ 外观 / 语言 / 关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../state/library_providers.dart';
import '../../state/scan_controller.dart';
import '../../state/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final p = context.ia;
    final settings = ref.watch(settingsProvider);
    final scan = ref.watch(scanProvider);
    final roots = ref.watch(rootsProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(IaSpacing.xl, IaSpacing.l, IaSpacing.xl, IaSpacing.xxl),
        children: [
          Text(s.settingsTitle,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: p.mainText)),
          const SizedBox(height: IaSpacing.l),

          // ── 曲库 ──
          _sectionTitle(context, s.sectionLibrary),
          Card(
            child: Column(
              children: [
                if (roots == null)
                  const Padding(
                    padding: EdgeInsets.all(IaSpacing.xl),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  for (final root in roots)
                    ListTile(
                      leading: Icon(Icons.folder, color: p.accent),
                      title: Text(root.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: p.secondaryText),
                        onPressed: () =>
                            ref.read(scanProvider.notifier).removeRoot(root.id),
                      ),
                    ),
                ],
                ListTile(
                  leading: Icon(Icons.add, color: p.accent),
                  title: Text(s.addFolder),
                  onTap: () => _addFolder(context, ref),
                ),
                if (scan.scanning)
                  ListTile(
                    leading: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
                    ),
                    title: Text(
                      s.scanning(scan.done, scan.total),
                      style: TextStyle(fontSize: 13.5, color: p.secondaryText),
                    ),
                  )
                else
                  ListTile(
                    leading: Icon(Icons.refresh, color: p.secondaryText),
                    title: Text(s.rescanAll,
                        style: const TextStyle(fontSize: 14)),
                    onTap: () => ref.read(scanProvider.notifier).rescanAll(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: IaSpacing.l),

          // ── 外观 ──
          _sectionTitle(context, s.sectionAppearance),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(IaSpacing.l),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: AppearanceMode.system, label: Text(s.themeSystem)),
                  ButtonSegment(value: AppearanceMode.light, label: Text(s.themeLight)),
                  ButtonSegment(value: AppearanceMode.dark, label: Text(s.themeDark)),
                ],
                selected: {settings.appearance},
                onSelectionChanged: (sel) => ref
                    .read(settingsProvider.notifier)
                    .setAppearance(sel.first),
              ),
            ),
          ),
          const SizedBox(height: IaSpacing.l),

          // ── 语言 ──
          _sectionTitle(context, s.sectionLanguage),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(IaSpacing.l),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: LocaleMode.system, label: Text(s.languageSystem)),
                  ButtonSegment(value: LocaleMode.zh, label: const Text('中文')),
                  ButtonSegment(value: LocaleMode.en, label: const Text('English')),
                ],
                selected: {settings.locale},
                onSelectionChanged: (sel) =>
                    ref.read(settingsProvider.notifier).setLocale(sel.first),
              ),
            ),
          ),
          const SizedBox(height: IaSpacing.l),

          // ── 关于 ──
          _sectionTitle(context, s.sectionAbout),
          Card(
            child: ListTile(
              leading: Icon(Icons.graphic_eq, color: p.accent),
              title: const Text('iA Music'),
              subtitle: Text('${s.aboutVersion} 2.0.0'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(left: IaSpacing.xs, bottom: IaSpacing.s),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.ia.secondaryText)),
      );

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final ctrl = ref.read(scanProvider.notifier);

    // 权限门 + 预置/手输名
    final granted = await ctrl.ensureAudioPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.errorGeneric)));
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final path = await _androidFolderDialog(context, ctrl);
    if (path == null || path.trim().isEmpty || !context.mounted) {
      return;
    }
    final result = await ctrl.addRoot(path.trim());
    if (result == 'exists' && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.folderAlreadyAdded)));
    }
  }

  Future<String?> _androidFolderDialog(
      BuildContext context, ScanController ctrl) {
    final presets = ctrl.androidPresetFolders();
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx).addFolder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<List<String>>(
              future: presets,
              builder: (_, snap) => Column(
                children: [
                  for (final p in snap.data ?? const <String>[])
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.folder_special_outlined, size: 20),
                      title: Text(p.split('/').last),
                      subtitle: Text(p, style: const TextStyle(fontSize: 11)),
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                ],
              ),
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: '/storage/emulated/0/...'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(ctx).cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(S.of(ctx).confirm)),
        ],
      ),
    );
  }
}
