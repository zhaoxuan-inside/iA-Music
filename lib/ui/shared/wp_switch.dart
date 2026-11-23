/// Windows Phone 风格开关（替代 Material 药丸 Switch）。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

/// Windows Phone 风格开关（替代 Material 药丸 Switch）：
/// 方角矩形 + 「开/关」文字 + 右侧实心块（开=accent 打勾，关=灰）。
/// 全应用统一切换控件——不要在 UI 里直接用 [Switch]。
class WpSwitch extends StatelessWidget {
  const WpSwitch({required this.value, this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        width: 84,
        height: 30,
        decoration: BoxDecoration(
          border: Border.all(
              color: value ? p.accent : IaColors.hairlineStrong),
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  value ? '开' : '关',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: value ? p.accent : IaColors.textLow,
                  ),
                ),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              color: value ? p.accent : IaColors.hairline,
              child: value
                  ? const Icon(Icons.check,
                      size: 18, color: IaColors.onAccent)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
