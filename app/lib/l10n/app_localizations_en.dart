// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navSearch => 'SEARCH';

  @override
  String get navLibrary => 'LIBRARY';

  @override
  String get navTracks => 'TRACKS';

  @override
  String get navAlbums => 'ALBUMS';

  @override
  String get navArtists => 'ARTISTS';

  @override
  String get navMore => 'MORE';

  @override
  String get navPlaylists => 'PLAYLISTS';

  @override
  String get navSettings => 'SETTINGS';

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageNameZh => '中文';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageFollowSystem => 'Follow system';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeFollowSystem => 'Follow system';

  @override
  String get coverOnlineTitle => 'Fetch covers online';

  @override
  String get coverOnlineSubtitle =>
      'Search online when no local cover (MusicBrainz → iTunes)';

  @override
  String get logoutConfirmTitle => 'Sign out of Bilibili?';

  @override
  String get logoutConfirmBody =>
      'After signing out, extraction falls back to anonymous quality (64k).';

  @override
  String get cancel => 'Cancel';

  @override
  String get logoutAction => 'Sign out';

  @override
  String get logoutButton => 'Sign out';

  @override
  String get biliUserFallback => 'Bilibili user';

  @override
  String get loginBili => 'Sign in to Bilibili';

  @override
  String accountLoggedIn(int level) {
    return 'Lv.$level · Signed in (HQ extract unlocked)';
  }

  @override
  String get accountAnonymousSubtitle =>
      'Scan QR or import Cookie to unlock HQ extract';

  @override
  String get audioPermissionDenied =>
      'Music read permission not granted — grant it in system settings and retry';

  @override
  String dirMissing(String path) {
    return 'Directory not found: $path';
  }

  @override
  String repoAdded(String path) {
    return 'Folder added and scanned: $path';
  }

  @override
  String get rescanTriggered => 'Rescan triggered';

  @override
  String enrichQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks queued for recognition fix',
      one: '1 track queued for recognition fix',
    );
    return '$_temp0';
  }

  @override
  String get repoSection => 'Music folders';

  @override
  String get repoHint =>
      'Extracted tracks are saved under <folder>/Extracts/; removing a folder never deletes files.';

  @override
  String get enrichTooltip => 'Fix recognition (title/lyrics/cover)';

  @override
  String get rescanTooltip => 'Rescan';

  @override
  String get repoEmpty => 'No folders yet — add a local music folder to start';

  @override
  String get repoAddLabel => 'Add music folder';

  @override
  String get repoBrowseLabel => 'Browse folders';

  @override
  String get repoPathHint => 'or type an absolute music folder path';

  @override
  String get addLabel => 'Add';

  @override
  String get aboutSection => 'About';

  @override
  String get aboutBody =>
      'iA Music · local-first music player\nBilibili discover → extract → lyrics/cover enrichment → library\nUI inspired by Harmonoid (visual language only, no code copied under PolyForm)';

  @override
  String get shuffleTooltip => 'Shuffle (pool = library − play-less)';

  @override
  String get viewListTooltip => 'List view';

  @override
  String get viewGridTooltip => 'Grid view';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String get sortRecent => 'Recent';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortDuration => 'Duration';

  @override
  String get untitled => 'Untitled';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get sourceBili => 'Bili';

  @override
  String get missingBadge => 'Missing';

  @override
  String get emptyLibraryTitle => 'Library is empty';

  @override
  String get emptyLibraryBody =>
      'Scan local music folders, or extract your first track from Bilibili.';

  @override
  String get emptyGoSettings => 'Add folders in Settings';

  @override
  String get emptyGoSearch => 'Search & extract from Bilibili';

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get albumsEmpty =>
      'No albums yet (auto-grouped once tracks are enriched)';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return 'Album · $_temp0';
  }

  @override
  String get playAll => 'Play all';

  @override
  String get shuffleShort => 'Shuffle';

  @override
  String artistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String get artistsEmpty => 'No artists yet';

  @override
  String artistTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return 'Artist · $_temp0';
  }

  @override
  String get playlistCreateTitle => 'New playlist';

  @override
  String get playlistNameHint => 'Playlist name';

  @override
  String get createAction => 'Create';

  @override
  String get playlistsEmpty =>
      'No playlists yet. Hearted tracks go to “Liked”.';

  @override
  String playlistPlayAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return 'Play all ($_temp0)';
  }

  @override
  String get playlistEmpty => 'Playlist is empty';

  @override
  String get playlistRemoveTooltip => 'Remove from playlist';

  @override
  String get shufflingSubtitle => 'Shuffle playing';

  @override
  String get pauseTooltip => 'Pause';

  @override
  String get playTooltip => 'Play';

  @override
  String get previousTooltip => 'Previous';

  @override
  String get nextTooltip => 'Next';

  @override
  String get queueTitle => 'Queue';

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get eqTitle => 'Audio effects';

  @override
  String get eqUnsupportedTitle =>
      'Equalizer not supported by the current engine';

  @override
  String get eqUnsupportedBody =>
      'mpv_audio_kit publishes the media session as a single Player and exposes no EQ bands; this page states that plainly instead of faking sliders.';

  @override
  String get shuffleNotStarted => 'Shuffle session not started';

  @override
  String get dislikeTooltip => 'Remove from shuffle pool (play less)';

  @override
  String get heartTooltip => 'Heart';

  @override
  String get unheartTooltip => 'Unheart';

  @override
  String get swipeUpHint => 'Swipe up to skip · no repeats within a round';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get sourceBiliSubtitle => 'Bilibili subtitles';

  @override
  String get sourceAsr => 'Speech recognition';

  @override
  String get loading => 'Loading…';

  @override
  String get lyricsEmptyTitle => 'No lyrics for this track';

  @override
  String get lyricsEmptyBody =>
      'Lyrics are generated when a track enters the library:\nonline lyrics DB → Bilibili subtitles → on-device speech recognition, in order;\nmatched lookups also backfill standard lyrics and covers.';

  @override
  String get modeLoops => 'List loop';

  @override
  String get modeSingle => 'Loop one';

  @override
  String get modeSequence => 'In order';

  @override
  String get modeRandom => 'Shuffle';

  @override
  String get playTitle => 'Player';

  @override
  String get nothingPlaying => 'Nothing is playing yet';

  @override
  String get wheelTooltip => 'Shuffle wheel';

  @override
  String get shuffleOnTooltip => 'Shuffling (tap for in-order)';

  @override
  String get dislikeLongTooltip => 'Trash (play less)';

  @override
  String get heartLongTooltip => 'Heart (add to “Liked”)';

  @override
  String get biliNetworkError =>
      'Cannot reach Bilibili — check the device network and retry';

  @override
  String searchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String extractQueued(String title) {
    return 'Queued for extraction: $title';
  }

  @override
  String get searchHintBili => 'Search Bilibili / paste link or BV id';

  @override
  String get searchHintLocal => 'Search songs / artists / albums';

  @override
  String get segmentLocal => 'Local library';

  @override
  String get segmentBili => 'Bilibili';

  @override
  String get searchLocalHint =>
      'Try an artist or song title; pinyin initials supported';

  @override
  String searchNoResults(String query) {
    return 'No music found for “$query”';
  }

  @override
  String get scanLoginBili => 'Scan QR to sign in to Bilibili';

  @override
  String get retryAction => 'Retry';

  @override
  String get biliNoResults => 'Nothing found — try different keywords';

  @override
  String get openExtractQueue => 'Open extract queue';

  @override
  String biliRowMeta(String uploader, String duration, String plays) {
    return '$uploader · $duration · $plays plays';
  }

  @override
  String get extractTooltip =>
      'Extract audio to library (with lyrics enrichment)';

  @override
  String parseFailed(String error) {
    return 'Parse failed: $error';
  }

  @override
  String taskEnqueued(String title) {
    return 'Queued: $title';
  }

  @override
  String get taskExists => 'Task already exists — reused';

  @override
  String get navExtract => 'Extract';

  @override
  String get extractTitle => 'EXTRACT';

  @override
  String get extractIntro =>
      'Paste a Bilibili link / share text, or type keywords to parse a collection; title, artist, cover and lyrics are auto-enriched after extraction.';

  @override
  String get extractInputHint =>
      'https://www.bilibili.com/video/… or share text';

  @override
  String get parseAction => 'Parse';

  @override
  String get optOnlineLyrics => 'Online lyrics';

  @override
  String get optBiliSubtitle => 'Bilibili subtitles';

  @override
  String get taskQueueTitle => 'Task queue';

  @override
  String get taskQueueEmpty =>
      'Queue is empty. Paste a Bilibili link to start.';

  @override
  String get extractAction => 'Extract';

  @override
  String get statusResolved => 'Parsed';

  @override
  String get statusGating => 'Gating';

  @override
  String get statusGated => 'Blocked';

  @override
  String get complianceTitle => 'Confirm before extracting';

  @override
  String get complianceBody =>
      '• Extraction is for personal listening only — respect creators\' rights\n• Extracted content never goes to any public distribution channel\n• You are responsible for the links you submit';

  @override
  String get complianceAck => 'I have read and agree';

  @override
  String get qrScanHint => 'Scan with the Bilibili app';

  @override
  String qrFetchFailed(String error) {
    return 'Failed to fetch QR code: $error';
  }

  @override
  String get qrWaiting => 'Waiting for scan…';

  @override
  String get qrScanned => 'Scanned — confirm on your phone';

  @override
  String get loginSuccess => 'Signed in';

  @override
  String welcomeUnlocked(String name) {
    return 'Welcome, $name (HQ extract unlocked)';
  }

  @override
  String get qrExpired => 'QR code expired — refresh';

  @override
  String get cookieImported => 'Cookie imported';

  @override
  String get cookieInvalid => 'Cookie invalid or expired';

  @override
  String get qrRefresh => 'Refresh QR code';

  @override
  String get cookieSection => 'Or paste a Cookie (SESSDATA=…)';

  @override
  String get cookieHint =>
      'Copy the Cookie after signing in to Bilibili in a browser';

  @override
  String get importCookie => 'Import Cookie';

  @override
  String dirReadFailed(String reason) {
    return 'Cannot read this folder ($reason)';
  }

  @override
  String get permissionDenied => 'permission denied';

  @override
  String get internalStorage => 'Internal storage';

  @override
  String get levelUpTooltip => 'Up one level';

  @override
  String dirBrowserStat(int dirs, int audio) {
    String _temp0 = intl.Intl.pluralLogic(
      dirs,
      locale: localeName,
      other: '$dirs subfolders',
      one: '1 subfolder',
    );
    String _temp1 = intl.Intl.pluralLogic(
      audio,
      locale: localeName,
      other: '$audio audio files',
      one: '1 audio file',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get noSubdirs => 'No subfolders — you can pick this folder directly';

  @override
  String pickThisDir(String name) {
    return 'Pick this folder ($name)';
  }

  @override
  String get grantAudioPermission => 'Grant music read permission';

  @override
  String get openSystemSettings => 'Open system settings';

  @override
  String get coverSuffix => 'cover';

  @override
  String get emptyPoolForShuffle =>
      'Library is empty. Import music to shuffle.';

  @override
  String get emptyPoolForPlay => 'Library is empty. Import music to play.';

  @override
  String get fewWatchedNotice => 'Noted — this one will be played less';

  @override
  String missingSkipped(String title) {
    return '《$title》 missing — skipped';
  }

  @override
  String corruptSkipped(String title) {
    return '《$title》 cannot be played (format or file damaged) — skipped';
  }

  @override
  String get serviceBrokenNotice => 'Playback service error';

  @override
  String get noContentInLink => 'No content found in the link';

  @override
  String subtitleExtractFailed(String error) {
    return 'Failed to extract subtitle text: $error';
  }

  @override
  String get unknownError => 'unknown error';

  @override
  String get noSubtitleAvailable =>
      'No subtitle text available for this video (AI subtitles require Bilibili sign-in)';

  @override
  String get subtitleNotSavedNoRepo =>
      'Subtitle text not saved: no music folder configured yet';

  @override
  String subtitleSplitSaved(int count) {
    return 'Subtitle text saved as $count segments';
  }

  @override
  String subtitleSaved(String path) {
    return 'Subtitle text saved: $path';
  }

  @override
  String get extractTerminated => 'Extraction failed; task terminated';

  @override
  String get noRepoConfigured =>
      'No music folder configured — add one in Settings first';

  @override
  String get downloadPaused =>
      'Download interrupted — paused; resumes automatically when online';

  @override
  String get transcodeFailed => 'Output transcode failed';

  @override
  String get videoDirNotWritable =>
      'Video folder not writable; task terminated';

  @override
  String get videoMoveFailed => 'Video move failed: target folder not writable';

  @override
  String get videoSavedNote =>
      'Video saved to <folder>/Extracts/Video (not added to library)';

  @override
  String get parsingLink => 'Parsing link…';

  @override
  String get linkParseDead =>
      'Failed to parse: the link may be dead, or login required';

  @override
  String get linkParseNoContent => 'Failed to parse: no content found';

  @override
  String get analyzingAudio => 'Analyzing audio…';

  @override
  String get audioMoveFailed =>
      'Output move failed: target folder not writable';

  @override
  String get registerFailedIsolated =>
      'Registration failed: output quarantined; library unaffected';

  @override
  String get splitFailedWhole => 'Split failed — added as one full track';

  @override
  String splitProgress(int done, int total, String title) {
    return 'Split $done/$total: $title';
  }

  @override
  String splitDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Collection split into $count tracks; title/cover/lyrics enriched per segment',
      one: 'Collection split into 1 track; title/cover/lyrics enriched per segment',
    );
    return '$_temp0';
  }

  @override
  String get splitRegisterFailed =>
      'Split registration failed: output quarantined';

  @override
  String get noSongBoundary =>
      'No song boundary detected — added as one full track';

  @override
  String get failureAuth => 'Bilibili session expired — scan the QR code again';

  @override
  String get failureDisk => 'Not enough storage — free up space and retry';

  @override
  String get failureUnsupported =>
      'This content cannot be extracted yet (paid/region/format restricted, or the toolchain needs an update)';

  @override
  String get failureNetwork =>
      'Network lost — task paused; local data unaffected';

  @override
  String get noLinkInShareText => 'No link found in the share text';

  @override
  String get desktopOnlyExtract =>
      'Extraction is currently desktop-only (Windows); Android support is coming in a later version';

  @override
  String get linkNeedLogin =>
      'Failed to parse: this content requires sign-in, or the link is dead. Sign in to Bilibili and try again';

  @override
  String get linkFormatUnsupported =>
      'This link format cannot be extracted yet (paid/region/platform restricted, or the extraction toolchain needs an update)';

  @override
  String get engineNotInit => 'Extract engine not initialized (Android)';

  @override
  String get linkParseTimeout =>
      'Failed to parse: network timeout — check the network and retry (or the link is dead)';

  @override
  String get linkParseUnrecognized =>
      'Failed to parse: unrecognized link format — make sure it is a Bilibili video/collection link';

  @override
  String engineErrorAndroid(String detail) {
    return 'Extract engine error (Android): $detail';
  }

  @override
  String get searchQueryEmpty => 'Search query is empty';

  @override
  String get douyinUnsupported =>
      'Douyin search requires a signed-in platform session; paste a share link to extract instead';

  @override
  String get riskControlIntercepted =>
      'Blocked by platform risk control — try again later or sign in to Bilibili';

  @override
  String searchApiFailed(String code, String reason) {
    return 'Bilibili search failed ($code): $reason';
  }

  @override
  String get unknownReason => 'unknown reason';

  @override
  String get responseNotJson => 'Response is not a JSON object';

  @override
  String qrCreateFailed(String code) {
    return 'Failed to fetch login QR code ($code)';
  }

  @override
  String get qrDataIncomplete => 'Login QR data incomplete';

  @override
  String pollFailed(String code) {
    return 'Login status check failed ($code)';
  }

  @override
  String get dbRecoveryHint =>
      'Database failed to open: read-only protection is on; your data is safe. Use the repair guide in Settings.';

  @override
  String get eqBandsNote => '5 bands · ±12dB · applies live while dragging';

  @override
  String get eqPresetDefault => 'Default';

  @override
  String get eqPresetPop => 'Pop';

  @override
  String get eqPresetRock => 'Rock';

  @override
  String get eqPresetClassical => 'Classical';

  @override
  String get eqPresetJazz => 'Jazz';

  @override
  String get eqPresetBass => 'Bass Boost';

  @override
  String get eqPresetCustom => 'Custom';

  @override
  String eqBandLabel(String hz) {
    return '$hz Hz';
  }

  @override
  String get menuPlayNext => 'Play next';

  @override
  String get menuAddToPlaylist => 'Add to playlist';

  @override
  String get menuEditTitle => 'Edit title';

  @override
  String get menuRemoveTrack => 'Remove from library';

  @override
  String get editTitleLabel => 'Track title';

  @override
  String get save => 'Save';

  @override
  String removeTrackConfirm(String title) {
    return 'Remove \"$title\" from the library? The audio file will not be deleted.';
  }

  @override
  String addedToPlaylist(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String alreadyInPlaylist(String title, String name) {
    return '\"$title\" is already in \"$name\"';
  }

  @override
  String get playlistNewName => 'Playlist name';

  @override
  String get playlistRename => 'Rename playlist';

  @override
  String get playlistDelete => 'Delete playlist';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Delete playlist \"$name\"? Tracks stay in the library.';
  }

  @override
  String get queueClear => 'Clear queue';

  @override
  String get queueClearConfirm => 'Clear the current play queue?';

  @override
  String get queueRemoveTooltip => 'Remove from queue';

  @override
  String get historyTitle => 'Play history';

  @override
  String get historyClear => 'Clear history';

  @override
  String get historyClearConfirm => 'Clear all play history?';

  @override
  String get historyEmpty => 'No play history yet';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get cardFavorites => 'Favorites';

  @override
  String get cardHistory => 'History';

  @override
  String get cardLocal => 'Local';

  @override
  String get repoRemoveTooltip => 'Remove repository';

  @override
  String repoRemoveConfirm(String name) {
    return 'Remove repository \"$name\"? Library records are removed; audio files are kept.';
  }

  @override
  String get fewWatchClear => 'Clear dislike list';

  @override
  String get fewWatchCleared => 'Dislike list cleared';

  @override
  String get playbackSection => 'Playback';

  @override
  String get repoRemoved => 'Repository removed';

  @override
  String get trackRemoved => 'Removed from library';

  @override
  String get renamed => 'Renamed';

  @override
  String get playlistDeleted => 'Playlist deleted';

  @override
  String get historyCleared => 'Play history cleared';

  @override
  String get qualityLabel => 'Quality';

  @override
  String get quality64 => '64k';

  @override
  String get quality128 => '128k';

  @override
  String get quality192 => '192k';

  @override
  String get qualityHires => 'Hi-Res';

  @override
  String get qualityHint => 'Log in to Bilibili for higher bitrates';

  @override
  String get statusDownloading => 'Downloading';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusTranscoding => 'Transcoding';

  @override
  String get statusRegistered => 'Imported';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusDup => 'Duplicate';

  @override
  String get taskPause => 'Pause';

  @override
  String get taskRetry => 'Retry';

  @override
  String get taskSkipDup => 'Skip';

  @override
  String get extractNotification => 'Extraction in progress';

  @override
  String get lyricsOffset => 'Lyrics offset';

  @override
  String lyricsOffsetValue(String s) {
    return 'Offset ${s}s';
  }

  @override
  String get lyricsOffsetWriteBack => 'Write to .lrc file';

  @override
  String get lyricsOffsetSaved => 'Offset saved';

  @override
  String get lyricsOffsetReset => 'Reset';

  @override
  String get lyricsPaste => 'Paste lyrics';

  @override
  String get lyricsPasteHint => 'Paste lyrics (LRC supported)';

  @override
  String get lyricsPasteSaved => 'Lyrics saved';

  @override
  String get lyricsGen => 'Generate lyrics (on-device AI)';

  @override
  String get lyricsGenStarted => 'Lyrics generation started';

  @override
  String get lyricsGenNoModel => 'Download the lyrics model in Settings first';

  @override
  String get lyricsPreviewTitle => 'Preview lyrics';

  @override
  String get lyricsPreviewSave => 'Save lyrics';

  @override
  String get lyricsPreviewSaved => 'Lyrics saved';

  @override
  String get lyricsFontSize => 'Lyrics font size';

  @override
  String get modelManagerTitle => 'Lyrics model';

  @override
  String get modelStatusAbsent => 'Not downloaded';

  @override
  String get modelStatusPresent => 'Ready';

  @override
  String get modelDownload => 'Download model';

  @override
  String get modelDelete => 'Delete model';

  @override
  String get modelDeleteConfirm =>
      'Delete the downloaded model? Lyric generation returns to not-ready.';

  @override
  String get modelDeleted => 'Model deleted';

  @override
  String modelDownloading(int pct) {
    return 'Downloading $pct%';
  }

  @override
  String modelSizeLabel(int mb) {
    return 'Size: $mb MB';
  }

  @override
  String get modelDownloadDone => 'Model ready';

  @override
  String get modelDownloadFailed => 'Download failed: check network and retry';

  @override
  String get tracksSelect => 'Select';

  @override
  String tracksSelected(int n) {
    return '$n selected';
  }

  @override
  String get batchLyricsTitle => 'Batch generate lyrics';

  @override
  String batchLyricsRunning(int done, int total) {
    return 'Generating $done/$total';
  }

  @override
  String batchLyricsDone(int ok, int skip, int fail) {
    return 'Batch done: $ok ok · $skip skipped · $fail failed';
  }

  @override
  String get lyricsSection => 'Lyrics';

  @override
  String get fontSizeS => 'Small';

  @override
  String get fontSizeM => 'Standard';

  @override
  String get fontSizeL => 'Large';
}
