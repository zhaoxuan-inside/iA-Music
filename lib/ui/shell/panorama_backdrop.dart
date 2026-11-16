/// Hub 全景背景：巨幅水印与页标题以 0.5～0.6x 速度横移。
///
/// 这是 Panorama 的「深度」来源：内容 1:1 滑动，背景慢半拍，
/// 页面因此不是七张并列的卡片，而是一条连续的音乐长廊。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

class PanoramaBackdrop extends StatelessWidget {
  const PanoramaBackdrop({
    required this.controller,
    required this.titles,
    super.key,
  });

  final PageController controller;

  /// 与 PageView 一一对应的页标题（用于背景巨字）。
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final page = controller.hasClients
                ? (controller.page ?? controller.initialPage.toDouble())
                : controller.initialPage.toDouble();

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // 品牌水印：整条长廊只有这一句，慢速跟随。
                Positioned(
                  left: 0,
                  top: top + 26,
                  child: Transform.translate(
                    offset: Offset(-page * w * 0.34, 0),
                    child: IgnorePointer(
                      child: Text(
                        'iA MUSIC',
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 148,
                          height: 1,
                          fontWeight: IaType.light,
                          letterSpacing: -6,
                          color: IaColors.watermark,
                        ),
                      ),
                    ),
                  ),
                ),
                // 每页巨字：以 0.62x 速度滑过，像 Panorama 的层叠标题。
                for (var i = 0; i < titles.length; i++)
                  Positioned(
                    left: 18,
                    top: top + 94,
                    child: Transform.translate(
                      offset: Offset((i - page) * w * 0.62, 0),
                      child: IgnorePointer(
                        child: Opacity(
                          opacity:
                              (1 - (i - page).abs()).clamp(0.0, 1.0) * 0.055,
                          child: Text(
                            titles[i],
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 172,
                              height: 0.92,
                              fontWeight: IaType.light,
                              letterSpacing: -8,
                              color: IaColors.textHi,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // 一条极淡的竖向分割线，随页面以半速移动。
                Positioned(
                  left: 0,
                  top: top + 40,
                  bottom: 120,
                  child: Transform.translate(
                    offset: Offset(w * 0.86 - page * w * 0.43, 0),
                    child: Container(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.035),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
