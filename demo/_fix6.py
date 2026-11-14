import io, os
os.chdir(r'E:\HardStone.iCodeing\GitHub\iA-Music')

p = 'lib/ui/settings/subpages.dart'
s = io.open(p, encoding='utf-8').read()

i0 = s.index('/// 收集子页')
i1 = s.index('/// 关于子页。')

clean = '''/// 收集子页：GitHub 歌单拉取入口 + 提取与补全进度入口。
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

'''

s = s[:i0] + clean + s[i1:]
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('subpages repaired, len', len(s))
