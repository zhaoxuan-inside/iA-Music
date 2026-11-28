/// 空态：细体大字 + 弱提示（无插画——内容即界面）。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

/// 空态：细体大字 + 弱提示（无插画——内容即界面）。
class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(IaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: IaType.page,
                fontWeight: IaType.light,
                color: IaColors.textHi,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: IaSpacing.m),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: IaColors.textLow,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
