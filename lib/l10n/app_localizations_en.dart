// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'iA Music';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSearch => 'Search';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Settings';

  @override
  String get tabTracks => 'Tracks';

  @override
  String get tabAlbums => 'Albums';

  @override
  String get tabArtists => 'Artists';

  @override
  String get sortTitle => 'By title';

  @override
  String get sortArtist => 'By artist';

  @override
  String get sortAlbum => 'By album';

  @override
  String get sortRecent => 'Recently added';

  @override
  String get playAll => 'Play all';

  @override
  String get shuffleAll => 'Shuffle';

  @override
  String get emptyLibraryTitle => 'Your library is empty';

  @override
  String get emptyLibraryHint => 'Add a music folder to start scanning.';

  @override
  String emptySearchTitle(String query) {
    return 'No results for “$query”';
  }

  @override
  String get emptySearchHint =>
      'Try a different keyword or the pinyin spelling.';

  @override
  String get emptyPlaylists => 'No playlists yet';

  @override
  String get emptyHistory => 'No play history yet';

  @override
  String get emptyQueue => 'The queue is empty';

  @override
  String get searchHint => 'Search songs, artists, albums or pinyin';

  @override
  String get searchResults => 'Results';

  @override
  String get playlistMine => 'Your playlists';

  @override
  String get playlistFavorites => 'Liked songs';

  @override
  String get playlistHistory => 'Recently played';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get playlistNameHint => 'Playlist name';

  @override
  String get renamePlaylist => 'Rename';

  @override
  String get deletePlaylist => 'Delete playlist';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Delete playlist “$name”? Songs won\'t be removed.';
  }

  @override
  String playlistCount(int n) {
    return '$n songs';
  }

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String addedToPlaylist(String name) {
    return 'Added to “$name”';
  }

  @override
  String get playNext => 'Play next';

  @override
  String get queueTitle => 'Queue';

  @override
  String get clearQueue => 'Clear queue';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics';

  @override
  String get lyricsPureMusic => 'Instrumental';

  @override
  String get historyTitle => 'Recently played';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryConfirm => 'Clear all play history?';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionLibrary => 'Library';

  @override
  String get musicFolders => 'Music folders';

  @override
  String get addFolder => 'Add folder';

  @override
  String get removeFolder => 'Remove';

  @override
  String get rescanAll => 'Rescan all';

  @override
  String get folderAlreadyAdded => 'This folder is already in the library';

  @override
  String scanning(int done, int total) {
    return 'Scanning… $done/$total';
  }

  @override
  String scanComplete(int n) {
    return 'Scan finished, $n tracks';
  }

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get sectionAbout => 'About';

  @override
  String get aboutVersion => 'Version';

  @override
  String get onboardingTitle => 'Welcome to iA Music';

  @override
  String get onboardingSubtitle =>
      'A local-first music library: bring your scattered music together, see it clearly, hear it at its best.';

  @override
  String get onboardingPickFolder => 'Choose a music folder';

  @override
  String get onboardingSkip => 'Skip for now';

  @override
  String get trackMissing => 'File missing';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get unknownAlbum => 'Unknown album';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get remove => 'Remove';

  @override
  String get delete => 'Delete';
}
