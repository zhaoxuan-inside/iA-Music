/// YouTube 登录页：浏览器 cookie 导入（与 yt-dlp cookies 通道同构）。
///
/// 谷歌 OAuth 不开放第三方客户端直接账号密码登录——本页引导用户在
/// 任意浏览器登录 YouTube 后粘贴 Cookie 头，客户端校验 SAPISID 后落库。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../services/collect/platform_store.dart';
import '../../state/collect_providers.dart';
import '../shared/ui_kit.dart';

class YoutubeLoginPage extends ConsumerStatefulWidget {
  const YoutubeLoginPage({super.key});

  @override
  ConsumerState<YoutubeLoginPage> createState() => _YoutubeLoginPageState();
}

class _YoutubeLoginPageState extends ConsumerState<YoutubeLoginPage> {
  final _ctrl = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);

    return PopScope(
      canPop: !_checking,
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
            Text('YouTube 登录',
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            const SizedBox(height: IaSpacing.m),
            const Text(
                '在电脑浏览器登录 youtube.com → F12 网络 → 任意请求复制 Cookie 请求头 → 粘贴到下方',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            Container(
              padding: const EdgeInsets.all(IaSpacing.m),
              decoration:
                  BoxDecoration(border: Border.all(color: IaColors.hairlineStrong)),
              child: TextField(
                controller: _ctrl,
                maxLines: 6,
                style: const TextStyle(
                    fontSize: 12,
                    color: IaColors.textHi,
                    fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'SAPISID=…; __Secure-3PAPISID=…; …',
                  hintStyle: TextStyle(color: IaColors.textLow),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _checking ? null : _import,
                child: Text(_checking ? '校验中…' : '保存并校验',
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: IaSpacing.m),
              Text(_error!,
                  style: const TextStyle(fontSize: 12.5, color: IaColors.error)),
            ],
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('为什么是 Cookie'),
            const SizedBox(height: IaSpacing.s),
            const Text(
                '谷歌不向第三方开放 YouTube 账号密码登录。Cookie 导入与 yt-dlp 的 '
                'cookies 通道同构：登录态只落在本机曲库设置，仅用于你自己的提取请求。',
                style: TextStyle(fontSize: 11.5, color: IaColors.textLow, height: 1.5)),
            const SizedBox(height: IaSpacing.l),
            Text('校验依据：包含 SAPISID / __Secure-3PAPISID',
                style: TextStyle(fontSize: 11, color: p.textLow)),
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
      _checking = true;
      _error = null;
    });
    try {
      final check =
          await ref.read(youtubeClientProvider).importCookies(header);
      if (!mounted) {
        return;
      }
      if (!check.ok) {
        setState(() => _error = check.message);
        return;
      }
      final saved =
          await ref.read(platformStoreProvider).cookies(PlatformId.youtube);
      if (saved == null || saved.isEmpty) {
        setState(() => _error = '登录态保存失败：cookie 未落库');
        return;
      }
      // 登录页自己 bump，不依赖上一级页面 context 是否还挂载。
      ref.read(platformLoginEpochProvider.notifier).bump();
      if (!mounted) {
        return;
      }
      showWpToast(context, title: 'YouTube', message: '登录成功');
      setState(() => _checking = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }
}
