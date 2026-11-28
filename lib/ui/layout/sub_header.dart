/// 子页页头：返回钮 + 大标题 + accent 短横（设置子页/详情/分类等共用）。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

class SubHeader extends StatelessWidget {
  const SubHeader({required this.title, this.showBack = true, super.key});

  final String title;

  /// false = 无返回钮（WP 式：靠系统返回键/手势返回）。
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBack) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: IaSpacing.xs),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: IaType.page,
                fontWeight: IaType.light,
                letterSpacing: IaType.titleTracking,
                color: IaColors.textHi,
              ),
            ),
          ],
        ),
        const SizedBox(height: IaSpacing.s),
        Container(
          width: 26,
          height: 2,
          color: Theme.of(context).extension<IaPalette>()!.accent,
        ),
      ],
    );
  }
}
