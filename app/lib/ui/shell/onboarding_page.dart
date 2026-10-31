/// 首次引导（WS5/REQ-ONB-01/02/03：两步 FTUE——①选仓库即扫即显计数
/// →②可选粘贴 B 站链接试提取；可全程跳过；完成后置 onboarding.done）。
library;

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'package:flutter/material.dart';

import 'package:contracts/contracts.dart';

import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/ui/settings/directory_browser_page.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// onboarding 完成标记键（ShellDao KV）。
const String kOnboardingDoneKey = 'onboarding.done';

final class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.hub, required this.onDone});

  final LibraryHub hub;
  final Future<void> Function() onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 1;
  int? _found; // 实时计数（REQ-ONB-02）
  bool _scanning = false;
  bool _scanDone = false;
  bool _extracting = false;
  final TextEditingController _url = TextEditingController();

  /// 建议目录：系统「音乐」文件夹（桌面；Android 无 home 概念 → 隐藏）。
  String? get _suggestedDir {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      return home == null ? null : '$home\\Music';
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      return home == null ? null : '$home/Music';
    }
    return null;
  }

  Future<void> _scanPath(String dir) async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _found = 0;
    });
    try {
      final report = await widget.hub.addRepositoryAndScan(
        dir,
        onProgress: (processed, admitted, skipped) {
          if (mounted) setState(() => _found = admitted);
        },
      );
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanDone = true;
          _found = report.total;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(sOf(context).dirMissing(dir))));
      }
    }
  }

  Future<void> _useSuggested() async {
    final dir = _suggestedDir;
    if (dir == null) return;
    if (!Directory(dir).existsSync()) {
      Directory(dir).createSync(recursive: true);
    }
    await _scanPath(dir);
  }

  Future<void> _pickFolder() async {
    if (Platform.isAndroid) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DirectoryBrowserPage(
          onPick: (path) => unawaited(_scanPath(path)),
        ),
      ));
      return;
    }
    final dir = await getDirectoryPath();
    if (dir != null) {
      await _scanPath(dir);
    }
  }

  Future<void> _extractSample() async {
    final raw = _url.text.trim();
    if (raw.isEmpty || _extracting) return;
    // 合规门禁（REQ-ONB-03）：未确认先展示声明，确认后落账
    if (!await widget.hub.extract.isComplianceAcknowledged()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(sOf(ctx).complianceTitle),
          content: SingleChildScrollView(
            child: Text(sOf(ctx).complianceBody),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(sOf(ctx).cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(sOf(ctx).complianceAck),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await widget.hub.extract.acknowledgeCompliance(at: DateTime.now());
    }
    setState(() => _extracting = true);
    try {
      final (task, _) = await widget.hub.extract.enqueueUrl(
        raw,
        quality: TaskQuality.hires,
        withLyrics: true,
        withText: true,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(sOf(context)
                .extractQueued(task.title ?? raw))));
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on ContractException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _finish() async {
    await widget.hub.data.shell.put(
      kOnboardingDoneKey,
      'true',
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('onboarding_page'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: _step == 1 ? _step1(p, t) : _step2(p, t),
        ),
      ),
    );
  }

  Widget _step1(IaPalette p, AppLocalizations t) => Column(
        key: const ValueKey('onboarding_step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(t.onboardingTitle,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t.onboardingSubtitle,
              style:
                  TextStyle(fontSize: 14, color: p.secondaryText, height: 1.6)),
          const SizedBox(height: 32),
          if (_suggestedDir != null && !_scanDone)
            FilledButton.icon(
              key: const ValueKey('onboarding_use_suggested'),
              onPressed: _scanning ? null : () => unawaited(_useSuggested()),
              icon: Icon(IaIcon.folder),
              label: Text(t.onboardingUseSuggested),
            ),
          const SizedBox(height: 12),
          if (!_scanDone)
            FilledButton.tonalIcon(
              key: const ValueKey('onboarding_pick_folder'),
              onPressed: _scanning ? null : () => unawaited(_pickFolder()),
              icon: Icon(IaIcon.add),
              label: Text(t.onboardingPickFolder),
            ),
          if (_scanning) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  t.onboardingScanning(_found ?? 0),
                  key: const ValueKey('onboarding_count'),
                  style: TextStyle(
                      fontSize: 14,
                      color: p.accent,
                      fontFeatures: kIaNumericFeatures),
                ),
              ],
            ),
          ],
          if (_scanDone) ...[
            const SizedBox(height: 24),
            Text(
              t.onboardingScanDone(_found ?? 0),
              style: TextStyle(
                  fontSize: 14,
                  color: p.accent,
                  fontFeatures: kIaNumericFeatures),
            ),
          ],
          const Spacer(flex: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                key: const ValueKey('onboarding_skip'),
                onPressed: () => unawaited(_finish()),
                child: Text(t.onboardingSkip),
              ),
              FilledButton(
                key: const ValueKey('onboarding_next'),
                onPressed: () => setState(() => _step = 2),
                child: Text(t.onboardingNext),
              ),
            ],
          ),
        ],
      );

  Widget _step2(IaPalette p, AppLocalizations t) => Column(
        key: const ValueKey('onboarding_step2'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(t.onboardingStep2Title,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t.onboardingStep2Body,
              style:
                  TextStyle(fontSize: 14, color: p.secondaryText, height: 1.6)),
          const SizedBox(height: 32),
          TextField(
            key: const ValueKey('onboarding_url'),
            controller: _url,
            decoration: InputDecoration(
              hintText: t.extractInputHint,
              prefixIcon:
                  Icon(IaIcon.link, size: 20, color: p.secondaryText),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('onboarding_extract'),
            onPressed: _extracting ? null : () => unawaited(_extractSample()),
            child: Text(t.onboardingExtract),
          ),
          const Spacer(flex: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 1),
                child: Text(t.cancel),
              ),
              FilledButton(
                key: const ValueKey('onboarding_start'),
                onPressed: () => unawaited(_finish()),
                child: Text(t.onboardingStart),
              ),
            ],
          ),
        ],
      );
}
