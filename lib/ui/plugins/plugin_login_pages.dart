/// 音频源插件登录页（按 authKind 泛化）：
/// * [PluginQrLoginPage] —— kind=qr：authStart → 2s 轮询 authPoll → 成功关页。
/// * [PluginCookieLoginPage] —— kind=cookie：粘贴 Cookie 头 → authImport。
/// 凭据全部落在插件自己的 KV 沙箱；宿主只见状态不见内容。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';
import '../shared/ui_kit.dart';

/// 已启用的音频源插件句柄（登录页按 id 从 provider 拿，路由只传 id）。
Future<SourcePluginHandle?> _handleOf(WidgetRef ref, String pluginId) async {
  final handles = await ref.read(sourceHandlesProvider.future);
  return handles.where((h) => h.id == pluginId).firstOrNull;
}

// ── 扫码登录 ──────────────────────────────────────────────────────────

class PluginQrLoginPage extends ConsumerStatefulWidget {
  const PluginQrLoginPage({required this.pluginId, super.key});

  final String pluginId;

  @override
  ConsumerState<PluginQrLoginPage> createState() => _PluginQrLoginPageState();
}

class _PluginQrLoginPageState extends ConsumerState<PluginQrLoginPage> {
  String _qrUrl = '';
  int _remainSec = 0;
  String _state = 'waiting';
  String? _error;
  Timer? _timer;
  Timer? _pollTimer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _newQr();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<SourcePluginHandle?> get _handle async =>
      await _handleOf(ref, widget.pluginId);

  Future<void> _newQr() async {
    setState(() {
      _state = 'waiting';
      _error = null;
      _qrUrl = '';
    });
    try {
      final h = await _handle;
      if (h == null) {
        if (mounted) {
          setState(() => _error = '插件未安装或未启用');
        }
        return;
      }
      final st = await h.authStart();
      if (!mounted) {
        return;
      }
      setState(() {
        _qrUrl = '${st?['qrUrl'] ?? ''}';
        _remainSec = (st?['lifetimeSec'] as num?)?.toInt() ?? 180;
      });
      if (_qrUrl.isEmpty) {
        setState(() => _error = '二维码生成失败：插件未返回 qrUrl');
        return;
      }
      // 1s 走表倒计时 + 2s 轮询，双轨并行
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _startPolling();
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = '二维码生成失败：$e');
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  void _tick() {
    if (_state != 'waiting' && _state != 'scanned') {
      return;
    }
    if (_remainSec <= 1) {
      _timer?.cancel();
      unawaited(_newQr());
      return;
    }
    setState(() => _remainSec--);
  }

  Future<void> _poll() async {
    if (_leaving || _qrUrl.isEmpty) {
      return;
    }
    try {
      final h = await _handle;
      if (h == null) {
        return;
      }
      final poll = await h.authPoll();
      if (!mounted) {
        return;
      }
      final state = '${poll?['state'] ?? 'error'}';
      switch (state) {
        case 'waiting':
        case 'scanned':
          setState(() {
            _state = state;
            _error = null; // 网络恢复后抹掉上一轮报错
          });
          break;
        case 'expired':
          _timer?.cancel();
          _pollTimer?.cancel();
          unawaited(_newQr());
          break;
        case 'success':
          _timer?.cancel();
          _pollTimer?.cancel();
          setState(() => _state = 'success');
          await _finish();
          break;
        default:
          setState(() => _error = '${poll?['message'] ?? '未知登录状态'}');
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = '轮询失败：$e');
      }
    }
  }

  Future<void> _finish() async {
    // 凭据由插件在 authPoll 成功分支里写自己的 KV 沙箱；
    // 这里只需 bump 让收集页刷新登录态，然后关页。
    ref.read(sourceEpochProvider.notifier).bump();
    if (!mounted) {
      return;
    }
    setState(() => _leaving = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);
    final pluginName =
        ref.watch(sourceHandlesProvider).value?.where((h) => h.id == widget.pluginId).firstOrNull?.name ?? '插件';

    return PopScope(
      canPop: _leaving,
      child: Scaffold(
        backgroundColor: IaColors.canvas,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: IaSpacing.m),
              Text('$pluginName 登录',
                  style: TextStyle(
                      fontSize: IaType.page,
                      fontWeight: IaType.light,
                      color: IaColors.textHi)),
              const SizedBox(height: IaSpacing.xl),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(IaSpacing.l),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: IaColors.hairlineStrong)),
                  child: _state == 'expired'
                      ? SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('二维码已过期',
                                    style: TextStyle(
                                        fontSize: 15.5, color: Colors.black87)),
                                const SizedBox(height: IaSpacing.m),
                                TextButton(
                                  onPressed: () => unawaited(_newQr()),
                                  child: Text('重新生成',
                                      style: TextStyle(
                                          fontSize: 14.5, color: p.accent)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _qrUrl.isEmpty
                          ? const SizedBox(
                              width: 220,
                              height: 220,
                              child: Center(
                                  child: Text('生成中…',
                                      style: TextStyle(
                                          fontSize: 15.5,
                                          color: Colors.black54))))
                          : SizedBox(
                              width: 220,
                              height: 220,
                              child: QrImageView(
                                  data: _qrUrl,
                                  version: QrVersions.auto,
                                  backgroundColor: Colors.white)),
                ),
              ),
              const SizedBox(height: IaSpacing.l),
              Center(
                child: Text(
                    switch (_state) {
                      'waiting' => '等待扫码… · ${_remainSec}s 后自动刷新',
                      'scanned' => '已扫码——请在手机上确认',
                      'expired' => '二维码已过期',
                      'success' => '登录成功',
                      _ => '出错',
                    },
                    style: TextStyle(
                        fontSize: 15,
                        color: _state == 'success' ? p.accent : IaColors.textMid)),
              ),
              if (_error != null) ...[
                const SizedBox(height: IaSpacing.m),
                Center(
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5, color: IaColors.error)),
                ),
              ],
              const SizedBox(height: IaSpacing.xl),
              Text(
                  '登录后可站内搜索并批量提取；凭据只保存在本机插件沙箱里，不外传。',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cookie 导入登录 ───────────────────────────────────────────────────

class PluginCookieLoginPage extends ConsumerStatefulWidget {
  const PluginCookieLoginPage({required this.pluginId, super.key});

  final String pluginId;

  @override
  ConsumerState<PluginCookieLoginPage> createState() =>
      _PluginCookieLoginPageState();
}

class _PluginCookieLoginPageState extends ConsumerState<PluginCookieLoginPage> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<SourcePluginHandle?> get _handle async =>
      await _handleOf(ref, widget.pluginId);

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);
    final pluginName =
        ref.watch(sourceHandlesProvider).value?.where((h) => h.id == widget.pluginId).firstOrNull?.name ?? '插件';

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: IaColors.canvas,
        body: SafeArea(
          child: ListView(
            padding:
                EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: IaSpacing.m),
              Text('$pluginName 登录',
                  style: TextStyle(
                      fontSize: IaType.page,
                      fontWeight: IaType.light,
                      color: IaColors.textHi)),
              const SizedBox(height: IaSpacing.m),
              Text(
                  '在电脑浏览器登录 → F12 网络 → 任意请求复制 Cookie 请求头 → 粘贴到下方',
                  style: TextStyle(fontSize: 14, color: IaColors.textLow)),
              const SizedBox(height: IaSpacing.xl),
              Container(
                padding: const EdgeInsets.all(IaSpacing.m),
                decoration:
                    BoxDecoration(border: Border.all(color: IaColors.hairlineStrong)),
                child: TextField(
                  controller: _ctrl,
                  maxLines: 6,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: IaColors.textHi,
                      fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '粘贴浏览器 Cookie 请求头（name=value; …）',
                    hintStyle: TextStyle(color: IaColors.textLow),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: IaSpacing.m),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : () => unawaited(_import()),
                  child: Text(_saving ? '校验中…' : '保存并校验',
                      style: const TextStyle(fontSize: 15.5)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: IaSpacing.m),
                Text(_error!,
                    style: TextStyle(fontSize: 14, color: IaColors.error)),
              ],
              const SizedBox(height: IaSpacing.xl),
              Text(
                  'Cookie 导入与 yt-dlp 的 cookies 通道同构：登录态只落在插件沙箱，'
                  '仅用于你自己的提取请求。',
                  style: TextStyle(fontSize: 13, color: IaColors.textLow, height: 1.5)),
              const SizedBox(height: IaSpacing.l),
              Text('校验规则由插件定义（authImport 返回 ok/message）',
                  style: TextStyle(fontSize: 12.5, color: p.textLow)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _import() async {
    final header = _ctrl.text.trim();
    if (header.isEmpty) {
      setState(() => _error = '先粘贴 Cookie 头');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final h = await _handle;
      if (h == null) {
        if (mounted) {
          setState(() => _error = '插件未安装或未启用');
        }
        return;
      }
      final r = await h.authImport(header);
      if (!mounted) {
        return;
      }
      if (r?['ok'] != true) {
        setState(() => _error = '${r?['message'] ?? '导入被插件拒绝'}');
        return;
      }
      ref.read(sourceEpochProvider.notifier).bump();
      // 名字从已缓存的插件列表同步取，避免 await 后再摸 context。
      final name = ref
              .read(sourceHandlesProvider)
              .value
              ?.where((h) => h.id == widget.pluginId)
              .firstOrNull
              ?.name ??
          '插件';
      if (!mounted) {
        return;
      }
      showWpToast(context, title: name, message: '登录成功');
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
