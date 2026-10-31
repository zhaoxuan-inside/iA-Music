import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @navSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get navSearch;

  /// No description provided for @navLibrary.
  ///
  /// In zh, this message translates to:
  /// **'曲库'**
  String get navLibrary;

  /// No description provided for @navTracks.
  ///
  /// In zh, this message translates to:
  /// **'单曲'**
  String get navTracks;

  /// No description provided for @navAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get navAlbums;

  /// No description provided for @navArtists.
  ///
  /// In zh, this message translates to:
  /// **'歌手'**
  String get navArtists;

  /// No description provided for @navMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get navMore;

  /// No description provided for @navPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get navPlaylists;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// 设置页语言条目标题
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// 语言选项：中文（自称，不译）
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageNameZh;

  /// 语言选项：English（自称，不译）
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// 语言三选：跟随系统
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageFollowSystem;

  /// No description provided for @appearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearanceTitle;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeFollowSystem;

  /// No description provided for @coverOnlineTitle.
  ///
  /// In zh, this message translates to:
  /// **'在线补齐封面'**
  String get coverOnlineTitle;

  /// No description provided for @coverOnlineSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本地无封面时联网检索（MusicBrainz → iTunes）'**
  String get coverOnlineSubtitle;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出登录 B 站？'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'退出后提取将回到匿名音质（64k）。'**
  String get logoutConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @logoutAction.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logoutAction;

  /// No description provided for @logoutButton.
  ///
  /// In zh, this message translates to:
  /// **'登出'**
  String get logoutButton;

  /// No description provided for @biliUserFallback.
  ///
  /// In zh, this message translates to:
  /// **'B 站用户'**
  String get biliUserFallback;

  /// No description provided for @loginBili.
  ///
  /// In zh, this message translates to:
  /// **'登录 B 站'**
  String get loginBili;

  /// No description provided for @accountLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'Lv.{level} · 已登录（高音质提取可用）'**
  String accountLoggedIn(int level);

  /// No description provided for @accountAnonymousSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'扫码或 Cookie 登录，解锁高音质提取'**
  String get accountAnonymousSubtitle;

  /// No description provided for @audioPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'未获得音乐读取权限——请在系统设置中授权后重试'**
  String get audioPermissionDenied;

  /// No description provided for @dirMissing.
  ///
  /// In zh, this message translates to:
  /// **'目录不存在：{path}'**
  String dirMissing(String path);

  /// No description provided for @repoAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加仓库并完成扫描：{path}'**
  String repoAdded(String path);

  /// No description provided for @rescanTriggered.
  ///
  /// In zh, this message translates to:
  /// **'已触发重新扫描'**
  String get rescanTriggered;

  /// 识别修正入队反馈（D5-5：输出语言跟随 UI 语言）
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{已排队识别修正：{count} 首}}'**
  String enrichQueued(int count);

  /// No description provided for @repoSection.
  ///
  /// In zh, this message translates to:
  /// **'音乐仓库'**
  String get repoSection;

  /// No description provided for @repoHint.
  ///
  /// In zh, this message translates to:
  /// **'提取的曲目保存在 仓库/提取/ 下；删除仓库不删文件。'**
  String get repoHint;

  /// No description provided for @enrichTooltip.
  ///
  /// In zh, this message translates to:
  /// **'识别修正（歌名/歌词/封面）'**
  String get enrichTooltip;

  /// No description provided for @rescanTooltip.
  ///
  /// In zh, this message translates to:
  /// **'重新扫描'**
  String get rescanTooltip;

  /// No description provided for @repoEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无仓库——添加一个本地音乐目录开始'**
  String get repoEmpty;

  /// No description provided for @repoAddLabel.
  ///
  /// In zh, this message translates to:
  /// **'添加仓库目录'**
  String get repoAddLabel;

  /// No description provided for @repoBrowseLabel.
  ///
  /// In zh, this message translates to:
  /// **'浏览选择目录'**
  String get repoBrowseLabel;

  /// No description provided for @repoPathHint.
  ///
  /// In zh, this message translates to:
  /// **'或输入音乐目录绝对路径'**
  String get repoPathHint;

  /// No description provided for @addLabel.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addLabel;

  /// No description provided for @aboutSection.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutSection;

  /// No description provided for @aboutBody.
  ///
  /// In zh, this message translates to:
  /// **'iA Music · 本地优先音乐播放器\nB 站发现 → 提取 → 歌词/封面补全 → 曲库\nUI 参照 Harmonoid（仅视觉语言，PolyForm 许可不复制代码）'**
  String get aboutBody;

  /// No description provided for @shuffleTooltip.
  ///
  /// In zh, this message translates to:
  /// **'随机播放（随机池=全库−少播）'**
  String get shuffleTooltip;

  /// No description provided for @viewListTooltip.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get viewListTooltip;

  /// No description provided for @viewGridTooltip.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get viewGridTooltip;

  /// No description provided for @trackCount.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 首}}'**
  String trackCount(int count);

  /// No description provided for @sortRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近'**
  String get sortRecent;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In zh, this message translates to:
  /// **'歌手'**
  String get sortArtist;

  /// No description provided for @sortDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get sortDuration;

  /// No description provided for @untitled.
  ///
  /// In zh, this message translates to:
  /// **'未命名'**
  String get untitled;

  /// No description provided for @unknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知歌手'**
  String get unknownArtist;

  /// No description provided for @sourceBili.
  ///
  /// In zh, this message translates to:
  /// **'B站'**
  String get sourceBili;

  /// No description provided for @missingBadge.
  ///
  /// In zh, this message translates to:
  /// **'文件缺失'**
  String get missingBadge;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'曲库是空的'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryBody.
  ///
  /// In zh, this message translates to:
  /// **'扫描本地音乐目录，或从 B 站搜索提取你的第一首歌。'**
  String get emptyLibraryBody;

  /// No description provided for @emptyGoSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置添加仓库'**
  String get emptyGoSettings;

  /// No description provided for @emptyGoSearch.
  ///
  /// In zh, this message translates to:
  /// **'去 B 站搜索提取'**
  String get emptyGoSearch;

  /// No description provided for @albumCount.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 张专辑}}'**
  String albumCount(int count);

  /// No description provided for @albumsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无专辑（曲目补全后自动归档）'**
  String get albumsEmpty;

  /// No description provided for @albumTrackCount.
  ///
  /// In zh, this message translates to:
  /// **'专辑 · {count, plural, other{{count} 首}}'**
  String albumTrackCount(int count);

  /// No description provided for @playAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get playAll;

  /// No description provided for @shuffleShort.
  ///
  /// In zh, this message translates to:
  /// **'随机'**
  String get shuffleShort;

  /// No description provided for @artistCount.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 位艺术家}}'**
  String artistCount(int count);

  /// No description provided for @artistsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无艺术家'**
  String get artistsEmpty;

  /// No description provided for @artistTrackCount.
  ///
  /// In zh, this message translates to:
  /// **'艺术家 · {count, plural, other{{count} 首}}'**
  String artistTrackCount(int count);

  /// No description provided for @playlistCreateTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建歌单'**
  String get playlistCreateTitle;

  /// No description provided for @playlistNameHint.
  ///
  /// In zh, this message translates to:
  /// **'歌单名称'**
  String get playlistNameHint;

  /// No description provided for @createAction.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createAction;

  /// No description provided for @playlistsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有歌单。红心的歌会进「我喜欢的音乐」。'**
  String get playlistsEmpty;

  /// No description provided for @playlistPlayAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部（{count, plural, other{{count} 首}}）'**
  String playlistPlayAll(int count);

  /// No description provided for @playlistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'歌单是空的'**
  String get playlistEmpty;

  /// No description provided for @playlistRemoveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'从歌单移除'**
  String get playlistRemoveTooltip;

  /// No description provided for @shufflingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'随机播放中'**
  String get shufflingSubtitle;

  /// No description provided for @pauseTooltip.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pauseTooltip;

  /// No description provided for @playTooltip.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playTooltip;

  /// No description provided for @previousTooltip.
  ///
  /// In zh, this message translates to:
  /// **'上一首'**
  String get previousTooltip;

  /// No description provided for @nextTooltip.
  ///
  /// In zh, this message translates to:
  /// **'下一首'**
  String get nextTooltip;

  /// No description provided for @queueTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get queueTitle;

  /// No description provided for @queueEmpty.
  ///
  /// In zh, this message translates to:
  /// **'队列为空'**
  String get queueEmpty;

  /// No description provided for @eqTitle.
  ///
  /// In zh, this message translates to:
  /// **'音效'**
  String get eqTitle;

  /// No description provided for @eqUnsupportedTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前播放引擎不支持均衡器'**
  String get eqUnsupportedTitle;

  /// No description provided for @eqUnsupportedBody.
  ///
  /// In zh, this message translates to:
  /// **'mpv_audio_kit 以单 Player 实例发布媒体会话，\n未暴露均衡器波段接口；本页明示不支持，不伪造滑杆。'**
  String get eqUnsupportedBody;

  /// No description provided for @shuffleNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'随机会话未开始'**
  String get shuffleNotStarted;

  /// No description provided for @dislikeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'移出随机池（少播）'**
  String get dislikeTooltip;

  /// No description provided for @heartTooltip.
  ///
  /// In zh, this message translates to:
  /// **'红心'**
  String get heartTooltip;

  /// No description provided for @unheartTooltip.
  ///
  /// In zh, this message translates to:
  /// **'取消红心'**
  String get unheartTooltip;

  /// No description provided for @swipeUpHint.
  ///
  /// In zh, this message translates to:
  /// **'上滑切歌 · 单轮内不重复'**
  String get swipeUpHint;

  /// No description provided for @lyricsTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌词'**
  String get lyricsTitle;

  /// No description provided for @sourceBiliSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'B站字幕'**
  String get sourceBiliSubtitle;

  /// No description provided for @sourceAsr.
  ///
  /// In zh, this message translates to:
  /// **'语音识别'**
  String get sourceAsr;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loading;

  /// No description provided for @lyricsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'本曲暂无歌词'**
  String get lyricsEmptyTitle;

  /// No description provided for @lyricsEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'歌词在提取入库时自动生成：\n在线歌词库 → B 站字幕 → 本地语音识别，逐级兜底；\n反查命中后回填标准歌词与封面。'**
  String get lyricsEmptyBody;

  /// No description provided for @modeLoops.
  ///
  /// In zh, this message translates to:
  /// **'列表循环'**
  String get modeLoops;

  /// No description provided for @modeSingle.
  ///
  /// In zh, this message translates to:
  /// **'单曲循环'**
  String get modeSingle;

  /// No description provided for @modeSequence.
  ///
  /// In zh, this message translates to:
  /// **'顺序播放'**
  String get modeSequence;

  /// No description provided for @modeRandom.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get modeRandom;

  /// No description provided for @playTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playTitle;

  /// No description provided for @nothingPlaying.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放内容'**
  String get nothingPlaying;

  /// No description provided for @wheelTooltip.
  ///
  /// In zh, this message translates to:
  /// **'随机轮盘'**
  String get wheelTooltip;

  /// No description provided for @shuffleOnTooltip.
  ///
  /// In zh, this message translates to:
  /// **'随机中（点按改顺序）'**
  String get shuffleOnTooltip;

  /// No description provided for @dislikeLongTooltip.
  ///
  /// In zh, this message translates to:
  /// **'垃圾桶（减少推荐）'**
  String get dislikeLongTooltip;

  /// No description provided for @heartLongTooltip.
  ///
  /// In zh, this message translates to:
  /// **'红心（加入「我喜欢的音乐」）'**
  String get heartLongTooltip;

  /// No description provided for @biliNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'网络连不上 B 站——请检查设备的网络连接后重试'**
  String get biliNetworkError;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败：{error}'**
  String searchFailed(String error);

  /// No description provided for @extractQueued.
  ///
  /// In zh, this message translates to:
  /// **'已加入提取队列：{title}'**
  String extractQueued(String title);

  /// No description provided for @searchHintBili.
  ///
  /// In zh, this message translates to:
  /// **'搜索 B 站 / 粘贴链接或 BV 号'**
  String get searchHintBili;

  /// No description provided for @searchHintLocal.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌曲 / 歌手 / 专辑'**
  String get searchHintLocal;

  /// No description provided for @segmentLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地曲库'**
  String get segmentLocal;

  /// No description provided for @segmentBili.
  ///
  /// In zh, this message translates to:
  /// **'B 站'**
  String get segmentBili;

  /// No description provided for @searchLocalHint.
  ///
  /// In zh, this message translates to:
  /// **'试试搜索歌手或歌名；支持拼音首字母'**
  String get searchLocalHint;

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到与「{query}」相关的音乐'**
  String searchNoResults(String query);

  /// No description provided for @scanLoginBili.
  ///
  /// In zh, this message translates to:
  /// **'扫码登录 B 站'**
  String get scanLoginBili;

  /// No description provided for @retryAction.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retryAction;

  /// No description provided for @biliNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关内容，换个关键词试试'**
  String get biliNoResults;

  /// No description provided for @openExtractQueue.
  ///
  /// In zh, this message translates to:
  /// **'打开提取队列'**
  String get openExtractQueue;

  /// No description provided for @biliRowMeta.
  ///
  /// In zh, this message translates to:
  /// **'{uploader} · {duration} · 播放 {plays}'**
  String biliRowMeta(String uploader, String duration, String plays);

  /// No description provided for @extractTooltip.
  ///
  /// In zh, this message translates to:
  /// **'提取音频入库（含歌词补全链路）'**
  String get extractTooltip;

  /// No description provided for @parseFailed.
  ///
  /// In zh, this message translates to:
  /// **'解析失败：{error}'**
  String parseFailed(String error);

  /// No description provided for @taskEnqueued.
  ///
  /// In zh, this message translates to:
  /// **'已入队：{title}'**
  String taskEnqueued(String title);

  /// No description provided for @taskExists.
  ///
  /// In zh, this message translates to:
  /// **'任务已存在，继续沿用'**
  String get taskExists;

  /// No description provided for @navExtract.
  ///
  /// In zh, this message translates to:
  /// **'提取'**
  String get navExtract;

  /// No description provided for @extractTitle.
  ///
  /// In zh, this message translates to:
  /// **'提取'**
  String get extractTitle;

  /// No description provided for @extractIntro.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 B 站链接 / 分享文本，或输入关键词解析合集；提取后自动补全歌名、歌手、封面与歌词。'**
  String get extractIntro;

  /// No description provided for @extractInputHint.
  ///
  /// In zh, this message translates to:
  /// **'https://www.bilibili.com/video/… 或分享文本'**
  String get extractInputHint;

  /// No description provided for @parseAction.
  ///
  /// In zh, this message translates to:
  /// **'解析'**
  String get parseAction;

  /// No description provided for @optOnlineLyrics.
  ///
  /// In zh, this message translates to:
  /// **'在线歌词'**
  String get optOnlineLyrics;

  /// No description provided for @optBiliSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'B 站字幕'**
  String get optBiliSubtitle;

  /// No description provided for @taskQueueTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务队列'**
  String get taskQueueTitle;

  /// No description provided for @taskQueueEmpty.
  ///
  /// In zh, this message translates to:
  /// **'队列为空。粘贴一条 B 站链接开始。'**
  String get taskQueueEmpty;

  /// No description provided for @extractAction.
  ///
  /// In zh, this message translates to:
  /// **'提取'**
  String get extractAction;

  /// No description provided for @statusResolved.
  ///
  /// In zh, this message translates to:
  /// **'已解析'**
  String get statusResolved;

  /// No description provided for @statusGating.
  ///
  /// In zh, this message translates to:
  /// **'门禁中'**
  String get statusGating;

  /// No description provided for @statusGated.
  ///
  /// In zh, this message translates to:
  /// **'已拦截'**
  String get statusGated;

  /// No description provided for @complianceTitle.
  ///
  /// In zh, this message translates to:
  /// **'提取前请确认'**
  String get complianceTitle;

  /// No description provided for @complianceBody.
  ///
  /// In zh, this message translates to:
  /// **'• 提取仅限个人收听用途，请尊重创作者权益\n• 提取内容不入任何公开分发渠道\n• 你需要对提交的链接内容负责'**
  String get complianceBody;

  /// No description provided for @complianceAck.
  ///
  /// In zh, this message translates to:
  /// **'我已阅读并确认'**
  String get complianceAck;

  /// No description provided for @qrScanHint.
  ///
  /// In zh, this message translates to:
  /// **'用 B 站 App 扫码登录'**
  String get qrScanHint;

  /// No description provided for @qrFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'二维码获取失败：{error}'**
  String qrFetchFailed(String error);

  /// No description provided for @qrWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待扫码…'**
  String get qrWaiting;

  /// No description provided for @qrScanned.
  ///
  /// In zh, this message translates to:
  /// **'已扫码，请在手机上确认'**
  String get qrScanned;

  /// No description provided for @loginSuccess.
  ///
  /// In zh, this message translates to:
  /// **'登录成功'**
  String get loginSuccess;

  /// No description provided for @welcomeUnlocked.
  ///
  /// In zh, this message translates to:
  /// **'欢迎，{name}（高音质提取已解锁）'**
  String welcomeUnlocked(String name);

  /// No description provided for @qrExpired.
  ///
  /// In zh, this message translates to:
  /// **'二维码已过期，请刷新'**
  String get qrExpired;

  /// No description provided for @cookieImported.
  ///
  /// In zh, this message translates to:
  /// **'Cookie 已导入'**
  String get cookieImported;

  /// No description provided for @cookieInvalid.
  ///
  /// In zh, this message translates to:
  /// **'Cookie 无效或已过期'**
  String get cookieInvalid;

  /// No description provided for @qrRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新二维码'**
  String get qrRefresh;

  /// No description provided for @cookieSection.
  ///
  /// In zh, this message translates to:
  /// **'或粘贴 Cookie（SESSDATA=…）'**
  String get cookieSection;

  /// No description provided for @cookieHint.
  ///
  /// In zh, this message translates to:
  /// **'从浏览器登录 B 站后复制 Cookie'**
  String get cookieHint;

  /// No description provided for @importCookie.
  ///
  /// In zh, this message translates to:
  /// **'导入 Cookie'**
  String get importCookie;

  /// No description provided for @dirReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取该目录（{reason}）'**
  String dirReadFailed(String reason);

  /// No description provided for @permissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'权限不足'**
  String get permissionDenied;

  /// No description provided for @internalStorage.
  ///
  /// In zh, this message translates to:
  /// **'内部存储'**
  String get internalStorage;

  /// No description provided for @levelUpTooltip.
  ///
  /// In zh, this message translates to:
  /// **'上一级'**
  String get levelUpTooltip;

  /// No description provided for @dirBrowserStat.
  ///
  /// In zh, this message translates to:
  /// **'{dirs, plural, other{{dirs} 个子目录}} · {audio, plural, other{{audio} 个音频文件}}'**
  String dirBrowserStat(int dirs, int audio);

  /// No description provided for @noSubdirs.
  ///
  /// In zh, this message translates to:
  /// **'没有子目录了——可以直接选择当前目录'**
  String get noSubdirs;

  /// No description provided for @pickThisDir.
  ///
  /// In zh, this message translates to:
  /// **'选择此目录（{name}）'**
  String pickThisDir(String name);

  /// No description provided for @grantAudioPermission.
  ///
  /// In zh, this message translates to:
  /// **'授予音乐读取权限'**
  String get grantAudioPermission;

  /// No description provided for @openSystemSettings.
  ///
  /// In zh, this message translates to:
  /// **'去系统设置开启'**
  String get openSystemSettings;

  /// No description provided for @coverSuffix.
  ///
  /// In zh, this message translates to:
  /// **'封面'**
  String get coverSuffix;

  /// No description provided for @emptyPoolForShuffle.
  ///
  /// In zh, this message translates to:
  /// **'曲库是空的。先导入音乐，才能随机播放'**
  String get emptyPoolForShuffle;

  /// No description provided for @emptyPoolForPlay.
  ///
  /// In zh, this message translates to:
  /// **'曲库是空的。先导入音乐，才能播放'**
  String get emptyPoolForPlay;

  /// No description provided for @fewWatchedNotice.
  ///
  /// In zh, this message translates to:
  /// **'已减少这首的推荐'**
  String get fewWatchedNotice;

  /// No description provided for @missingSkipped.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》文件缺失，已跳过'**
  String missingSkipped(String title);

  /// No description provided for @corruptSkipped.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》无法播放该文件（格式或文件损坏），已跳过'**
  String corruptSkipped(String title);

  /// No description provided for @serviceBrokenNotice.
  ///
  /// In zh, this message translates to:
  /// **'播放服务异常'**
  String get serviceBrokenNotice;

  /// No description provided for @noContentInLink.
  ///
  /// In zh, this message translates to:
  /// **'未在链接中找到内容'**
  String get noContentInLink;

  /// No description provided for @subtitleExtractFailed.
  ///
  /// In zh, this message translates to:
  /// **'字幕文本提取失败：{error}'**
  String subtitleExtractFailed(String error);

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知异常'**
  String get unknownError;

  /// No description provided for @noSubtitleAvailable.
  ///
  /// In zh, this message translates to:
  /// **'该视频没有可用的字幕文本（AI 字幕需登录 B 站）'**
  String get noSubtitleAvailable;

  /// No description provided for @subtitleNotSavedNoRepo.
  ///
  /// In zh, this message translates to:
  /// **'字幕文本未保存：尚未配置音乐仓库'**
  String get subtitleNotSavedNoRepo;

  /// No description provided for @subtitleSplitSaved.
  ///
  /// In zh, this message translates to:
  /// **'字幕文本已按 {count} 段拆分保存'**
  String subtitleSplitSaved(int count);

  /// No description provided for @subtitleSaved.
  ///
  /// In zh, this message translates to:
  /// **'字幕文本已保存：{path}'**
  String subtitleSaved(String path);

  /// No description provided for @extractTerminated.
  ///
  /// In zh, this message translates to:
  /// **'提取执行失败，任务已终止'**
  String get extractTerminated;

  /// No description provided for @noRepoConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置音乐仓库，请先在「设置」添加仓库'**
  String get noRepoConfigured;

  /// No description provided for @downloadPaused.
  ///
  /// In zh, this message translates to:
  /// **'下载中断，已暂停，联网后自动继续'**
  String get downloadPaused;

  /// No description provided for @transcodeFailed.
  ///
  /// In zh, this message translates to:
  /// **'产物转码失败'**
  String get transcodeFailed;

  /// No description provided for @videoDirNotWritable.
  ///
  /// In zh, this message translates to:
  /// **'视频目录不可写，任务终止'**
  String get videoDirNotWritable;

  /// No description provided for @videoMoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'视频迁移失败：目标目录不可写'**
  String get videoMoveFailed;

  /// No description provided for @videoSavedNote.
  ///
  /// In zh, this message translates to:
  /// **'视频已保存到 仓库/提取/视频（不入曲库）'**
  String get videoSavedNote;

  /// No description provided for @parsingLink.
  ///
  /// In zh, this message translates to:
  /// **'解析链接…'**
  String get parsingLink;

  /// No description provided for @linkParseDead.
  ///
  /// In zh, this message translates to:
  /// **'链接解析失败：链接可能已失效，或该内容需要登录'**
  String get linkParseDead;

  /// No description provided for @linkParseNoContent.
  ///
  /// In zh, this message translates to:
  /// **'链接解析失败：未找到内容'**
  String get linkParseNoContent;

  /// No description provided for @analyzingAudio.
  ///
  /// In zh, this message translates to:
  /// **'分析音频内容…'**
  String get analyzingAudio;

  /// No description provided for @audioMoveFailed.
  ///
  /// In zh, this message translates to:
  /// **'产物迁移失败：目标目录不可写'**
  String get audioMoveFailed;

  /// No description provided for @registerFailedIsolated.
  ///
  /// In zh, this message translates to:
  /// **'注册失败：产物已隔离，不影响曲库'**
  String get registerFailedIsolated;

  /// No description provided for @splitFailedWhole.
  ///
  /// In zh, this message translates to:
  /// **'拆分失败，按完整音轨入库'**
  String get splitFailedWhole;

  /// No description provided for @splitProgress.
  ///
  /// In zh, this message translates to:
  /// **'已拆分 {done}/{total} 首：{title}'**
  String splitProgress(int done, int total, String title);

  /// No description provided for @splitDone.
  ///
  /// In zh, this message translates to:
  /// **'合集已拆分为 {count} 首，歌名/封面/歌词已按段补全'**
  String splitDone(int count);

  /// No description provided for @splitRegisterFailed.
  ///
  /// In zh, this message translates to:
  /// **'拆分注册失败：产物已隔离'**
  String get splitRegisterFailed;

  /// No description provided for @noSongBoundary.
  ///
  /// In zh, this message translates to:
  /// **'未检测到歌曲分界，按完整音轨入库'**
  String get noSongBoundary;

  /// No description provided for @failureAuth.
  ///
  /// In zh, this message translates to:
  /// **'B 站登录状态过期，请重新扫码'**
  String get failureAuth;

  /// No description provided for @failureDisk.
  ///
  /// In zh, this message translates to:
  /// **'存储空间不足，请清理后重试'**
  String get failureDisk;

  /// No description provided for @failureUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'该内容暂不支持提取（付费/地区/格式受限，或工具链需更新）'**
  String get failureUnsupported;

  /// No description provided for @failureNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络连接中断，任务已暂停，本地数据不受影响'**
  String get failureNetwork;

  /// No description provided for @noLinkInShareText.
  ///
  /// In zh, this message translates to:
  /// **'未在分享文本中找到链接'**
  String get noLinkInShareText;

  /// No description provided for @desktopOnlyExtract.
  ///
  /// In zh, this message translates to:
  /// **'提取功能当前为桌面端形态（Windows），Android 端将在后续版本支持'**
  String get desktopOnlyExtract;

  /// No description provided for @linkNeedLogin.
  ///
  /// In zh, this message translates to:
  /// **'链接解析失败：该内容需要登录，或链接已失效。可登录 B 站账号后再试'**
  String get linkNeedLogin;

  /// No description provided for @linkFormatUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'该链接格式暂不支持提取（付费/地区/平台形态受限，或提取工具链需要更新）'**
  String get linkFormatUnsupported;

  /// No description provided for @engineNotInit.
  ///
  /// In zh, this message translates to:
  /// **'提取引擎未初始化（Android）'**
  String get engineNotInit;

  /// No description provided for @linkParseTimeout.
  ///
  /// In zh, this message translates to:
  /// **'链接解析失败：网络超时，请检查网络后重试（或链接已失效）'**
  String get linkParseTimeout;

  /// No description provided for @linkParseUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'链接解析失败：链接格式无法识别，请确认是 B 站视频/合集链接'**
  String get linkParseUnrecognized;

  /// No description provided for @engineErrorAndroid.
  ///
  /// In zh, this message translates to:
  /// **'提取引擎异常（Android）：{detail}'**
  String engineErrorAndroid(String detail);

  /// No description provided for @searchQueryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'搜索词为空'**
  String get searchQueryEmpty;

  /// No description provided for @douyinUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'抖音搜索需平台签名登录态，当前版本支持粘贴分享链接提取'**
  String get douyinUnsupported;

  /// No description provided for @riskControlIntercepted.
  ///
  /// In zh, this message translates to:
  /// **'平台风控拦截，请稍后再试或登录 B 站账号'**
  String get riskControlIntercepted;

  /// No description provided for @searchApiFailed.
  ///
  /// In zh, this message translates to:
  /// **'B 站搜索失败（{code}）：{reason}'**
  String searchApiFailed(String code, String reason);

  /// No description provided for @unknownReason.
  ///
  /// In zh, this message translates to:
  /// **'未知原因'**
  String get unknownReason;

  /// No description provided for @responseNotJson.
  ///
  /// In zh, this message translates to:
  /// **'响应不是 JSON 对象'**
  String get responseNotJson;

  /// No description provided for @qrCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录二维码获取失败（{code}）'**
  String qrCreateFailed(String code);

  /// No description provided for @qrDataIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'登录二维码数据不完整'**
  String get qrDataIncomplete;

  /// No description provided for @pollFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录状态查询失败（{code}）'**
  String pollFailed(String code);

  /// No description provided for @dbRecoveryHint.
  ///
  /// In zh, this message translates to:
  /// **'数据库打开异常：已进入只读保护，你的数据未丢失；请在设置的「修复引导」中处理。'**
  String get dbRecoveryHint;

  /// No description provided for @eqBandsNote.
  ///
  /// In zh, this message translates to:
  /// **'5 段均衡 · ±12dB · 拖动实时生效'**
  String get eqBandsNote;

  /// No description provided for @eqPresetDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get eqPresetDefault;

  /// No description provided for @eqPresetPop.
  ///
  /// In zh, this message translates to:
  /// **'流行'**
  String get eqPresetPop;

  /// No description provided for @eqPresetRock.
  ///
  /// In zh, this message translates to:
  /// **'摇滚'**
  String get eqPresetRock;

  /// No description provided for @eqPresetClassical.
  ///
  /// In zh, this message translates to:
  /// **'古典'**
  String get eqPresetClassical;

  /// No description provided for @eqPresetJazz.
  ///
  /// In zh, this message translates to:
  /// **'爵士'**
  String get eqPresetJazz;

  /// No description provided for @eqPresetBass.
  ///
  /// In zh, this message translates to:
  /// **'低音增强'**
  String get eqPresetBass;

  /// No description provided for @eqPresetCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get eqPresetCustom;

  /// No description provided for @eqBandLabel.
  ///
  /// In zh, this message translates to:
  /// **'{hz}'**
  String eqBandLabel(String hz);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
