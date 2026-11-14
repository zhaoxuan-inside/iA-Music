/// 设置子页：存储 / 收集（含 GitHub 歌单拉取入口与提取进度）/ 关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/settings_controller.dart';
import '../../services/enrich/enrichment_service.dart';
import '../playlists/github/github_page.dart';
import '../shared/ui_kit.dart';

/// 页头（返回 + 大标题），四子页共用。
class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

/// 提取与补全进度子页：任务实时流（真实 CollectTasks）。
class ExtractPage extends ConsumerWidget {
  const ExtractPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(collectTasksProvider).value ?? const [];
    final edge = edgeInsets(context);

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '提取进度'),
            const SizedBox(height: IaSpacing.s),
            Text('${tasks.length} 项任务 · 完成后自动入库',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.l),
            if (tasks.isEmpty)
              const Text('当前没有进行中的任务——回到「收集」粘贴链接或拉取歌单开始',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            for (final t in tasks) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.m, vertical: IaSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: IaType.list,
                                  color: IaColors.textHi)),
                        ),
                        Text('${t.source} · ${t.progress}%',
                            style: const TextStyle(
                                fontSize: 12, color: IaColors.textLow)),
                      ],
                    ),
                    const SizedBox(height: IaSpacing.s),
                    Stack(
                      children: [
                        Container(height: 2, color: IaColors.hairlineStrong),
                        FractionallySizedBox(
                          widthFactor: (t.progress / 100).clamp(0.0, 1.0),
                          child: Container(
                            height: 2,
                            color: Theme.of(context)
                                .extension<IaPalette>()!
                                .accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: IaSpacing.m),
            ],
          ],
        ),
      ),
    );
  }
}

/// 存储子页：音乐目录（扫描根目录）+ 曲库统计 + 索引状态。
class StorageSubPage extends ConsumerWidget {
  const StorageSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(trackCountProvider).value ?? 0;
    final roots = ref.watch(rootsProvider).value ?? const [];
    final edge = edgeInsets(context);

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
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
            Text('存储',
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            const SizedBox(height: IaSpacing.m),
            const Text('所有音乐统一收入同一个目录、同一个曲库，不分来源。',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            for (final r in roots)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.m, vertical: IaSpacing.l),
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: IaColors.hairline))),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(r.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: IaType.list, color: IaColors.textHi)),
                    ),
                    const Text('音乐目录',
                        style:
                            TextStyle(fontSize: 12, color: IaColors.textLow)),
                  ],
                ),
              ),
            if (roots.isEmpty)
              const Text('尚未添加音乐目录——在开箱仪式或收集页添加',
                  style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.s),
            Text('$count 首 · FTS 拼音索引就绪',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            const Text('目录的添加与扫描在开箱仪式或收集页交互式完成',
                style: TextStyle(fontSize: 11, color: IaColors.textLow)),
          ],
        ),
      ),
    );
  }
}

/// 收集子页：GitHub 歌单拉取入口 + 提取与补全进度入口。
class CollectSubPage extends ConsumerWidget {
  const CollectSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(collectTasksProvider).value ?? const [];
    final edge = edgeInsets(context);

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const _SubHeader(title: '收集'),
            const SizedBox(height: IaSpacing.m),
            const Text('所有音乐统一收入同一个目录、同一个曲库，不分来源。',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('GitHub 歌单拉取'),
            const SizedBox(height: IaSpacing.m),
            const Text(
                '拉取仓库中的 JSON 歌单：每首含 来源 / 搜索词 / 来源地址 / 歌手 / 歌名 / 歌词；导入后按来源地址获取音频',
                style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GithubPage())),
              child: const Text('⇣ 拉取 GitHub 歌单',
                  style: TextStyle(color: IaColors.textHi)),
            ),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('平台提取（二期）'),
            const SizedBox(height: IaSpacing.m),
            for (final platform in const ['B 站', 'YouTube'])
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.m, vertical: IaSpacing.l),
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: IaColors.hairline))),
                child: Row(
                  children: [
                    Text(platform,
                        style: const TextStyle(
                            fontSize: IaType.list, color: IaColors.textHi)),
                    const Spacer(),
                    Text('二期接入',
                        style: TextStyle(
                            fontSize: 12, color: IaColors.textLow)),
                  ],
                ),
              ),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('元数据反向重建（NLP + 网络搜索）'),
            const SizedBox(height: IaSpacing.m),
            const Text(
                '对缺歌手/歌词的曲目：本地 NLP 提取搜索词 → 网络歌词库搜索（时长锚定）→ 反向重建 歌名/歌手/歌词',
                style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.xl),
            Container(
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: IaColors.hairline))),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提取与补全进度',
                    style: TextStyle(
                        fontSize: IaType.list, color: IaColors.textHi)),
                subtitle: Text('${tasks.length} 项任务落库',
                    style:
                        const TextStyle(fontSize: 12, color: IaColors.textLow)),
                trailing:
                    const Icon(Icons.chevron_right, color: IaColors.textLow),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ExtractPage())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 关于子页。
class AboutSubPage extends ConsumerWidget {
  const AboutSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
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
            Text('关于',
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            const SizedBox(height: IaSpacing.xl),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.l),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline))),
              child: const Row(
                children: [
                  Text('语言',
                      style:
                          TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
                  Spacer(),
                  Text('中文（简体）',
                      style: TextStyle(fontSize: 12, color: IaColors.textLow)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.l),
              child: const Row(
                children: [
                  Text('重播开箱仪式',
                      style:
                          TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
                  Spacer(),
                  Text('选色 → 文件夹',
                      style: TextStyle(fontSize: 12, color: IaColors.textLow)),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.xl),
            const Text('设计语言与交互法则详见 docs/DESIGN.md',
                style: TextStyle(fontSize: 11, color: IaColors.textLow)),
          ],
        ),
      ),
    );
  }
}
