/// 主壳（DEC-012 D12-3 资料库中心 · Harmonoid 形态，从零重写）。
///
/// * 桌面（≥1024）：240px 侧栏（SEARCH / LIBRARY 子树 TRACKS·ALBUMS·ARTISTS /
///   PLAYLISTS / SETTINGS + **侧栏底部常驻迷你播放器**）+ 内容区。
/// * 移动：底部 4 Tab（曲库/搜索/歌单/设置）+ **悬浮胶囊迷你条**；
///   曲库 Tab 内部 TRACKS/ALBUMS/ARTISTS 分段。
/// * 播放域唯一于壳层；就绪即绑 AccentController（D12-6）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/adapters/mpv_engine_adapter.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/library/albums_page.dart';
import 'package:ia_music/ui/library/artists_page.dart';
import 'package:ia_music/ui/library/tracks_page.dart';
import 'package:ia_music/ui/play/mini_player.dart';
import 'package:ia_music/ui/play/now_playing_page.dart';
import 'package:ia_music/ui/play/playback_notice.dart';
import 'package:ia_music/ui/play/queue_page.dart';
import 'package:ia_music/ui/play/shuffle_page.dart';
import 'package:ia_music/ui/playlists/playlists_page.dart';
import 'package:ia_music/ui/search/search_page.dart';
import 'package:ia_music/ui/settings/settings_page.dart';
import 'package:ia_music/ui/shell/appearance.dart';
import 'package:ia_music/ui/shell/locale_controller.dart';
import 'package:ia_music/ui/theme/accent_controller.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// 壳层目的地（侧栏子树 = tracks/albums/artists；search/playlists/settings 平级）。
enum ShellSection { tracks, albums, artists, playlists, search, settings }

final class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.hub,
    required this.appearance,
    required this.locale,
    this.accent,
  });

  final LibraryHub hub;
  final AppearanceController appearance;

  /// 语言三选（DEC-005 D5-2）。
  final LocaleController locale;
  final AccentController? accent;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  ShellSection _section = ShellSection.tracks; // 资料库中心：TRACKS 是首页

  PlaybackService? _playback;
  PlaybackService? get playbackOrNull => _playback;

  @override
  void initState() {
    super.initState();
    // WS7/REQ-PLAY 恢复闭环：冷启动恢复上次会话（有快照才恢复；自动起播=
    // 电台连续性裁决 IMPL-S3 §4）。best-effort：无快照/恢复失败不阻塞首帧。
    unawaited(() async {
      try {
        final svc = await ensurePlayback();
        await svc.restoreFromDisk();
      } on Object {
        // 会话损坏/引擎失败——空态起步（壳层空态面已覆盖）
      }
    }());
  }

  Future<PlaybackService> ensurePlayback() async {
    var svc = _playback;
    if (svc == null || !svc.isReady) {
      svc = PlaybackService(MpvEngineAdapter(), widget.hub.data);
      await svc.init();
      if (mounted) setState(() => _playback = svc);
    }
    widget.accent?.bind(svc);
    return svc;
  }

  Future<PlaybackService> playTrackIds(
    List<int> ids, {
    int startIndex = 0,
  }) async {
    final svc = await ensurePlayback();
    await svc.playTrackIds(ids, startIndex: startIndex);
    return svc;
  }

  /// 随机一触即听（曲库工具栏随机键入口）。
  Future<PlaybackService> startShuffle({int poolSize = 100}) async {
    final svc = await ensurePlayback();
    await svc.startRandom(poolSize: poolSize);
    return svc;
  }

  Future<void> dislikeNow() async => _playback?.dislikeThenNext();
  Future<void> nextNow() async => _playback?.next();

  Future<void> openNowPlaying() async {
    final svc = _playback;
    if (svc == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NowPlayingPage(
        service: svc,
        data: widget.hub.data,
        covers: widget.hub.covers,
        hub: widget.hub,
      ),
    ));
  }

  Future<void> openQueue() async {
    final svc = _playback;
    if (svc == null) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => QueuePage(service: svc)));
  }

  Future<void> openShuffle() async {
    final svc = _playback;
    if (svc == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ShufflePage(
        service: svc,
        data: widget.hub.data,
        covers: widget.hub.covers,
      ),
    ));
  }

  /// 跳转缝（测试/空态引导：0 tracks/1 albums/2 artists/3 playlists/4 search/5 settings）。
  void jumpTo(ShellSection section) => setState(() => _section = section);

  @override
  void dispose() {
    widget.accent?.unbind();
    unawaited(_playback?.dispose());
    _playback = null;
    super.dispose();
  }

  void _bump() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final svc = _playback;
    final pages = IndexedStack(
      key: const ValueKey('shell_stack'),
      index: _section.index,
      children: [
        TracksPage(
          hub: widget.hub,
          ensurePlayback: ensurePlayback,
          playTracks: playTrackIds,
          onPlayRequested: () => unawaited(openNowPlaying()),
          onShuffleRequested: () => unawaited(startShuffle().then((_) {
                if (mounted) unawaited(openShuffle());
              })),
          onSection: (i) => jumpTo(switch (i) {
                0 => ShellSection.tracks,
                1 => ShellSection.albums,
                _ => ShellSection.artists,
              }),
          onNavigate: (i) => jumpTo(ShellSection.values[i]),
        ),
        AlbumsPage(
          hub: widget.hub,
          playTracks: playTrackIds,
          onPlayRequested: () => unawaited(openNowPlaying()),
        ),
        ArtistsPage(
          hub: widget.hub,
          playTracks: playTrackIds,
          onPlayRequested: () => unawaited(openNowPlaying()),
        ),
        PlaylistsPage(
          data: widget.hub.data,
          ensurePlayback: ensurePlayback,
          onChanged: _bump,
          onGoLibrary: () => jumpTo(ShellSection.tracks), // 本地卡→曲库 Tab
        ),
        SearchPage(
          hub: widget.hub,
          ensurePlayback: ensurePlayback,
          accent: widget.accent,
        ),
        SettingsPage(
          hub: widget.hub,
          appearance: widget.appearance,
          locale: widget.locale,
          onChanged: _bump,
        ),
      ],
    );

    return LayoutBuilder(builder: (context, cons) {
      // V1 视觉审查修复：桌面形态阈值 1024→720。此前的 1024 让半屏桌面窗口
      // （如 800/960px）整个切到移动底部 Tab——「桌面出现手机 UI」的根因。
      // 720 以下才降级移动形态；侧栏在窄桌面自适应缩窄（240→200）。
      final desktop = cons.maxWidth >= 720;
      final sidebarWidth = cons.maxWidth >= 1024 ? 240.0 : 200.0;
      if (desktop) {
        return Scaffold(
          key: const ValueKey('app_shell'),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(
                section: _section,
                width: sidebarWidth,
                onSelect: (s) => setState(() => _section = s),
                miniPlayer: svc == null
                    ? const SizedBox.shrink()
                    : SidebarMiniPlayer(
                        key: const ValueKey('shell_mini'),
                        service: svc,
                        data: widget.hub.data,
                        covers: widget.hub.covers,
                        onOpen: () => unawaited(openNowPlaying()),
                        onNext: nextNow,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (svc != null)
                      PlaybackNoticeBar(
                          key: const ValueKey('shell_notice'), service: svc),
                    Expanded(
                      key: const ValueKey('shell_content'),
                      child: pages,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      // 移动端：内容 + 悬浮胶囊迷你条 + 4 Tab 底栏。
      // SafeArea(top)：Android 15 强制 edge-to-edge——无 AppBar 的页面
      // （TRACKS/搜索/设置等）否则顶进状态栏底下；底部由 Tab 栏自管。
      return Scaffold(
        key: const ValueKey('app_shell'),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (svc != null)
                    PlaybackNoticeBar(
                        key: const ValueKey('shell_notice'), service: svc),
                  Expanded(
                    key: const ValueKey('shell_content'),
                    child: pages,
                  ),
                  if (svc != null)
                    CapsuleMiniPlayer(
                      key: const ValueKey('shell_mini'),
                      service: svc,
                      data: widget.hub.data,
                      covers: widget.hub.covers,
                      onOpen: () => unawaited(openNowPlaying()),
                      onNext: nextNow,
                    ),
                  ],
                ),
              ],
            ),
          ),
        bottomNavigationBar: _MobileTabs(
          section: _section,
          onSelect: (s) => setState(() => _section = s),
        ),
      );
    });
  }
}

/// 桌面侧栏（SEARCH / LIBRARY 子树 / PLAYLISTS / SETTINGS + 底部迷你播放器）。
final class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.onSelect,
    required this.miniPlayer,
    this.width = 240,
  });

  final ShellSection section;
  final ValueChanged<ShellSection> onSelect;
  final Widget miniPlayer;

  /// 窄桌面自适应缩窄（V1：720-1023px 窗口用 200px）。
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    final scheme = Theme.of(context).colorScheme;
    Widget item(
      ShellSection s,
      IconData icon,
      String label,
      String keyName, {
      bool indent = false,
    }) {
      final selected = section == s;
      return Padding(
        padding: EdgeInsets.only(
          left: indent ? 40 : 12,
          right: 12,
          top: 2,
          bottom: 2,
        ),
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(IaRadius.card),
          child: InkWell(
            key: ValueKey(keyName),
            borderRadius: BorderRadius.circular(IaRadius.card),
            onTap: () => onSelect(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 21,
                    fill: selected ? 1.0 : 0.0,
                    color: selected ? p.mainText : p.secondaryText,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.02,
                      color: selected ? p.mainText : p.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.14,
              color: p.secondaryText,
            ),
          ),
        );

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(IaIcon.play, size: 18, color: p.onAccent),
                  ),
                  const SizedBox(width: 10),
                  // V1：窄侧栏（200px）品牌名可截断，避免 Row 溢出。
                  const Expanded(
                    child: Text(
                      'iA Music',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            item(ShellSection.search, IaIcon.search, t.navSearch, 'nav_search'),
            header(t.navLibrary),
            item(ShellSection.tracks, IaIcon.tracks, t.navTracks, 'nav_tracks'),
            item(ShellSection.albums, IaIcon.albums, t.navAlbums, 'nav_albums',
                indent: true),
            item(ShellSection.artists, IaIcon.artists, t.navArtists,
                'nav_artists', indent: true),
            header(t.navMore),
            item(ShellSection.playlists, IaIcon.playlist, t.navPlaylists,
                'nav_playlists'),
            item(ShellSection.settings, IaIcon.settings, t.navSettings,
                'nav_settings'),
            const Spacer(),
            miniPlayer,
          ],
        ),
      ),
    );
  }
}

/// 移动端 4 Tab（曲库/搜索/歌单/设置；曲库含 albums/artists 分段子面）。
final class _MobileTabs extends StatelessWidget {
  const _MobileTabs({required this.section, required this.onSelect});

  final ShellSection section;
  final ValueChanged<ShellSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    final scheme = Theme.of(context).colorScheme;
    Widget item(
      ShellSection s,
      IconData icon,
      String label,
      String keyName, {
      ShellSection? highlight,
    }) {
      final selected = section == (highlight ?? s);
      return Expanded(
        child: Semantics(
          label: label,
          button: true,
          selected: selected,
          child: InkWell(
            key: ValueKey(keyName),
            onTap: () => onSelect(s),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected ? scheme.secondaryContainer : null,
                      borderRadius: BorderRadius.circular(IaRadius.pill),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      fill: selected ? 1.0 : 0.0,
                      color: selected ? p.mainText : p.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? p.mainText : p.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('main_tabs'),
      decoration: BoxDecoration(
        color: p.canvas,
        border: Border(top: BorderSide(color: p.separator)),
      ),
      height: 66 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          // 曲库 Tab 覆盖 tracks/albums/artists 三个子面（高亮合一）。
          item(ShellSection.tracks, IaIcon.library, t.navLibrary,
              'nav_library', highlight: ShellSection.tracks),
          item(ShellSection.search, IaIcon.search, t.navSearch, 'nav_search'),
          item(ShellSection.playlists, IaIcon.playlist, t.navPlaylists,
              'nav_playlists'),
          item(ShellSection.settings, IaIcon.settings, t.navSettings,
              'nav_settings'),
        ],
      ),
    );
  }
}
