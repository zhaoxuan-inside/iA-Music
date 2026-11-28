/// 听法（负一屏）：磁贴 = 策略目录渲染（无种子策略逐行开播）。
/// 电台清单在 listenStrategiesProvider——加策略零 UI 改动。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/listen_providers.dart';
import '../actions/radio_starter.dart';import '../components/kit/search_action.dart';
import '../shared/ui_kit.dart';

class ListenPage extends ConsumerWidget {
  const ListenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref
        .watch(listenStrategiesProvider)
        .where((s) => !s.requiresSeed)
        .toList();

    return HubPage(
      header: const PageHeader(
        kicker: '今天怎么听',
        title: '听法',
        subtitle: '会话从这里开始',
        trailing: SearchAction(),
      ),
      children: [
        for (final s in tiles)
          BigRow(
            title: s.label,
            subtitle: s.subtitle,
            onTap: () => startRadio(ref, context, s),
          ),
      ],
    );
  }
}
