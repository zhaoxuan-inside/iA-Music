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
import 'package:ia_music/ui/login/bili_login_page.dart';
import 'package:ia_music/ui/settings/directory_browser_page.dart';
import 'package:ia_music/ui/shell/appearance.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.hub,
    required this.appearance,
    this.onChanged,
  });

  final LibraryHub hub;
  final AppearanceController appearance;
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录 B 站？'),
        content: const Text('退出后提取将回到匿名音质（64k）。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('退出登录')),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('未获得音乐读取权限——请在系统设置中授权后重试')));
      }
      return;
    }
    await _addRootPath(path);
  }

  Future<void> _addRootPath(String dir) async {
    if (!Directory(dir).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('目录不存在：$dir')));
      }
      return;
    }
    try {
      await widget.hub.addRepositoryAndScan(dir);
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已添加仓库并完成扫描：$dir')));
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
          .showSnackBar(const SnackBar(content: Text('已触发重新扫描')));
    }
  }

  /// 手动识别修正（根内全部活轨重跑 LRCLIB→网易→ASR 兜底；串行限速）。
  Future<void> _enrichRoot(int rootId) async {
    final n = await widget.hub.enrichRoot(rootId);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已排队识别修正：$n 首')));
    }
  }

  Future<void> _pickTheme() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('外观',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            for (final (mode, label, icon) in const [
              (ThemeMode.dark, '深色', Icons.dark_mode_rounded),
              (ThemeMode.light, '浅色', Icons.light_mode_rounded),
              (ThemeMode.system, '跟随系统', Icons.brightness_auto_rounded),
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

  String get _themeLabel => switch (widget.appearance.value) {
        ThemeMode.dark => '深色',
        ThemeMode.light => '浅色',
        ThemeMode.system => '跟随系统',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return Scaffold(
      key: const ValueKey('settings_page'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'SETTINGS',
            style: TextStyle(
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
            title: const Text('外观'),
            subtitle: Text(_themeLabel),
            trailing: Icon(IaIcon.arrowForward),
            onTap: () => unawaited(_pickTheme()),
          ),
          SwitchListTile(
            key: const ValueKey('cover_online_entry'),
            secondary: Icon(IaIcon.album),
            title: const Text('在线补齐封面'),
            subtitle: const Text('本地无封面时联网检索（MusicBrainz → iTunes）'),
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
                    : 'B 站用户')
                : '登录 B 站'),
            subtitle: Text(_account.isLogin
                ? 'Lv.${_account.level} · 已登录（高音质提取可用）'
                : '扫码或 Cookie 登录，解锁高音质提取'),
            trailing: _account.isLogin
                ? TextButton(
                    key: const ValueKey('mine_logout'),
                    onPressed: () => unawaited(_logout()),
                    child:
                        const Text('登出', style: TextStyle(fontSize: 13)),
                  )
                : Icon(IaIcon.arrowForward),
            onTap: _account.isLogin ? null : () => unawaited(_openLogin()),
          ),
          const SizedBox(height: 12),
          Text(
            '音乐仓库',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.mainText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '提取的曲目保存在 仓库/提取/ 下；删除仓库不删文件。',
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
                            tooltip: '识别修正（歌名/歌词/封面）',
                            onPressed: () =>
                                unawaited(_enrichRoot(roots[i].id)),
                            icon: Icon(IaIcon.autoFix,
                                size: 18, color: p.secondaryText),
                          ),
                          IconButton(
                            key: ValueKey('repo_rescan_$i'),
                            tooltip: '重新扫描',
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
                        '暂无仓库——添加一个本地音乐目录开始',
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
              label: const Text('添加仓库目录'),
            ),
          const SizedBox(height: 24),
          Text(
            '关于',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.mainText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'iA Music · 本地优先音乐播放器\n'
            'B 站发现 → 提取 → 歌词/封面补全 → 曲库\n'
            'UI 参照 Harmonoid（仅视觉语言，PolyForm 许可不复制代码）',
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
            label: const Text('浏览选择目录'),
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
                  hintText: '或输入音乐目录绝对路径',
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
              label: const Text('添加'),
            ),
          ],
        ),
      ],
    );
  }
}
