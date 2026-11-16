/// B 站扫码登录页：真实 passport 协议（generate → 轮询 → cookies 落库）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/config/collect_config.dart' as cfg;
import '../../app/theme/design_tokens.dart';
import '../../services/collect/bili_login.dart';
import '../../services/collect/bilibili_client.dart';
import '../../state/collect_providers.dart';
import '../shared/ui_kit.dart';

class BilibiliLoginPage extends ConsumerStatefulWidget {
  const BilibiliLoginPage({super.key});

  @override
  ConsumerState<BilibiliLoginPage> createState() => _BilibiliLoginPageState();
}

class _BilibiliLoginPageState extends ConsumerState<BilibiliLoginPage> {
  BiliQrCode? _qr;
  BiliQrState _state = BiliQrState.waiting;
  String? _error;
  Timer? _timer; // 有效期倒计时（1s 走表）
  Timer? _pollTimer; // 扫码状态轮询（2s）
  bool _saving = false;
  bool _leaving = false;
  int _remainSec = 0; // 当前二维码剩余有效期（B 站 180s 口径）

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

  Future<void> _newQr() async {
    setState(() {
      _state = BiliQrState.waiting;
      _error = null;
      _qr = null;
      _remainSec = cfg.KBili.qrLifetime.inSeconds;
    });
    try {
      final qr = await ref.read(bilibiliClientProvider).generateQr();
      if (!mounted) {
        return;
      }
      setState(() => _qr = qr);
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

  /// 扫码状态轮询（2s 一次）；保存失败后可原地重启，不必重新扫码。
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  /// 有效期倒计时：到 0 主动换码（服务端 86038 兜底）。
  void _tick() {
    if (_state != BiliQrState.waiting && _state != BiliQrState.scanned) {
      return;
    }
    if (_remainSec <= 1) {
      _timer?.cancel();
      _newQr();
      return;
    }
    setState(() => _remainSec--);
  }

  Future<void> _poll() async {
    final qr = _qr;
    if (qr == null || _saving) {
      return;
    }
    try {
      final poll = await ref.read(bilibiliClientProvider).pollQr(qr.qrcodeKey);
      if (!mounted) {
        return;
      }
      switch (poll.state) {
        case BiliQrState.waiting:
        case BiliQrState.scanned:
          setState(() {
            _state = poll.state;
            // 网络恢复后抹掉上一轮的报错，避免二维码正常却挂着红字。
            _error = null;
          });
          break;
        case BiliQrState.expired:
          // 服务端判失效（86038）→ 立即换新码（正常由倒计时先行触发）
          _timer?.cancel();
          _pollTimer?.cancel();
          unawaited(_newQr());
          break;
        case BiliQrState.success:
          // 成功即停表停轮询，保存成功后由页面自己关闭；
          // 保存失败则原地重启轮询（同一 qrcode_key 仍可复用）。
          _timer?.cancel();
          _pollTimer?.cancel();
          setState(() => _state = BiliQrState.success);
          await _save(poll);
          break;
        case BiliQrState.error:
          setState(() => _error = poll.message ?? '未知登录状态');
          break;
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = '轮询失败：$e');
      }
    }
  }

  /// 返回/退出登录页：先做最后一次轮询，若已确认则保存并自动关闭；
  /// 否则明确提示「现在退出不会保存登录态」。
  Future<void> _handleBack() async {
    if (_leaving || _saving) {
      return;
    }
    final qr = _qr;
    if (qr != null) {
      try {
        final poll = await ref.read(bilibiliClientProvider).pollQr(qr.qrcodeKey);
        if (!mounted) {
          return;
        }
        if (poll.state == BiliQrState.success) {
          await _save(poll);
          return;
        }
      } on Object {
        // 网络失败：按未确认处理，继续给用户选择
      }
    }
    if (!mounted) {
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IaColors.canvas,
        title: const Text('扫码尚未完成',
            style: TextStyle(
                fontSize: 20,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        content: const Text('现在退出登录页不会保存登录态，需要下次重新扫码。',
            style: TextStyle(fontSize: 13, color: IaColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续扫码',
                style: TextStyle(fontSize: 13, color: IaColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('退出',
                style: TextStyle(fontSize: 13, color: IaColors.error)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _save(BiliQrPoll poll) async {
    if (_saving || _leaving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final commit = await commitBiliLogin(
        client: ref.read(bilibiliClientProvider),
        store: ref.read(platformStoreProvider),
        poll: poll,
      );
      if (!mounted) {
        return;
      }
      if (!commit.ok) {
        final noCookie = (poll.cookies ?? const {}).isEmpty;
        setState(() {
          _state = BiliQrState.waiting;
          _saving = false;
          _error = noCookie ? '登录成功但未取到 cookie——请重新扫码' : '登录态保存失败：cookie 未落库';
        });
        // 同一 qrcode_key 可能仍有效：继续轮询，用户不必再扫一次。
        _startPolling();
        return;
      }
      // 登录页自己 bump，不依赖上一级页面 context 是否还挂载：
      // 登录期间收集页可能因 stream 更新重建，旧 context 会失效。
      ref.read(platformLoginEpochProvider.notifier).bump();
      // 保存已确认落库：立刻关闭登录页。
      // 提示交给上一级页面（在 pop 之后显示），避免 overlay 与页面销毁竞争。
      setState(() {
        _saving = false;
        _leaving = true;
      });
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = BiliQrState.waiting;
        _saving = false;
        _error = '登录态保存失败：$e';
      });
      _startPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);

    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
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
                  onPressed: _handleBack,
                ),
              ],
            ),
            const SizedBox(height: IaSpacing.m),
            Text('B 站登录',
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            const SizedBox(height: IaSpacing.m),
            Text('打开 B 站 App → 扫一扫 → 确认登录',
                style: const TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            Center(
              child: Container(
                padding: const EdgeInsets.all(IaSpacing.l),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: IaColors.hairlineStrong)),
                child: switch (_state) {
                  BiliQrState.expired => SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('二维码已过期',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.black87)),
                            const SizedBox(height: IaSpacing.m),
                            TextButton(
                              onPressed: _newQr,
                              child: Text('重新生成',
                                  style: TextStyle(fontSize: 13, color: p.accent)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _ => _qr == null
                      ? const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                              child: Text('生成中…',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black54))))
                      : SizedBox(
                          width: 220,
                          height: 220,
                          child: QrImageView(
                              data: _qr!.url,
                              version: QrVersions.auto,
                              backgroundColor: Colors.white)),
                },
              ),
            ),
            const SizedBox(height: IaSpacing.l),
            Center(
              child: Text(
                  switch (_state) {
                    BiliQrState.waiting =>
                      '等待扫码… · ${_remainSec}s 后自动刷新',
                    BiliQrState.scanned => '已扫码——请在手机上确认',
                    BiliQrState.expired => '二维码已过期',
                    BiliQrState.success => '登录成功',
                    BiliQrState.error => '出错',
                  },
                  style: TextStyle(
                      fontSize: 13.5,
                      color: _state == BiliQrState.success
                          ? p.accent
                          : IaColors.textMid)),
            ),
            if (_error != null) ...[
              const SizedBox(height: IaSpacing.m),
              Center(
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: IaColors.error)),
              ),
              const SizedBox(height: IaSpacing.xs),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() => _error = null);
                    unawaited(_newQr());
                  },
                  child: Text('重新生成二维码',
                      style: TextStyle(fontSize: 12.5, color: p.accent)),
                ),
              ),
            ],
            const SizedBox(height: IaSpacing.xl),
            const Text(
                '登录后可站内搜索并批量提取；凭据只保存在本机曲库设置里，不外传。',
                style: TextStyle(fontSize: 11, color: IaColors.textLow)),
          ],
        ),
      ),
      ),
    );
  }
}
