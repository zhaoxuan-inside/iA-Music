// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'iA 音乐';

  @override
  String get navLibrary => '曲库';

  @override
  String get navSearch => '搜索';

  @override
  String get navPlaylists => '歌单';

  @override
  String get navSettings => '设置';

  @override
  String get tabTracks => '曲目';

  @override
  String get tabAlbums => '专辑';

  @override
  String get tabArtists => '艺术家';

  @override
  String get sortTitle => '按标题';

  @override
  String get sortArtist => '按歌手';

  @override
  String get sortAlbum => '按专辑';

  @override
  String get sortRecent => '最近添加';

  @override
  String get playAll => '播放全部';

  @override
  String get shuffleAll => '随机播放';

  @override
  String get emptyLibraryTitle => '曲库还是空的';

  @override
  String get emptyLibraryHint => '添加一个音乐文件夹，开始扫描入库。';

  @override
  String emptySearchTitle(String query) {
    return '没有找到“$query”';
  }

  @override
  String get emptySearchHint => '试试换个关键词，或检查拼音/全名。';

  @override
  String get emptyPlaylists => '还没有歌单';

  @override
  String get emptyHistory => '还没有播放记录';

  @override
  String get emptyQueue => '播放队列为空';

  @override
  String get searchHint => '搜索歌曲、歌手、专辑或拼音';

  @override
  String get searchResults => '搜索结果';

  @override
  String get playlistMine => '我的歌单';

  @override
  String get playlistFavorites => '我喜欢的音乐';

  @override
  String get playlistHistory => '最近播放';

  @override
  String get newPlaylist => '新建歌单';

  @override
  String get playlistNameHint => '歌单名称';

  @override
  String get renamePlaylist => '重命名';

  @override
  String get deletePlaylist => '删除歌单';

  @override
  String deletePlaylistConfirm(String name) {
    return '确定删除歌单“$name”？歌曲不会被删除。';
  }

  @override
  String playlistCount(int n) {
    return '$n 首';
  }

  @override
  String get addToPlaylist => '加入歌单';

  @override
  String addedToPlaylist(String name) {
    return '已加入“$name”';
  }

  @override
  String get playNext => '下一首播放';

  @override
  String get queueTitle => '播放队列';

  @override
  String get clearQueue => '清空队列';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get lyricsTitle => '歌词';

  @override
  String get lyricsEmpty => '暂无歌词';

  @override
  String get lyricsPureMusic => '纯音乐，请欣赏';

  @override
  String get historyTitle => '最近播放';

  @override
  String get clearHistory => '清空记录';

  @override
  String get clearHistoryConfirm => '确定清空全部播放记录？';

  @override
  String get settingsTitle => '设置';

  @override
  String get sectionLibrary => '曲库';

  @override
  String get musicFolders => '音乐文件夹';

  @override
  String get addFolder => '添加文件夹';

  @override
  String get removeFolder => '移除';

  @override
  String get rescanAll => '重新扫描全部';

  @override
  String get folderAlreadyAdded => '该文件夹已在曲库中';

  @override
  String scanning(int done, int total) {
    return '扫描中… $done/$total';
  }

  @override
  String scanComplete(int n) {
    return '扫描完成，共 $n 首';
  }

  @override
  String get sectionAppearance => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get sectionLanguage => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get sectionAbout => '关于';

  @override
  String get aboutVersion => '版本';

  @override
  String get onboardingTitle => '欢迎使用 iA 音乐';

  @override
  String get onboardingSubtitle => '本地优先的个人音乐库：把散落的音乐收进来、看得清、听得好。';

  @override
  String get onboardingPickFolder => '选择音乐文件夹';

  @override
  String get onboardingSkip => '先跳过';

  @override
  String get trackMissing => '文件缺失';

  @override
  String get unknownArtist => '未知歌手';

  @override
  String get unknownAlbum => '未知专辑';

  @override
  String get errorGeneric => '出错了，请重试';

  @override
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get remove => '移除';

  @override
  String get delete => '删除';
}
