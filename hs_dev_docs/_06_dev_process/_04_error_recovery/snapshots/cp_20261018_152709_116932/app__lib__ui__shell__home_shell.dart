/// 主壳骨架（S4 · REQ-NAV-01）：三 Tab + 迷你播放条常驻。
///
/// * 播放域实例**唯一**于壳层（跨 Tab 一致：切 Tab 不掉队列/不停播）。
/// * IndexedStack 保活各 Tab 状态（切换无数据丢失）——NAV-01 锚。
/// * 迷你条/服务提示横幅在 Tab 内容之外（任何 Tab 均可见/一致）。
///
/// 数据门面=`LibraryHub`（组合根）；播放域生命周期归本壳（S9/S10 终装配）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/adapters/mpv_engine_adapter.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/library/library_list_page.dart';
import 'package:ia_music/ui/mine/mine_page.dart';
import 'package:ia_music/ui/play/play_page.dart';
import 'package:ia_music/ui/play/playback_dock.dart';
import 'package:ia_music/ui/playlists/playlist_list_page.dart';

final class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.hub});

  final LibraryHub hub;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// 壳层唯一播放域实例（REQ-NAV-01 跨 Tab 一致）。
  PlaybackService? _playback;

  PlaybackService? get playbackOrNull => _playback;

  /// 保活/取用播放域（首次触达即初始化；表内真实引擎）。
  Future<PlaybackService> ensurePlayback() async {
    var svc = _playback;
    if (svc == null || !svc.isReady) {
      svc = PlaybackService(MpvEngineAdapter(), widget.hub.data);
      await svc.init();
      if (mounted) {
        setState(() => _playback = svc);
      }
    }
    return svc;
  }

  /// 行点击/歌单「播放全部」起播（REQ-PLAY-01/PL-06 入口；测试经同一缝驱动）。
  Future<PlaybackService> playTrackIds(List<int> ids, {int startIndex = 0}) async {
    final svc = await ensurePlayback();
    await svc.playTrackIds(ids, startIndex: startIndex);
    return svc;
  }

  /// 随机一触即听（REQ-NAV-02 入口；随机卡进随机模式）。
  Future<PlaybackService> startShuffle({int poolSize = 100}) async {
    final svc = await ensurePlayback();
    await svc.startRandom(poolSize: poolSize);
    return svc;
  }

  Future<void> dislikeNow() async => _playback?.dislikeThenNext();
  Future<void> nextNow() async => _playback?.next();

  /// 进沉浸播放页（REQ-PLAY-01：点击播放进入沉浸页）。
  Future<void> openPlayPage() async {
    final svc = _playback;
    if (svc == null) {
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlayPage(service: svc, data: widget.hub.data),
    ));
  }

  @override
  void dispose() {
    unawaited(_playback?.dispose()); // §4.3：句柄/bridges/通知全净释放
    _playback = null;
    super.dispose();
  }

  void _bumpPages() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final svc = _playback;
    final pages = [
      LibraryListPage(
        hub: widget.hub,
        ensurePlayback: ensurePlayback,
        onPlayRequested: () => unawaited(openPlayPage()),
      ),
      PlaylistListPage(
        data: widget.hub.data,
        ensurePlayback: ensurePlayback,
        onChanged: _bumpPages,
      ),
      MinePage(
        data: widget.hub.data,
        ensurePlayback: ensurePlayback,
        onChanged: _bumpPages,
      ),
    ];
    return Scaffold(
      key: const ValueKey('home_shell'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (svc != null) PlaybackNoticeBar(service: svc),
          Expanded(
            child: IndexedStack(index: _tab, children: pages),
          ),
          if (svc != null)
            PlaybackStrip(
              service: svc,
              onOpen: () => unawaited(openPlayPage()),
              onDislike: dislikeNow,
              onNext: nextNow,
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('main_tabs'),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music),
              label: '音乐空间'),
          NavigationDestination(
              icon: Icon(Icons.queue_music_outlined),
              selectedIcon: Icon(Icons.queue_music),
              label: '歌单'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的'),
        ],
      ),
    );
  }
}
