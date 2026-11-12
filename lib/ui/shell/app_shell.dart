/// 响应式壳层：宽屏侧栏 + 迷你条 / 移动底 Tab + 悬浮胶囊。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../state/playback_controller.dart';
import '../library/library_section.dart';
import '../play/mini_player.dart';
import '../play/now_playing_page.dart';
import '../playlists/playlists_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';

enum ShellSection { library, search, playlists, settings }

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  ShellSection _section = ShellSection.library;

  static const _desktopBreakpoint = 720.0;

  @override
  void initState() {
    super.initState();
    // 播放异常横幅（缺失/损坏跳过）
    ref.listenManual(playbackNoticeProvider, (prev, next) {
      final msg = next.value;
      if (msg != null && msg.isNotEmpty && mounted) {
        final s = S.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${s.trackMissing}: $msg'),
          duration: const Duration(seconds: 3),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= _desktopBreakpoint;
    final body = IndexedStack(
      index: _section.index,
      children: const [
        LibrarySection(),
        SearchPage(),
        PlaylistsPage(),
        SettingsPage(),
      ],
    );

    if (desktop) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              section: _section,
              onSelect: (s) => setState(() => _section = s),
            ),
            VerticalDivider(width: 1, color: context.ia.separator),
            Expanded(child: body),
          ],
        ),
        bottomNavigationBar: const MiniPlayer(capsule: false),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          body,
          Positioned(
            left: IaSpacing.l,
            right: IaSpacing.l,
            bottom: 84,
            child: const MiniPlayer(capsule: true),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section.index,
        onDestinationSelected: (i) =>
            setState(() => _section = ShellSection.values[i]),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.library_music_outlined),
              selectedIcon: const Icon(Icons.library_music),
              label: S.of(context).navLibrary),
          NavigationDestination(
              icon: const Icon(Icons.search),
              selectedIcon: const Icon(Icons.search),
              label: S.of(context).navSearch),
          NavigationDestination(
              icon: const Icon(Icons.queue_music_outlined),
              selectedIcon: const Icon(Icons.queue_music),
              label: S.of(context).navPlaylists),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: S.of(context).navSettings),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.section, required this.onSelect});

  final ShellSection section;
  final ValueChanged<ShellSection> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ia;
    final s = S.of(context);
    Widget item(ShellSection sec, IconData icon, IconData iconActive, String label) {
      final active = section == sec;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: IaSpacing.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(IaSpacing.radiusM),
          onTap: () => onSelect(sec),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: IaSpacing.m, vertical: IaSpacing.m + 2),
            decoration: BoxDecoration(
              color: active ? p.lifted : Colors.transparent,
              borderRadius: BorderRadius.circular(IaSpacing.radiusM),
            ),
            child: Row(
              children: [
                Icon(active ? iconActive : icon, size: 20,
                    color: active ? p.accent : p.secondaryText),
                const SizedBox(width: IaSpacing.m),
                Text(label,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? p.mainText : p.secondaryText)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 216,
      color: p.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: IaSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: IaSpacing.l),
            child: Row(
              children: [
                Icon(Icons.graphic_eq, color: p.accent, size: 26),
                const SizedBox(width: IaSpacing.s),
                Text('iA Music',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: p.mainText)),
              ],
            ),
          ),
          const SizedBox(height: IaSpacing.xl),
          item(ShellSection.library, Icons.library_music_outlined,
              Icons.library_music, s.navLibrary),
          item(ShellSection.search, Icons.search, Icons.search, s.navSearch),
          item(ShellSection.playlists, Icons.queue_music_outlined,
              Icons.queue_music, s.navPlaylists),
          item(ShellSection.settings, Icons.settings_outlined, Icons.settings,
              s.navSettings),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(IaSpacing.s),
            child: Text('v2.0.0',
                style: TextStyle(fontSize: 11, color: p.secondaryText)),
          ),
        ],
      ),
    );
  }
}

/// 打开沉浸播放页的统一入口。
Future<void> openNowPlaying(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const NowPlayingPage(),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      ),
      opaque: false,
      barrierColor: Colors.black54,
    ),
  );
}
