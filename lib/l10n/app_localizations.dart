import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
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
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

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
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'iA 音乐'**
  String get appTitle;

  /// No description provided for @navLibrary.
  ///
  /// In zh, this message translates to:
  /// **'曲库'**
  String get navLibrary;

  /// No description provided for @navSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get navSearch;

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

  /// No description provided for @tabTracks.
  ///
  /// In zh, this message translates to:
  /// **'曲目'**
  String get tabTracks;

  /// No description provided for @tabAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get tabAlbums;

  /// No description provided for @tabArtists.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get tabArtists;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'按标题'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In zh, this message translates to:
  /// **'按歌手'**
  String get sortArtist;

  /// No description provided for @sortAlbum.
  ///
  /// In zh, this message translates to:
  /// **'按专辑'**
  String get sortAlbum;

  /// No description provided for @sortRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近添加'**
  String get sortRecent;

  /// No description provided for @playAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get playAll;

  /// No description provided for @shuffleAll.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get shuffleAll;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'曲库还是空的'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryHint.
  ///
  /// In zh, this message translates to:
  /// **'添加一个音乐文件夹，开始扫描入库。'**
  String get emptyLibraryHint;

  /// No description provided for @emptySearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有找到“{query}”'**
  String emptySearchTitle(String query);

  /// No description provided for @emptySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'试试换个关键词，或检查拼音/全名。'**
  String get emptySearchHint;

  /// No description provided for @emptyPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'还没有歌单'**
  String get emptyPlaylists;

  /// No description provided for @emptyHistory.
  ///
  /// In zh, this message translates to:
  /// **'还没有播放记录'**
  String get emptyHistory;

  /// No description provided for @emptyQueue.
  ///
  /// In zh, this message translates to:
  /// **'播放队列为空'**
  String get emptyQueue;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌曲、歌手、专辑或拼音'**
  String get searchHint;

  /// No description provided for @searchResults.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果'**
  String get searchResults;

  /// No description provided for @playlistMine.
  ///
  /// In zh, this message translates to:
  /// **'我的歌单'**
  String get playlistMine;

  /// No description provided for @playlistFavorites.
  ///
  /// In zh, this message translates to:
  /// **'我喜欢的音乐'**
  String get playlistFavorites;

  /// No description provided for @playlistHistory.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get playlistHistory;

  /// No description provided for @newPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'新建歌单'**
  String get newPlaylist;

  /// No description provided for @playlistNameHint.
  ///
  /// In zh, this message translates to:
  /// **'歌单名称'**
  String get playlistNameHint;

  /// No description provided for @renamePlaylist.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get renamePlaylist;

  /// No description provided for @deletePlaylist.
  ///
  /// In zh, this message translates to:
  /// **'删除歌单'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除歌单“{name}”？歌曲不会被删除。'**
  String deletePlaylistConfirm(String name);

  /// No description provided for @playlistCount.
  ///
  /// In zh, this message translates to:
  /// **'{n} 首'**
  String playlistCount(int n);

  /// No description provided for @addToPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'加入歌单'**
  String get addToPlaylist;

  /// No description provided for @addedToPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'已加入“{name}”'**
  String addedToPlaylist(String name);

  /// No description provided for @playNext.
  ///
  /// In zh, this message translates to:
  /// **'下一首播放'**
  String get playNext;

  /// No description provided for @queueTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get queueTitle;

  /// No description provided for @clearQueue.
  ///
  /// In zh, this message translates to:
  /// **'清空队列'**
  String get clearQueue;

  /// No description provided for @nowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get nowPlaying;

  /// No description provided for @lyricsTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌词'**
  String get lyricsTitle;

  /// No description provided for @lyricsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌词'**
  String get lyricsEmpty;

  /// No description provided for @lyricsPureMusic.
  ///
  /// In zh, this message translates to:
  /// **'纯音乐，请欣赏'**
  String get lyricsPureMusic;

  /// No description provided for @historyTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get historyTitle;

  /// No description provided for @clearHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空记录'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定清空全部播放记录？'**
  String get clearHistoryConfirm;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @sectionLibrary.
  ///
  /// In zh, this message translates to:
  /// **'曲库'**
  String get sectionLibrary;

  /// No description provided for @musicFolders.
  ///
  /// In zh, this message translates to:
  /// **'音乐文件夹'**
  String get musicFolders;

  /// No description provided for @addFolder.
  ///
  /// In zh, this message translates to:
  /// **'添加文件夹'**
  String get addFolder;

  /// No description provided for @removeFolder.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get removeFolder;

  /// No description provided for @rescanAll.
  ///
  /// In zh, this message translates to:
  /// **'重新扫描全部'**
  String get rescanAll;

  /// No description provided for @folderAlreadyAdded.
  ///
  /// In zh, this message translates to:
  /// **'该文件夹已在曲库中'**
  String get folderAlreadyAdded;

  /// No description provided for @scanning.
  ///
  /// In zh, this message translates to:
  /// **'扫描中… {done}/{total}'**
  String scanning(int done, int total);

  /// No description provided for @scanComplete.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成，共 {n} 首'**
  String scanComplete(int n);

  /// No description provided for @sectionAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get sectionAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @sectionLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get sectionLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @sectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get sectionAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get aboutVersion;

  /// No description provided for @onboardingTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 iA 音乐'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本地优先的个人音乐库：把散落的音乐收进来、看得清、听得好。'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingPickFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择音乐文件夹'**
  String get onboardingPickFolder;

  /// No description provided for @onboardingSkip.
  ///
  /// In zh, this message translates to:
  /// **'先跳过'**
  String get onboardingSkip;

  /// No description provided for @trackMissing.
  ///
  /// In zh, this message translates to:
  /// **'文件缺失'**
  String get trackMissing;

  /// No description provided for @unknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知歌手'**
  String get unknownArtist;

  /// No description provided for @unknownAlbum.
  ///
  /// In zh, this message translates to:
  /// **'未知专辑'**
  String get unknownAlbum;

  /// No description provided for @errorGeneric.
  ///
  /// In zh, this message translates to:
  /// **'出错了，请重试'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
