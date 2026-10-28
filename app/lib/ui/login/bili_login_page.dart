/// B 站登录页（扫码主路 + Cookie 粘贴兜底 · DEC-012 重写）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:ia_music/adapters/bilibili_auth_adapter.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class BiliLoginPage extends StatefulWidget {
  const BiliLoginPage({super.key, required this.auth});

  final BilibiliAuthAdapter auth;

  @override
  State<BiliLoginPage> createState() => _BiliLoginPageState();
}

class _BiliLoginPageState extends State<BiliLoginPage> {
  BiliQrSession? _session;
  String _state = '';
  Timer? _poll;
  final TextEditingController _cookie = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_startQr());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cookie.dispose();
    super.dispose();
  }

  Future<void> _startQr() async {
    setState(() => _busy = true);
    try {
      final s = await widget.auth.createQrLogin();
      if (!mounted) return;
      setState(() {
        _session = s;
        _state = '用 B 站 App 扫码登录';
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_pollQr()));
    } catch (e) {
      if (mounted) setState(() => _state = '二维码获取失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pollQr() async {
    final s = _session;
    if (s == null) return;
    try {
      final poll = await widget.auth.pollQrLogin(s.qrcodeKey);
      if (!mounted) return;
      switch (poll.state) {
        case BiliQrState.waiting:
          setState(() => _state = '等待扫码…');
        case BiliQrState.scanned:
          setState(() => _state = '已扫码，请在手机上确认');
        case BiliQrState.confirmed:
          _poll?.cancel();
          setState(() => _state = '登录成功');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '欢迎，${poll.account?.uname ?? 'B 站用户'}（高音质提取已解锁）')),
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (mounted) Navigator.of(context).pop(true);
        case BiliQrState.expired:
          _poll?.cancel();
          setState(() => _state = '二维码已过期，请刷新');
      }
    } catch (_) {
      // 网络抖动：下一拍重试（不惊动用户）。
    }
  }

  Future<void> _importCookie() async {
    final raw = _cookie.text.trim();
    if (raw.isEmpty) return;
    setState(() => _busy = true);
    try {
      final ok = await widget.auth.importCookieText(raw);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cookie 已导入')));
        Navigator.of(context).pop(true);
      } else {
        setState(() => _state = 'Cookie 无效或已过期');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return Scaffold(
      key: const ValueKey('bili_login_page'),
      appBar: AppBar(title: const Text('登录 B 站')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_session != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(IaRadius.card),
                      ),
                      child: QrImageView(
                        key: const ValueKey('bili_qr'),
                        data: _session!.qrContent,
                        size: 210,
                      ),
                    )
                  else
                    const SizedBox(
                      height: 230,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _state,
                    key: const ValueKey('bili_qr_state'),
                    style: TextStyle(fontSize: 13, color: p.secondaryText),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('bili_qr_refresh'),
                    onPressed: _busy ? null : () => unawaited(_startQr()),
                    icon: Icon(IaIcon.refresh, size: 16),
                    label: const Text('刷新二维码'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '或粘贴 Cookie（SESSDATA=…）',
            style: TextStyle(fontSize: 13, color: p.secondaryText),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('bili_cookie_input'),
            controller: _cookie,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '从浏览器登录 B 站后复制 Cookie',
              prefixIcon: Icon(IaIcon.cookie, size: 20, color: p.secondaryText),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const ValueKey('bili_cookie_import'),
            onPressed: _busy ? null : () => unawaited(_importCookie()),
            icon: Icon(IaIcon.check),
            label: const Text('导入 Cookie'),
          ),
        ],
      ),
    );
  }
}
