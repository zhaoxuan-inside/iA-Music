/// WP 式长按上下文菜单（黑底横条升起 + accent 上缘；细体大字）。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

/// WP 式长按上下文菜单（黑底横条升起 + accent 上缘；细体大字）。
Future<void> showWpMenu(
  BuildContext context, {
  required String title,
  required List<(String, VoidCallback)> items,
}) {
  final p = Theme.of(context).extension<IaPalette>()!;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    shape: const RoundedRectangleBorder(),
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.accent, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IaSpacing.xl,
              IaSpacing.l,
              IaSpacing.xl,
              IaSpacing.s,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: IaType.semibold,
                  letterSpacing: 1.2,
                  color: p.accent,
                ),
              ),
            ),
          ),
          for (final (label, action) in items)
            InkWell(
              onTap: () {
                Navigator.of(sheetContext).pop();
                action();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.xl,
                  vertical: IaSpacing.l,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: IaType.menu,
                    fontWeight: IaType.light,
                    color: IaColors.textHi,
                  ),
                ),
              ),
            ),
          const SizedBox(height: IaSpacing.xl),
        ],
      ),
    ),
  );
}
