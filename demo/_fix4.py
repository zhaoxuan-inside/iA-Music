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
            print('MISS', path, '|', a[:60].replace('\n', ' '))
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print(path, '->', ok)

# 1) SettingKeys：LLM 配置键
fix('lib/services/settings/settings_service.dart', [
    ("  static const accent = 'appearance.accent'; // WP 色板色值字符串",
     """  static const accent = 'appearance.accent'; // WP 色板色值字符串
  static const llmBaseUrl = 'nlp.baseUrl'; // OpenAI 兼容端点
  static const llmApiKey = 'nlp.apiKey';
  static const llmModel = 'nlp.model';"""),
])

# 2) settings_controller：state 加 LLM 配置 + 加载/保存
fix('lib/state/settings_controller.dart', [
    ("import '../services/settings/settings_service.dart';",
     "import '../app/config/llm_config.dart';\nimport '../services/settings/settings_service.dart';"),
    ("""class SettingsState {
  const SettingsState({
    this.accent = kDefaultAccent,
    this.locale = LocaleMode.system,
    this.onboardingDone = false,
    this.loaded = false,
  });

  /// 用户选定的 accent（WP 色板色值）。
  final Color accent;
  final String locale;
  final bool onboardingDone;
  final bool loaded;

  SettingsState copyWith({
    Color? accent,
    String? locale,
    bool? onboardingDone,
    bool? loaded,
  }) =>
      SettingsState(
        accent: accent ?? this.accent,
        locale: locale ?? this.locale,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        loaded: loaded ?? this.loaded,
      );
}""",
    """class SettingsState {
  const SettingsState({
    this.accent = kDefaultAccent,
    this.locale = LocaleMode.system,
    this.onboardingDone = false,
    this.loaded = false,
    this.llmBaseUrl = kLlmDefaultBaseUrl,
    this.llmApiKey = '',
    this.llmModel = kLlmDefaultModel,
  });

  /// 用户选定的 accent（WP 色板色值）。
  final Color accent;
  final String locale;
  final bool onboardingDone;
  final bool loaded;

  /// NLP 清洗服务（OpenAI 兼容端点）。
  final String llmBaseUrl;
  final String llmApiKey;
  final String llmModel;

  SettingsState copyWith({
    Color? accent,
    String? locale,
    bool? onboardingDone,
    bool? loaded,
    String? llmBaseUrl,
    String? llmApiKey,
    String? llmModel,
  }) =>
      SettingsState(
        accent: accent ?? this.accent,
        locale: locale ?? this.locale,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        loaded: loaded ?? this.loaded,
        llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
        llmApiKey: llmApiKey ?? this.llmApiKey,
        llmModel: llmModel ?? this.llmModel,
      );
}"""),
    ("""    final accentHex = await _settings.getString(SettingKeys.accent);
    final locale = await _settings.getString(SettingKeys.locale) ?? LocaleMode.system;
    final done = await _settings.getBool(SettingKeys.onboardingDone);
    final accent = _parseAccent(accentHex);
    state = state.copyWith(
      accent: accent,
      locale: locale,
      onboardingDone: done,
      loaded: true,
    );""",
    """    final accentHex = await _settings.getString(SettingKeys.accent);
    final locale = await _settings.getString(SettingKeys.locale) ?? LocaleMode.system;
    final done = await _settings.getBool(SettingKeys.onboardingDone);
    final llmBaseUrl =
        await _settings.getString(SettingKeys.llmBaseUrl) ?? kLlmDefaultBaseUrl;
    final llmApiKey = await _settings.getString(SettingKeys.llmApiKey) ?? '';
    final llmModel =
        await _settings.getString(SettingKeys.llmModel) ?? kLlmDefaultModel;
    final accent = _parseAccent(accentHex);
    state = state.copyWith(
      accent: accent,
      locale: locale,
      onboardingDone: done,
      loaded: true,
      llmBaseUrl: llmBaseUrl,
      llmApiKey: llmApiKey,
      llmModel: llmModel,
    );"""),
    ("""  Future<void> completeOnboarding() async {""",
    """  Future<void> setLlmConfig(
      {required String baseUrl, required String apiKey, required String model}) async {
    state = state.copyWith(
        llmBaseUrl: baseUrl, llmApiKey: apiKey, llmModel: model);
    await _settings.setString(SettingKeys.llmBaseUrl, baseUrl);
    await _settings.setString(SettingKeys.llmApiKey, apiKey);
    await _settings.setString(SettingKeys.llmModel, model);
  }

  Future<void> completeOnboarding() async {"""),
])

# 3) providers：NLP 服务 + EnrichmentService 注入 nlp
fix('lib/state/collect_providers.dart', [
    ("import '../services/collect/collect_service.dart';",
     "import '../services/collect/collect_service.dart';\nimport '../services/enrich/metadata_nlp_service.dart';"),
    ("""import '../services/enrich/enrichment_service.dart';""",
     "import '../../adapters/llm/openai_compat_adapter.dart';\nimport '../services/enrich/enrichment_service.dart';"),
    ("""/// 元数据反向重建服务（时长锚定 + 在线歌词库匹配）。
final enrichmentServiceProvider = FutureProvider<EnrichmentService>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  return EnrichmentService(ref.watch(dbProvider),
      ref.watch(lyricSearchProvider),
      cacheDir: dirs.lyrics);
});""",
    """/// 元数据反向重建服务（LLM 清洗 + 时长锚定歌词匹配）。
final enrichmentServiceProvider = FutureProvider<EnrichmentService>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  final st = ref.watch(settingsProvider);
  final llm = OpenAiCompatLlm(
      baseUrl: st.llmBaseUrl, apiKey: st.llmApiKey, model: st.llmModel);
  return EnrichmentService(ref.watch(dbProvider),
      ref.watch(lyricSearchProvider),
      cacheDir: dirs.lyrics,
      nlp: MetadataNlpService(llm));
});"""),
])

# 4) EnrichmentService：注入 NLP，清洗前置
fix('lib/services/enrich/enrichment_service.dart', [
    ("import '../../domain/ports/lyrics_port.dart';",
     "import '../../domain/ports/lyrics_port.dart';\nimport 'metadata_nlp_service.dart';"),
    ("""class EnrichmentService {
  EnrichmentService(this._db, this._lyrics, {required this.cacheDir});

  final IaDatabase _db;
  final LyricTextSearchPort _lyrics;
  final String cacheDir;""",
     """class EnrichmentService {
  EnrichmentService(this._db, this._lyrics,
      {required this.cacheDir, this.nlp});

  final IaDatabase _db;
  final LyricTextSearchPort _lyrics;
  final String cacheDir;

  /// NLP 清洗（LLM 主路径）；null=未配置，走规则归一化。
  final MetadataNlpService? nlp;"""),
    ("""  Future<bool> _enrichOne(Track t) async {
    final candidates = await _lyrics.searchMatches(t.title);
    // 时长锚定（±3s）；无时长则要求标题线索命中
    final matched = candidates
        .where((m) =>
            t.durationMs <= 0 ||
            (m.durationMs - t.durationMs).abs() <= 3000)
        .toList();
    if (matched.isEmpty) {
      // 保守：标记已尝试（歌名保留归一化结果），避免无限重试
      await _library.applyEnrichment(
          id: t.id, title: t.title, artist: t.artist);
      return false;
    }
    final best = matched.first;

    // 采纳策略：歌名/歌手仅在缺失或与文件名特征一致时覆盖（不覆盖有效标签）
    final adoptTitle = _looksLikeFileName(t.title) || t.title.trim().isEmpty;
    final newTitle = adoptTitle ? best.trackName : t.title;
    final newArtist = t.artist.isEmpty ? best.artistName : t.artist;

    await _library.applyEnrichment(
        id: t.id, title: newTitle, artist: newArtist);
    await _saveLyrics(t.id, best.syncedLrc.trim().isNotEmpty
        ? best.syncedLrc
        : best.plainLrc);
    return true;
  }""",
     """  Future<bool> _enrichOne(Track t) async {
    // NLP 主路径：LLM 清洗原始串（未配置则回退规则归一化）
    final cleaned = nlp == null
        ? null
        : await nlp!.clean(
            rawTitle: t.title,
            fileName: _fileBase(t.path),
            artistHint: t.artist.isEmpty ? null : t.artist);
    final hintTitle = cleaned?.title ?? t.title;
    final hintArtist =
        (cleaned?.artist?.isNotEmpty ?? false) ? cleaned!.artist : t.artist;

    final candidates =
        await _lyrics.searchMatches('$hintTitle $hintArtist'.trim());
    // 时长锚定（±3s）；无时长则要求标题线索命中
    final matched = candidates
        .where((m) =>
            t.durationMs <= 0 ||
            (m.durationMs - t.durationMs).abs() <= 3000)
        .toList();
    if (matched.isEmpty) {
      // 清洗后的歌名/歌手仍然写回（比垃圾名好），并标记已尝试
      await _library.applyEnrichment(
          id: t.id, title: hintTitle, artist: hintArtist);
      return false;
    }
    final best = matched.first;
    final newTitle = hintTitle;
    final newArtist = hintArtist.isNotEmpty ? hintArtist : best.artistName;

    await _library.applyEnrichment(
        id: t.id, title: newTitle, artist: newArtist);
    await _saveLyrics(t.id, best.syncedLrc.trim().isNotEmpty
        ? best.syncedLrc
        : best.plainLrc);
    return true;
  }

  String _fileBase(String path) {
    final name = path.substring(path.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }"""),
])
print('done')
PYEOF
