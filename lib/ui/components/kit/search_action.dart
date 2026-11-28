/// 统一搜索入口：放在各页 PageHeader 右上角，保证曲库/首页都能一步搜索。
library;

import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';
import '../../routing/app_routes.dart';

class SearchAction extends StatelessWidget {
  const SearchAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: '搜索',
      icon: Icon(Icons.search, size: 19, color: IaColors.textHi),
      onPressed: () => openSearch(context),
    );
  }
}
