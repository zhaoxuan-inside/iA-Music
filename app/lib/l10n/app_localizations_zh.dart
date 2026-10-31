// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navSearch => '搜索';

  @override
  String get navLibrary => '曲库';

  @override
  String get navTracks => '单曲';

  @override
  String get navAlbums => '专辑';

  @override
  String get navArtists => '歌手';

  @override
  String get navMore => '更多';

  @override
  String get navPlaylists => '歌单';

  @override
  String get navSettings => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get languageNameZh => '中文';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageFollowSystem => '跟随系统';

  @override
  String get appearanceTitle => '外观';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '浅色';

  @override
  String get themeFollowSystem => '跟随系统';

  @override
  String get coverOnlineTitle => '在线补齐封面';

  @override
  String get coverOnlineSubtitle => '本地无封面时联网检索（MusicBrainz → iTunes）';

  @override
  String get logoutConfirmTitle => '退出登录 B 站？';

  @override
  String get logoutConfirmBody => '退出后提取将回到匿名音质（64k）。';

  @override
  String get cancel => '取消';

  @override
  String get logoutAction => '退出登录';

  @override
  String get logoutButton => '登出';

  @override
  String get biliUserFallback => 'B 站用户';

  @override
  String get loginBili => '登录 B 站';

  @override
  String accountLoggedIn(int level) {
    return 'Lv.$level · 已登录（高音质提取可用）';
  }

  @override
  String get accountAnonymousSubtitle => '扫码或 Cookie 登录，解锁高音质提取';

  @override
  String get audioPermissionDenied => '未获得音乐读取权限——请在系统设置中授权后重试';

  @override
  String dirMissing(String path) {
    return '目录不存在：$path';
  }

  @override
  String repoAdded(String path) {
    return '已添加仓库并完成扫描：$path';
  }

  @override
  String get rescanTriggered => '已触发重新扫描';

  @override
  String enrichQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已排队识别修正：$count 首',
    );
    return '$_temp0';
  }

  @override
  String get repoSection => '音乐仓库';

  @override
  String get repoHint => '提取的曲目保存在 仓库/提取/ 下；删除仓库不删文件。';

  @override
  String get enrichTooltip => '识别修正（歌名/歌词/封面）';

  @override
  String get rescanTooltip => '重新扫描';

  @override
  String get repoEmpty => '暂无仓库——添加一个本地音乐目录开始';

  @override
  String get repoAddLabel => '添加仓库目录';

  @override
  String get repoBrowseLabel => '浏览选择目录';

  @override
  String get repoPathHint => '或输入音乐目录绝对路径';

  @override
  String get addLabel => '添加';

  @override
  String get aboutSection => '关于';

  @override
  String get aboutBody =>
      'iA Music · 本地优先音乐播放器\nB 站发现 → 提取 → 歌词/封面补全 → 曲库\nUI 参照 Harmonoid（仅视觉语言，PolyForm 许可不复制代码）';

  @override
  String get shuffleTooltip => '随机播放（随机池=全库−少播）';

  @override
  String get viewListTooltip => '列表视图';

  @override
  String get viewGridTooltip => '网格视图';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首',
    );
    return '$_temp0';
  }

  @override
  String get sortRecent => '最近';

  @override
  String get sortTitle => '标题';

  @override
  String get sortArtist => '歌手';

  @override
  String get sortDuration => '时长';

  @override
  String get untitled => '未命名';

  @override
  String get unknownArtist => '未知歌手';

  @override
  String get sourceBili => 'B站';

  @override
  String get missingBadge => '文件缺失';

  @override
  String get emptyLibraryTitle => '曲库是空的';

  @override
  String get emptyLibraryBody => '扫描本地音乐目录，或从 B 站搜索提取你的第一首歌。';

  @override
  String get emptyGoSettings => '去设置添加仓库';

  @override
  String get emptyGoSearch => '去 B 站搜索提取';

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张专辑',
    );
    return '$_temp0';
  }

  @override
  String get albumsEmpty => '暂无专辑（曲目补全后自动归档）';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首',
    );
    return '专辑 · $_temp0';
  }

  @override
  String get playAll => '播放全部';

  @override
  String get shuffleShort => '随机';

  @override
  String artistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位艺术家',
    );
    return '$_temp0';
  }

  @override
  String get artistsEmpty => '暂无艺术家';

  @override
  String artistTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首',
    );
    return '艺术家 · $_temp0';
  }

  @override
  String get playlistCreateTitle => '新建歌单';

  @override
  String get playlistNameHint => '歌单名称';

  @override
  String get createAction => '创建';

  @override
  String get playlistsEmpty => '还没有歌单。红心的歌会进「我喜欢的音乐」。';

  @override
  String playlistPlayAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首',
    );
    return '播放全部（$_temp0）';
  }

  @override
  String get playlistEmpty => '歌单是空的';

  @override
  String get playlistRemoveTooltip => '从歌单移除';

  @override
  String get shufflingSubtitle => '随机播放中';

  @override
  String get pauseTooltip => '暂停';

  @override
  String get playTooltip => '播放';

  @override
  String get previousTooltip => '上一首';

  @override
  String get nextTooltip => '下一首';

  @override
  String get queueTitle => '播放队列';

  @override
  String get queueEmpty => '队列为空';

  @override
  String get eqTitle => '音效';

  @override
  String get eqUnsupportedTitle => '当前播放引擎不支持均衡器';

  @override
  String get eqUnsupportedBody =>
      'mpv_audio_kit 以单 Player 实例发布媒体会话，\n未暴露均衡器波段接口；本页明示不支持，不伪造滑杆。';

  @override
  String get shuffleNotStarted => '随机会话未开始';

  @override
  String get dislikeTooltip => '移出随机池（少播）';

  @override
  String get heartTooltip => '红心';

  @override
  String get unheartTooltip => '取消红心';

  @override
  String get swipeUpHint => '上滑切歌 · 单轮内不重复';

  @override
  String get lyricsTitle => '歌词';

  @override
  String get sourceBiliSubtitle => 'B站字幕';

  @override
  String get sourceAsr => '语音识别';

  @override
  String get loading => '加载中…';

  @override
  String get lyricsEmptyTitle => '本曲暂无歌词';

  @override
  String get lyricsEmptyBody =>
      '歌词在提取入库时自动生成：\n在线歌词库 → B 站字幕 → 本地语音识别，逐级兜底；\n反查命中后回填标准歌词与封面。';

  @override
  String get modeLoops => '列表循环';

  @override
  String get modeSingle => '单曲循环';

  @override
  String get modeSequence => '顺序播放';

  @override
  String get modeRandom => '随机播放';

  @override
  String get playTitle => '播放';

  @override
  String get nothingPlaying => '暂无播放内容';

  @override
  String get wheelTooltip => '随机轮盘';

  @override
  String get shuffleOnTooltip => '随机中（点按改顺序）';

  @override
  String get dislikeLongTooltip => '垃圾桶（减少推荐）';

  @override
  String get heartLongTooltip => '红心（加入「我喜欢的音乐」）';

  @override
  String get biliNetworkError => '网络连不上 B 站——请检查设备的网络连接后重试';

  @override
  String searchFailed(String error) {
    return '搜索失败：$error';
  }

  @override
  String extractQueued(String title) {
    return '已加入提取队列：$title';
  }

  @override
  String get searchHintBili => '搜索 B 站 / 粘贴链接或 BV 号';

  @override
  String get searchHintLocal => '搜索歌曲 / 歌手 / 专辑';

  @override
  String get segmentLocal => '本地曲库';

  @override
  String get segmentBili => 'B 站';

  @override
  String get searchLocalHint => '试试搜索歌手或歌名；支持拼音首字母';

  @override
  String searchNoResults(String query) {
    return '没有找到与「$query」相关的音乐';
  }

  @override
  String get scanLoginBili => '扫码登录 B 站';

  @override
  String get retryAction => '重试';

  @override
  String get biliNoResults => '没有找到相关内容，换个关键词试试';

  @override
  String get openExtractQueue => '打开提取队列';

  @override
  String biliRowMeta(String uploader, String duration, String plays) {
    return '$uploader · $duration · 播放 $plays';
  }

  @override
  String get extractTooltip => '提取音频入库（含歌词补全链路）';

  @override
  String parseFailed(String error) {
    return '解析失败：$error';
  }

  @override
  String taskEnqueued(String title) {
    return '已入队：$title';
  }

  @override
  String get taskExists => '任务已存在，继续沿用';

  @override
  String get navExtract => '提取';

  @override
  String get extractTitle => '提取';

  @override
  String get extractIntro => '粘贴 B 站链接 / 分享文本，或输入关键词解析合集；提取后自动补全歌名、歌手、封面与歌词。';

  @override
  String get extractInputHint => 'https://www.bilibili.com/video/… 或分享文本';

  @override
  String get parseAction => '解析';

  @override
  String get optOnlineLyrics => '在线歌词';

  @override
  String get optBiliSubtitle => 'B 站字幕';

  @override
  String get taskQueueTitle => '任务队列';

  @override
  String get taskQueueEmpty => '队列为空。粘贴一条 B 站链接开始。';

  @override
  String get extractAction => '提取';

  @override
  String get statusResolved => '已解析';

  @override
  String get statusGating => '门禁中';

  @override
  String get statusGated => '已拦截';

  @override
  String get complianceTitle => '提取前请确认';

  @override
  String get complianceBody =>
      '• 提取仅限个人收听用途，请尊重创作者权益\n• 提取内容不入任何公开分发渠道\n• 你需要对提交的链接内容负责';

  @override
  String get complianceAck => '我已阅读并确认';

  @override
  String get qrScanHint => '用 B 站 App 扫码登录';

  @override
  String qrFetchFailed(String error) {
    return '二维码获取失败：$error';
  }

  @override
  String get qrWaiting => '等待扫码…';

  @override
  String get qrScanned => '已扫码，请在手机上确认';

  @override
  String get loginSuccess => '登录成功';

  @override
  String welcomeUnlocked(String name) {
    return '欢迎，$name（高音质提取已解锁）';
  }

  @override
  String get qrExpired => '二维码已过期，请刷新';

  @override
  String get cookieImported => 'Cookie 已导入';

  @override
  String get cookieInvalid => 'Cookie 无效或已过期';

  @override
  String get qrRefresh => '刷新二维码';

  @override
  String get cookieSection => '或粘贴 Cookie（SESSDATA=…）';

  @override
  String get cookieHint => '从浏览器登录 B 站后复制 Cookie';

  @override
  String get importCookie => '导入 Cookie';

  @override
  String dirReadFailed(String reason) {
    return '无法读取该目录（$reason）';
  }

  @override
  String get permissionDenied => '权限不足';

  @override
  String get internalStorage => '内部存储';

  @override
  String get levelUpTooltip => '上一级';

  @override
  String dirBrowserStat(int dirs, int audio) {
    String _temp0 = intl.Intl.pluralLogic(
      dirs,
      locale: localeName,
      other: '$dirs 个子目录',
    );
    String _temp1 = intl.Intl.pluralLogic(
      audio,
      locale: localeName,
      other: '$audio 个音频文件',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get noSubdirs => '没有子目录了——可以直接选择当前目录';

  @override
  String pickThisDir(String name) {
    return '选择此目录（$name）';
  }

  @override
  String get grantAudioPermission => '授予音乐读取权限';

  @override
  String get openSystemSettings => '去系统设置开启';

  @override
  String get coverSuffix => '封面';

  @override
  String get emptyPoolForShuffle => '曲库是空的。先导入音乐，才能随机播放';

  @override
  String get emptyPoolForPlay => '曲库是空的。先导入音乐，才能播放';

  @override
  String get fewWatchedNotice => '已减少这首的推荐';

  @override
  String missingSkipped(String title) {
    return '《$title》文件缺失，已跳过';
  }

  @override
  String corruptSkipped(String title) {
    return '《$title》无法播放该文件（格式或文件损坏），已跳过';
  }

  @override
  String get serviceBrokenNotice => '播放服务异常';

  @override
  String get noContentInLink => '未在链接中找到内容';

  @override
  String subtitleExtractFailed(String error) {
    return '字幕文本提取失败：$error';
  }

  @override
  String get unknownError => '未知异常';

  @override
  String get noSubtitleAvailable => '该视频没有可用的字幕文本（AI 字幕需登录 B 站）';

  @override
  String get subtitleNotSavedNoRepo => '字幕文本未保存：尚未配置音乐仓库';

  @override
  String subtitleSplitSaved(int count) {
    return '字幕文本已按 $count 段拆分保存';
  }

  @override
  String subtitleSaved(String path) {
    return '字幕文本已保存：$path';
  }

  @override
  String get extractTerminated => '提取执行失败，任务已终止';

  @override
  String get noRepoConfigured => '尚未配置音乐仓库，请先在「设置」添加仓库';

  @override
  String get downloadPaused => '下载中断，已暂停，联网后自动继续';

  @override
  String get transcodeFailed => '产物转码失败';

  @override
  String get videoDirNotWritable => '视频目录不可写，任务终止';

  @override
  String get videoMoveFailed => '视频迁移失败：目标目录不可写';

  @override
  String get videoSavedNote => '视频已保存到 仓库/提取/视频（不入曲库）';

  @override
  String get parsingLink => '解析链接…';

  @override
  String get linkParseDead => '链接解析失败：链接可能已失效，或该内容需要登录';

  @override
  String get linkParseNoContent => '链接解析失败：未找到内容';

  @override
  String get analyzingAudio => '分析音频内容…';

  @override
  String get audioMoveFailed => '产物迁移失败：目标目录不可写';

  @override
  String get registerFailedIsolated => '注册失败：产物已隔离，不影响曲库';

  @override
  String get splitFailedWhole => '拆分失败，按完整音轨入库';

  @override
  String splitProgress(int done, int total, String title) {
    return '已拆分 $done/$total 首：$title';
  }

  @override
  String splitDone(int count) {
    return '合集已拆分为 $count 首，歌名/封面/歌词已按段补全';
  }

  @override
  String get splitRegisterFailed => '拆分注册失败：产物已隔离';

  @override
  String get noSongBoundary => '未检测到歌曲分界，按完整音轨入库';

  @override
  String get failureAuth => 'B 站登录状态过期，请重新扫码';

  @override
  String get failureDisk => '存储空间不足，请清理后重试';

  @override
  String get failureUnsupported => '该内容暂不支持提取（付费/地区/格式受限，或工具链需更新）';

  @override
  String get failureNetwork => '网络连接中断，任务已暂停，本地数据不受影响';

  @override
  String get noLinkInShareText => '未在分享文本中找到链接';

  @override
  String get desktopOnlyExtract => '提取功能当前为桌面端形态（Windows），Android 端将在后续版本支持';

  @override
  String get linkNeedLogin => '链接解析失败：该内容需要登录，或链接已失效。可登录 B 站账号后再试';

  @override
  String get linkFormatUnsupported => '该链接格式暂不支持提取（付费/地区/平台形态受限，或提取工具链需要更新）';

  @override
  String get engineNotInit => '提取引擎未初始化（Android）';

  @override
  String get linkParseTimeout => '链接解析失败：网络超时，请检查网络后重试（或链接已失效）';

  @override
  String get linkParseUnrecognized => '链接解析失败：链接格式无法识别，请确认是 B 站视频/合集链接';

  @override
  String engineErrorAndroid(String detail) {
    return '提取引擎异常（Android）：$detail';
  }

  @override
  String get searchQueryEmpty => '搜索词为空';

  @override
  String get douyinUnsupported => '抖音搜索需平台签名登录态，当前版本支持粘贴分享链接提取';

  @override
  String get riskControlIntercepted => '平台风控拦截，请稍后再试或登录 B 站账号';

  @override
  String searchApiFailed(String code, String reason) {
    return 'B 站搜索失败（$code）：$reason';
  }

  @override
  String get unknownReason => '未知原因';

  @override
  String get responseNotJson => '响应不是 JSON 对象';

  @override
  String qrCreateFailed(String code) {
    return '登录二维码获取失败（$code）';
  }

  @override
  String get qrDataIncomplete => '登录二维码数据不完整';

  @override
  String pollFailed(String code) {
    return '登录状态查询失败（$code）';
  }

  @override
  String get dbRecoveryHint => '数据库打开异常：已进入只读保护，你的数据未丢失；请在设置的「修复引导」中处理。';

  @override
  String get eqBandsNote => '5 段均衡 · ±12dB · 拖动实时生效';

  @override
  String get eqPresetDefault => '默认';

  @override
  String get eqPresetPop => '流行';

  @override
  String get eqPresetRock => '摇滚';

  @override
  String get eqPresetClassical => '古典';

  @override
  String get eqPresetJazz => '爵士';

  @override
  String get eqPresetBass => '低音增强';

  @override
  String get eqPresetCustom => '自定义';

  @override
  String eqBandLabel(String hz) {
    return '$hz';
  }
}
