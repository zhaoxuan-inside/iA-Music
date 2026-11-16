/// Hub 全景壳：水平 PageView 七屏（负一屏听法 ← 屏1 在播 → … → 设置）+
/// 右缘 peek + 迷你条吸底 + NP 展开。
///
/// 曲面屏适配：每屏内容经 SafeArea + edgeInsets（左右曲面安全区取大者）；
/// 迷你条/字母轨按安全区偏移。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../added/added_page.dart';
import '../library/songs_page.dart';
import '../listen/listen_page.dart';
import '../play/mini_player.dart';
import '../play/now_playing.dart';
import '../played/played_page.dart';
import '../playing/playing_page.dart';
import '../playlists/playlists_page.dart';
import '../quickplay/quickplay_page.dart';
import '../settings/settings_page.dart';
import 'hub_backdrop.dart';
import 'panorama_backdrop.dart';

/// Hub 八屏。
enum HubScreen {
  listen, // 负一屏 听法
  playing, // 屏1 正在播放
  quickplay, // 屏2 快速播放（Zune Quickplay）
  songs, // 屏3 曲库（歌曲列表）
  added, // 屏4 最近添加
  played, // 屏5 常听与历史
  playlists, // 屏6 歌单
  settings, // 屏末 设置
}

class HubShell extends ConsumerStatefulWidget {
  const HubShell({super.key});

  @override
  ConsumerState<HubShell> createState() => _HubShellState();
}

class _HubShellState extends ConsumerState<HubShell> {
  late final PageController _pc = PageController(
      initialPage: HubScreen.quickplay.index, viewportFraction: 0.86);

  /// 背景巨字与 HubScreen 一一对应。
  static const _titles = [
    '听法',
    '音乐',
    '快速播放',
    '曲库',
    '最近添加',
    '常听',
    '歌单',
    '设置',
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: Stack(
        children: [
          // 封面色雾：整个 Hub 的环境底色。
          const Positioned.fill(child: HubBackdrop()),
          Positioned.fill(
            child: PanoramaBackdrop(controller: _pc, titles: _titles),
          ),
          PageView(
            controller: _pc,
            children: const [
              ListenPage(),
              PlayingPage(),
              QuickplayPage(),
              SongsPage(),
              AddedPage(),
              PlayedPage(),
              PlaylistsPage(),
              SettingsPage(),
            ],
          ),
          // 迷你条（有当前曲目才出现；曲面屏安全区已含在内）
          MiniPlayer(onOpen: _openNowPlaying),
        ],
      ),
    );
  }

  void _openNowPlaying() => openNowPlaying(context);
}

