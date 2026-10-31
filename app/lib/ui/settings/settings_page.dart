/// 设置页（外观三选 / B 站账号 / 音乐仓库 / 在线封面 / 关于 · DEC-012 重写）。
library;

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

import 'package:ia_music/adapters/bilibili_auth_adapter.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/ui/login/bili_login_page.dart';
import 'package:ia_music/ui/settings/directory_browser_page.dart';
import 'package:ia_music/ui/shell/appearance.dart';
import 'package:ia_music/ui/shell/locale_controller.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.hub,
    required this.appearance,
    required this.locale,
    this.onChanged,
  });

  final LibraryHub hub;
  final AppearanceController appearance;

  /// 语言三选（DEC-005 D5-2）。
  final LocaleController locale;
  final VoidCallback? onChanged;

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  BiliAccount _account = BiliAccount.anonymous;
  bool _coverOnline = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    widget.appearance.addListener(_onAppearance);
  }

  @override
  void dispose() {
    widget.appearance.removeListener(_onAppearance);
    super.dispose();
  }

  void _onAppearance() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final acc = await widget.hub.authAdapter.fetchAccount();
    final raw =
        await widget.hub.data.shell.value(CoverChain.onlineSettingKey);
    if (mounted) {
      setState(() {
        _account = acc;
        _coverOnline = raw == null || raw == 'true' || raw == '"true"';
      });
    }
  }

  Future<void> _toggleCoverOnline(bool v) async {
    setState(() => _coverOnline = v);
    await widget.hub.data.shell.put(
      CoverChain.onlineSettingKey,
      v ? 'true' : 'false',
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BiliLoginPage(auth: widget.hub.authAdapter),
    ));
    await _refresh();
  }

  Future<void> _logout() async {
    final t = sOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.logoutConfirmTitle),
        content: Text(t.logoutConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.logoutAction)),
        ],
      ),
    );
    if (ok ?? false) {
      await widget.hub.authAdapter.logout();
      await _refresh();
    }
  }

  /// 桌面：系统目录选择器。
  Future<void> _addRoot() async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    await _addRootPath(dir);
  }

  /// 安卓：SAF 返回 content:// 无法供扫描引擎使用——快捷目录/手动路径 +
  /// 运行时媒体权限（READ_MEDIA_AUDIO；旧系统回落存储权限）。
  Future<void> _addRootAndroid(String path) async {
    final status = await Permission.audio.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(sOf(context).audioPermissionDenied)));
      }
      return;
    }
    await _addRootPath(path);
  }

  Future<void> _addRootPath(String dir) async {
    final t = sOf(context);
    if (!Directory(dir).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.dirMissing(dir))));
      }
      return;
    }
    try {
      await widget.hub.addRepositoryAndScan(dir);
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.repoAdded(dir))));
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _rescan(int rootId) async {
    await widget.hub.rescanNow(rootId: rootId);
    widget.onChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sOf(context).rescanTriggered)));
    }
  }

  /// 手动识别修正（根内全部活轨重跑 LRCLIB→网易→ASR 兜底；串行限速）。
  Future<void> _enrichRoot(int rootId) async {
    final n = await widget.hub.enrichRoot(rootId);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sOf(context).enrichQueued(n))));
    }
  }

  Future<void> _pickTheme() async {
    final t = sOf(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(t.appearanceTitle,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            for (final (mode, label, icon) in [
              (ThemeMode.dark, t.themeDark, Icons.dark_mode_rounded),
              (ThemeMode.light, t.themeLight, Icons.light_mode_rounded),
              (ThemeMode.system, t.themeFollowSystem,
                  Icons.brightness_auto_rounded),
            ])
              ListTile(
                key: ValueKey('theme_${mode.name}'),
                leading: Icon(icon),
                title: Text(label),
                trailing: mode == widget.appearance.value
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await widget.appearance.set(mode);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 语言三选（DEC-005 D5-2）；语言名用自称（中文/English 不互译）。
  Future<void> _pickLanguage() async {
    final t = sOf(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(t.settingsLanguage,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            for (final (lang, label, icon) in [
              (AppLanguage.zh, t.languageNameZh, Icons.language_rounded),
              (AppLanguage.en, t.languageNameEn, Icons.language_rounded),
              (AppLanguage.system, t.languageFollowSystem,
                  Icons.brightness_auto_rounded),
            ])
              ListTile(
                key: ValueKey('lang_${lang.name}'),
                leading: Icon(icon),
                title: Text(label),
                trailing: lang == widget.locale.value
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await widget.locale.set(lang);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _themeLabel(AppLocalizations t) => switch (widget.appearance.value) {
        ThemeMode.dark => t.themeDark,
        ThemeMode.light => t.themeLight,
        ThemeMode.system => t.themeFollowSystem,
      };

  /// 语言条目副标题：当前选中项自称（中文/English）或「跟随系统」译名。
  String _languageSubtitle(AppLocalizations t) => switch (widget.locale.value) {
        AppLanguage.zh => t.languageNameZh,
        AppLanguage.en => t.languageNameEn,
        AppLanguage.system => t.languageFollowSystem,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('settings_page'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            t.settingsTitle,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.05,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            key: const ValueKey('appearance_entry'),
            leading: Icon(
              widget.appearance.value == ThemeMode.light
                  ? IaIcon.lightMode
                  : widget.appearance.value == ThemeMode.system
                      ? IaIcon.autoMode
                      : IaIcon.darkMode,
            ),
            title: Text(t.appearanceTitle),
            subtitle: Text(_themeLabel(t)),
            trailing: Icon(IaIcon.arrowForward),
            onTap: () => unawaited(_pickTheme()),
          ),
          ListTile(
            key: const ValueKey('language_entry'),
            leading: Icon(Icons.language_rounded),
            title: Text(t.settingsLanguage),
            subtitle: Text(_languageSubtitle(t)),
            trailing: Icon(IaIcon.arrowForward),
            onTap: () => unawaited(_pickLanguage()),
          ),
          SwitchListTile(
            key: const ValueKey('cover_online_entry'),
            secondary: Icon(IaIcon.album),
            title: Text(t.coverOnlineTitle),
            subtitle: Text(t.coverOnlineSubtitle),
            value: _coverOnline,
            onChanged: (v) => unawaited(_toggleCoverOnline(v)),
          ),
          ListTile(
            key: const ValueKey('mine_account_entry'),
            leading: Icon(
              _account.isLogin ? IaIcon.person : IaIcon.scanQr,
              color: _account.isLogin ? p.accent : p.secondaryText,
            ),
            title: Text(_account.isLogin
                ? (_account.uname?.isNotEmpty == true
                    ? _account.uname!
                    : t.biliUserFallback)
                : t.loginBili),
            subtitle: Text(_account.isLogin
                ? t.accountLoggedIn(_account.level)
                : t.accountAnonymousSubtitle),
            trailing: _account.isLogin
                ? TextButton(
                    key: const ValueKey('mine_logout'),
                    onPressed: () => unawaited(_logout()),
                    child:
                        Text(t.logoutButton, style: const TextStyle(fontSize: 13)),
                  )
                : Icon(IaIcon.arrowForward),
            onTap: _account.isLogin ? null : () => unawaited(_openLogin()),
          ),
          const SizedBox(height: 12),
          Text(
            t.repoSection,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.mainText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.repoHint,
            style: TextStyle(fontSize: 12, color: p.secondaryText),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<RepositoryRoot>>(
            future: widget.hub.rootsSnapshot(),
            builder: (context, snap) {
              final roots = snap.data ?? const <RepositoryRoot>[];
              return Column(
                children: [
                  for (var i = 0; i < roots.length; i++)
                    ListTile(
                      key: ValueKey('repo_root_$i'),
                      dense: true,
                      leading: Icon(IaIcon.folder,
                          size: 20, color: p.secondaryText),
                      title: Text(roots[i].path,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('repo_enrich_$i'),
                            tooltip: t.enrichTooltip,
                            onPressed: () =>
                                unawaited(_enrichRoot(roots[i].id)),
                            icon: Icon(IaIcon.autoFix,
                                size: 18, color: p.secondaryText),
                          ),
                          IconButton(
                            key: ValueKey('repo_rescan_$i'),
                            tooltip: t.rescanTooltip,
                            onPressed: () => unawaited(_rescan(roots[i].id)),
                            icon: Icon(IaIcon.refresh,
                                size: 18, color: p.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  if (roots.isEmpty)
                    Padding(
                      key: const ValueKey('repo_empty'),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        t.repoEmpty,
                        style:
                            TextStyle(fontSize: 12, color: p.secondaryText),
                      ),
                    ),
                ],
              );
            },
          ),
          if (Platform.isAndroid)
            _AndroidRepoPicker(onAdd: (path) => unawaited(_addRootAndroid(path)))
          else
            FilledButton.tonalIcon(
              key: const ValueKey('repo_add'),
              onPressed: () => unawaited(_addRoot()),
              icon: Icon(IaIcon.add),
              label: Text(t.repoAddLabel),
            ),
          const SizedBox(height: 24),
          Text(
            t.aboutSection,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.mainText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.aboutBody,
            style: TextStyle(
                fontSize: 12, color: p.secondaryText, height: 1.7),
          ),
        ],
      ),
    );
  }
}

/// 安卓仓库选择器：快捷公共目录 chips + 手动绝对路径输入。
/// （SAF 目录选择返回 content:// 不可扫描——真实路径直取是本地扫描引擎
/// 安卓仓库选择入口：主按钮=层级递进浏览器；手动路径输入兜底。
/// （SAF 目录选择返回 content:// 不可扫描——真实路径直取是本地扫描引擎
/// 的既定约束；权限申请在 [_addRootAndroid] 的 Permission.audio。）
final class _AndroidRepoPicker extends StatefulWidget {
  const _AndroidRepoPicker({required this.onAdd});

  final void Function(String path) onAdd;

  @override
  State<_AndroidRepoPicker> createState() => _AndroidRepoPickerState();
}

class _AndroidRepoPickerState extends State<_AndroidRepoPicker> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = sOf(context);
    return Column(
      key: const ValueKey('repo_add_android'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('repo_browse'),
            onPressed: () => unawaited(
              Navigator.of(context).push<String>(
                MaterialPageRoute<String>(
                  builder: (_) => DirectoryBrowserPage(onPick: widget.onAdd),
                ),
              ),
            ),
            icon: Icon(IaIcon.folder),
            label: Text(t.repoBrowseLabel),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('repo_path_input'),
                controller: _controller,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: t.repoPathHint,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('repo_add'),
              onPressed: () {
                final path = _controller.text.trim();
                if (path.isNotEmpty) widget.onAdd(path);
              },
              icon: Icon(IaIcon.add, size: 18),
              label: Text(t.addLabel),
            ),
          ],
        ),
      ],
    );
  }
}
