import io, os
os.chdir(r'E:\HardStone.iCodeing\GitHub\iA-Music')

def fix(path, subs):
    s = io.open(path, encoding='utf-8').read()
    ok = 0
    for a, b in subs:
        k = s.count(a)
        if k:
            s = s.replace(a, b)
            ok += k
        else:
            print('MISS', path, '|', a[:50].replace('\n', ' '))
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print(path, '->', ok)

# 1) 收集域 providers：去 LLM，重写
fix('lib/state/collect_providers.dart', [
    ("""/// 收集域 providers：任务流 / GitHub 服务 / 执行服务。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_controller.dart';
import '../services/enrich/metadata_nlp_service.dart';
import '../../adapters/llm/openai_compat_adapter.dart';
import '../services/enrich/enrichment_service.dart';
import '../services/github/github_playlist_service.dart';
import '../services/scan/scan_service.dart';
import 'providers.dart';""",
     """/// 收集域 providers：任务流 / GitHub 服务 / 执行服务 / NLP 查询。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/collect/collect_service.dart';
import '../services/enrich/enrichment_service.dart';
import '../services/enrich/query_nlp.dart';
import '../services/github/github_playlist_service.dart';
import '../services/scan/scan_service.dart';
import 'providers.dart';"""),
    ("""/// 元数据反向重建服务（LLM 清洗 + 时长锚定歌词匹配）。
final enrichmentServiceProvider = FutureProvider<EnrichmentService>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  final st = ref.watch(settingsProvider);
  final llm = OpenAiCompatLlm(
      baseUrl: st.llmBaseUrl, apiKey: st.llmApiKey, model: st.llmModel);
  return EnrichmentService(ref.watch(dbProvider),
      ref.watch(lyricSearchProvider),
      cacheDir: dirs.lyrics,
      nlp: MetadataNlpService(llm));
});""",
     """/// 元数据反向重建服务（本地 NLP 构造查询 + 网络搜索 + 时长锚定投票）。
final enrichmentServiceProvider = FutureProvider<EnrichmentService>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  return EnrichmentService(ref.watch(dbProvider),
      ref.watch(lyricSearchProvider),
      cacheDir: dirs.lyrics,
      nlp: const QueryNlp());
});"""),
])

# 2) settings_controller：去 LLM state/keys/方法
fix('lib/state/settings_controller.dart', [
    ("import '../app/config/llm_config.dart';\n", ""),
    ("""    this.llmBaseUrl = kLlmDefaultBaseUrl,
    this.llmApiKey = '',
    this.llmModel = kLlmDefaultModel,
  });""",
     """  });"""),
    ("""  /// NLP 清洗服务（OpenAI 兼容端点）。
  final String llmBaseUrl;
  final String llmApiKey;
  final String llmModel;

""", ""),
    ("""        llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
        llmApiKey: llmApiKey ?? this.llmApiKey,
        llmModel: llmModel ?? this.llmModel,
""", ""),
    ("""      loaded: true,
      llmBaseUrl: llmBaseUrl,
      llmApiKey: llmApiKey,
      llmModel: llmModel,
    );""",
     """      loaded: true,
    );"""),
    ("""  Future<void> setLlmConfig(
      {required String baseUrl, required String apiKey, required String model}) async {
    state = state.copyWith(
        llmBaseUrl: baseUrl, llmApiKey: apiKey, llmModel: model);
    await _settings.setString(SettingKeys.llmBaseUrl, baseUrl);
    await _settings.setString(SettingKeys.llmApiKey, apiKey);
    await _settings.setString(SettingKeys.llmModel, model);
  }

""", ""),
])

# 3) SettingKeys：去 llm 键
fix('lib/services/settings/settings_service.dart', [
    ("""  static const llmBaseUrl = 'nlp.baseUrl'; // OpenAI 兼容端点
  static const llmApiKey = 'nlp.apiKey';
  static const llmModel = 'nlp.model';
""", ""),
])

# 4) 设置子页：NLP 配置区 → 网络搜索说明
fix('lib/ui/settings/subpages.dart', [
    ("""            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('NLP 清洗服务（OpenAI 兼容端点）'),
            const SizedBox(height: IaSpacing.m),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.s),
              decoration: BoxDecoration(
                  border: Border.all(color: IaColors.hairlineStrong)),
              child: Column(children: [
                TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(
                      fontSize: 13, color: IaColors.textHi),
                  decoration: const InputDecoration(
                      hintText: '接口地址（https://api.openai.com/v1）',
                      border: InputBorder.none,
                      isDense: true),
                ),
                const Divider(color: IaColors.hairline),
                TextField(
                  controller: _keyCtrl,
                  obscureText: true,
                  style: const TextStyle(
                      fontSize: 13, color: IaColors.textHi),
                  decoration: const InputDecoration(
                      hintText: 'API Key（本地网关可留空）',
                      border: InputBorder.none,
                      isDense: true),
                ),
                const Divider(color: IaColors.hairline),
                TextField(
                  controller: _modelCtrl,
                  style: const TextStyle(
                      fontSize: 13, color: IaColors.textHi),
                  decoration: const InputDecoration(
                      hintText: '模型名（gpt-4o-mini）',
                      border: InputBorder.none,
                      isDense: true),
                ),
              ]),
            ),
            const SizedBox(height: IaSpacing.m),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saveLlm,
                child: Text('保存 NLP 配置',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .extension<IaPalette>()!
                            .accent)),
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('元数据反向重建'),
            const SizedBox(height: IaSpacing.m),
            const Text('对缺歌手/歌词的曲目：LLM 清洗 → 时长锚定在线歌词库 → 反向重建 歌名/歌手/歌词',
                style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            FilledButton(""",
     """            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('元数据反向重建（NLP + 网络搜索）'),
            const SizedBox(height: IaSpacing.m),
            const Text('对缺歌手/歌词的曲目：本地 NLP 提取搜索词 → 网络歌词库搜索（时长锚定）→ 反向重建 歌名/歌手/歌词',
                style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            FilledButton("""),
])

# 5) CollectSubPage：去控制器（恢复 ConsumerWidget + 去控制器方法）
fix('lib/ui/settings/subpages.dart', [
    ("""class CollectSubPage extends ConsumerStatefulWidget {
  const CollectSubPage({super.key});

  @override
  ConsumerState<CollectSubPage> createState() => _CollectSubPageState();
}

class _CollectSubPageState extends ConsumerState<CollectSubPage> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;

  @override
  void initState() {
    super.initState();
    final st = ref.read(settingsProvider);
    _urlCtrl = TextEditingController(text: st.llmBaseUrl);
    _keyCtrl = TextEditingController(text: st.llmApiKey);
    _modelCtrl = TextEditingController(text: st.llmModel);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _saveLlm() {
    ref.read(settingsProvider.notifier).setLlmConfig(
        baseUrl: _urlCtrl.text.trim(),
        apiKey: _keyCtrl.text.trim(),
        model: _modelCtrl.text.trim());
    showWpToast(context, title: 'NLP 清洗服务', message: '配置已保存');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {""",
     """class CollectSubPage extends ConsumerWidget {
  const CollectSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {"""),
])

# 6) 删除 LLM 三文件
import os as _os
for f in ['lib/domain/ports/llm_port.dart', 'lib/adapters/llm/openai_compat_adapter.dart',
          'lib/app/config/llm_config.dart', 'lib/services/enrich/metadata_nlp_service.dart']:
    if os.path.exists(f):
        os.remove(f)
        print('removed', f)
print('done')
PYEOF
