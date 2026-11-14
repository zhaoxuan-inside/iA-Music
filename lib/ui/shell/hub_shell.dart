/// Hub 全景壳：水平 PageView 七屏（负一屏听法 ← 屏1 在播 → … → 设置）+
/// 右缘 peek + 迷你条吸底 + NP 展开。
///
/// 曲面屏适配：每屏内容经 SafeArea + edgeInsets（左右曲面安全区取大者）；
/// 迷你条/字母轨按安全区偏移。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/playback_controller.dart';
import '../added/added_page.dart';
import '../library/songs_page.dart';
import '../listen/listen_page.dart';
import '../music/music_menu.dart';
import '../play/mini_player.dart';
import '../play/now_playing.dart';
import '../playlists/playlists_page.dart';
import '../played/played_page.dart';
import '../playing/playing_page.dart';
import '../settings/settings_page.dart';
import '../shared/ui_kit.dart';

/// Hub 七屏。
enum HubScreen {
  listen, // 负一屏 听法
  playing, // 屏1 正在播放
  songs, // 屏2 曲库（歌曲列表）
  added, // 屏3 最近添加
  played, // 屏4 常听与历史
  playlists, // 屏5 歌单
  settings, // 屏末 设置
}

class HubShell extends ConsumerStatefulWidget {
  const HubShell({super.key});

  @override
  ConsumerState<HubShell> createState() => _HubShellState();
}

class _HubShellState extends ConsumerState<HubShell> {
  late final PageController _pc =
      PageController(initialPage: HubScreen.playing.index, viewportFraction: 0.86);
  int _page = HubScreen.playing.index;

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
          PageView(
            controller: _pc,
            onPageChanged: (i) => setState(() => _page = i),
            children: const [
              ListenPage(),
              PlayingPage(),
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

  void _openNowPlaying() {
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => const NowPlayingPage(),
      transitionsBuilder: (_, anim, _, child) {
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    ));
  }
}
