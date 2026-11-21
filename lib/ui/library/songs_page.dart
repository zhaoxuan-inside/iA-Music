/// 曲库屏（Hub 屏2）：全部歌曲按歌名字母排序，右缘字母导航轨。
///
/// 页头固定（不随内容滚动、高度恒定）；字母轨为 Win11 跳转栏逻辑：
/// 列表槽位定高（[itemExtent]），字母 → 组头槽位号 × 槽高 = 精确偏移，
/// 跳转零估算零动画——按下即达，拖动实时刷屏；大字母走 ValueNotifier，
/// 拖动全程不重建列表。缺失/已删除曲目诚实灰显。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/letter.dart';
import '../../state/library_providers.dart';
import '../../state/playback_controller.dart';
import '../music/music_menu.dart';
import '../settings/subpages.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';
import '../shared/wp_motion.dart';

/// 列表槽位定高（封面 48 + 上下 12 边距；组头 / 音乐页入口同槽）。
const double _slotH = 72;

/// 展平槽位：字母组头 / 歌曲行。
sealed class _Slot {
  const _Slot();
}

class _Header extends _Slot {
  const _Header(this.letter);
  final String letter;
}

class _Song extends _Slot {
  const _Song(this.track);
  final Track track;
}

/// 曲库列表尾部的「音乐页」入口。
class _MusicPageEntry extends _Slot {
  const _MusicPageEntry();
}

class SongsPage extends ConsumerStatefulWidget {
  const SongsPage({super.key});

  @override
  ConsumerState<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends ConsumerState<SongsPage> {
  final _scrollCtrl = ScrollController();
  final _bigLetter = ValueNotifier<String?>(null);

  /// 字母 → 组头槽位号（build 时随分组刷新；槽位定高故偏移可精确算出）。
  Map<String, int> _headerSlots = const {};

  /// 拖动刷屏：按下即跳（Win11 跳转栏无缓动等待）。
  void _jumpTo(String letter) {
    final idx = _headerSlots[letter];
    if (idx == null || !_scrollCtrl.hasClients) {
      return;
    }
    final offset = (IaSpacing.xl + idx * _slotH)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.jumpTo(offset);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _bigLetter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final tracks =
        ref.watch(tracksProvider(TrackSort.title)).value ?? const <Track>[];
    final playingId = ref.watch(playbackProvider.select((s) => s.current?.id));
    final favs = ref.watch(favoritesSetProvider).value ?? const <int>{};
    final edge = edgeInsets(context);

    // 显示序在 Dart 侧自排：SQL 按 titleNorm 码点序（中文≠拼音序），
    // 直接用会让同组歌曲散落、组头只在首现处出现。按（拼音首字母，歌名）
    // 排序后一遍建槽，组才真正连续、字母轨才能跳到整组。点播不依赖任何
    // 定位——只交出被点的曲目，按 id 对位收口在 [PlaybackService.playTrack]。
    final display = [
      for (final t in tracks) (t, letterKey(t.title)),
    ]..sort((a, b) {
      final c = a.$2.compareTo(b.$2);
      return c != 0 ? c : a.$1.title.toLowerCase().compareTo(b.$1.title.toLowerCase());
    });
    final headerSlots = <String, int>{};
    final letters = <String>[];
    final slots = <_Slot>[];
    for (final (t, key) in display) {
      if (!headerSlots.containsKey(key)) {
        headerSlots[key] = slots.length;
        letters.add(key);
        slots.add(_Header(key));
      }
      slots.add(_Song(t));
    }
    slots.add(const _MusicPageEntry());
    _headerSlots = headerSlots;

    final header = PageHeader(
      kicker: '音乐仓库',
      title: '曲库',
      subtitle: '${tracks.length} 首 · 按歌名字母排序',
      trailing: const SearchAction(),
    );

    if (tracks.isEmpty) {
      // 真实空态：未配置目录/未扫描时给出可见出路，不再是一片黑
      return HubPage(
        header: header,
        children: [
          const SizedBox(height: IaSpacing.xl),
          const EmptyState(title: '曲库还是空的', subtitle: '先在「设置 · 存储」添加音乐目录并扫描'),
          const SizedBox(height: IaSpacing.l),
          OutlinedButton(
            onPressed: () => Navigator.of(context)
                .push(zuneRoute<void>(builder: (_) => const StorageSubPage())),
            child: const Text(
              '去添加音乐目录',
              style: TextStyle(fontSize: 13, color: IaColors.textHi),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            edge.left,
            topInset(context) + IaSpacing.l,
            edge.right,
            0,
          ),
          child: header,
        ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _scrollCtrl,
                itemExtent: _slotH,
                padding: EdgeInsets.fromLTRB(
                  edge.left,
                  IaSpacing.xl,
                  edge.right,
                  140,
                ),
                itemCount: slots.length,
                itemBuilder: (context, i) {
                  final slot = slots[i];
                  final child = switch (slot) {
                    _Header(:final letter) => Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: IaSpacing.s),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: IaType.semibold,
                            letterSpacing: 1.2,
                            color: p.accent,
                          ),
                        ),
                      ),
                    ),
                    _Song(:final track) => SongRow(
                      track: track,
                      leading: CoverArt(
                        track: track,
                        size: IaSpacing.coverSmall,
                      ),
                      isPlaying: playingId == track.id,
                      isLiked: favs.contains(track.id),
                      missing: track.missing,
                      onTap: () => ref
                          .read(playbackProvider.notifier)
                          .playTrack(track, queue: tracks),
                      onLongPress: () => showTrackMenu(context, ref, track),
                    ),
                    _MusicPageEntry() => BigRow(
                      title: '音乐页 · 全部艺人 / 专辑 / 歌单',
                      onTap: () => Navigator.of(context).push(
                        zuneRoute<void>(
                          builder: (_) => const MusicMenuPage(),
                        ),
                      ),
                    ),
                  };
                  // 进页一瞬的 Turnstile Feather；长列表滚动出的条目不重播。
                  return FeatherIn(index: i, child: child);
                },
              ),
              Positioned(
                right: edge.right > IaSpacing.gutter ? 4 : 2,
                // 固定页头（topInset + l + PageHeader.height）之下起轨
                top: topInset(context) + IaSpacing.l + PageHeader.height + 8,
                bottom: 150,
                width: 22,
                child: LetterRail(
                  letters: letters,
                  onPick: (l) {
                    _bigLetter.value = l;
                    _jumpTo(l);
                  },
                  onEnd: () => _bigLetter.value = null,
                ),
              ),
              // 中央大字母：ValueListenable 直连轨道，拖动全程零整页重建。
              ValueListenableBuilder<String?>(
                valueListenable: _bigLetter,
                builder: (_, letter, _) => letter == null
                    ? const SizedBox.shrink()
                    : IgnorePointer(
                        child: Center(
                          child: Text(
                            letter,
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: IaType.light,
                              color: p.accent,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
