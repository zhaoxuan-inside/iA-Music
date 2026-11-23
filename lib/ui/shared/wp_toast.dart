/// WP toast：顶部整宽横条通知（2.6s 自动收回；错误条不自动收回、点按关闭）。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

/// WP toast：顶部整宽横条从顶边滑入（来源标题 accent 小字 + 消息），直角无气泡。
///
/// 普通通知约 2.6s 自动收回；[isError] 时红色标识、**不自动收回**，
/// 点按任意处关闭，完整展示错误内容（长文换行）。
void showWpToast(
  BuildContext context, {
  required String title,
  required String message,
  bool isError = false,
}) {
  if (!context.mounted) {
    return;
  }
  final p = Theme.of(context).extension<IaPalette>()!;
  // 先取状态栏高度：OverlayEntry 的生命周期可能长于调用方 context，
  // 且调用方可能被 SafeArea 去掉了 padding；用 root view 的 viewPadding，
  // 保证 toast 永远从状态栏下方开始，不盖住状态栏。
  final topInset = MediaQueryData.fromView(View.of(context)).viewPadding.top;
  final overlay = Overlay.of(context, rootOverlay: true);
  final ctrl = AnimationController(
    vsync: overlay,
    duration: const Duration(milliseconds: 300),
  );
  final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
  late final OverlayEntry entry;
  var closed = false;
  void close() async {
    if (closed) {
      return;
    }
    closed = true;
    if (ctrl.isAnimating) {
      await ctrl.reverse();
    }
    if (entry.mounted) {
      entry.remove();
    }
    ctrl.dispose();
  }

  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: topInset,
      left: 0,
      right: 0,
      child: ClipRect(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(anim),
          child: Material(
            color: Colors.black.withValues(alpha: 0.96),
            child: InkWell(
              onTap: isError ? close : null, // 错误条点按关闭
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isError ? IaColors.error : IaColors.hairline,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  IaSpacing.xl,
                  IaSpacing.l,
                  IaSpacing.xl,
                  IaSpacing.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: IaType.semibold,
                        letterSpacing: 1.2,
                        color: isError ? IaColors.error : p.accent,
                      ),
                    ),
                    const SizedBox(height: IaSpacing.xs),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: IaType.light,
                        color: isError ? IaColors.error : IaColors.textHi,
                      ),
                    ),
                    if (isError) ...[
                      const SizedBox(height: IaSpacing.xs),
                      const Text(
                        '点按关闭',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: IaColors.textLow,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  ctrl.forward();
  if (!isError) {
    Future<void>.delayed(const Duration(milliseconds: 2600), () async {
      if (!entry.mounted) {
        ctrl.dispose();
        return;
      }
      await ctrl.reverse();
      if (entry.mounted) {
        entry.remove();
      }
      ctrl.dispose();
    });
  }
}
