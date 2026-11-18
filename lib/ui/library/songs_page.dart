/// 曲库屏（Hub 屏2）：全部歌曲按歌名字母排序，右缘字母导航轨。
///
/// 页头固定（不随内容滚动、高度恒定）；字母轨为 Win11 跳转栏逻辑：
/// 按下即跳 + 拖动实时刷屏 + 每越一个字母振动（LetterRail 内置）。
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

/// 展平槽位：字母组头 / 歌曲行。
sealed class _Slot {
  const _Slot();
}

class _Header extends _Slot {
  const _Header(this.letter);
  final String letter;
}

class _Song extends _Slot {
  const _Song(this.track, this.flatIndex);
  final Track track;
  final int flatIndex;
}

/// 曲库列表尾部的「音乐页」入口（demo hubP5 bigrow）。
class _MusicPageEntry extends _Slot {
  const _MusicPageEntry();
}

class SongsPage extends ConsumerStatefulWidget {
  const SongsPage({super.key});

  @override
  ConsumerState<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends ConsumerState<SongsPage> {
  final _groupKeys = <String, GlobalKey>{};
  final _scrollCtrl = ScrollController();
  String? _bigLetter;

  /// 各字母组头的估算偏移（build 时随分组刷新）。
  Map<String, double> _estOffsets = const {};

  /// 估算槽高：刻意取略小于实际值——估算偏小才能保证第一次跳转落在
  /// 目标组头上方，让懒列表把它构建出来再精确校正。
  static const double _estHeaderH = 36;
  static const double _estRowH = 60;

  /// 拖动刷屏：即时跳组（Win11 跳转栏无缓动等待）。
  void _jumpTo(String letter) {
    final ctx = _groupKeys[letter]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: Duration.zero);
      return;
    }
    _jumpByEstimate(letter);
  }

  /// 目标组头尚未被懒列表构建（GlobalKey 还没有 context）：
  /// 先跳到估算落点把目标组头带进视口，下一帧 ensureVisible 精确校正；
  /// 若估算 overshoot 仍未构建，回退 600px 重试（最多两次）。
  void _jumpByEstimate(String letter, {double backtrack = 0}) {
    if (!_scrollCtrl.hasClients) {
      return;
    }
    final offset =
        ((_estOffsets[letter] ?? 0) - backtrack).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.jumpTo(offset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ctx = _groupKeys[letter]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
        );
      } else if (backtrack < 1200) {
        _jumpByEstimate(letter, backtrack: backtrack + 600);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final tracks =
        ref.watch(tracksProvider(TrackSort.title)).value ?? const <Track>[];
    final playingId = ref.watch(playbackProvider.select((s) => s.current?.id));
    final edge = edgeInsets(context);

    final groups = <String, List<Track>>{};
    for (final t in tracks) {
      groups.putIfAbsent(letterKey(t.title), () => []).add(t);
    }
    final letters = groups.keys.toList();

    // 组头估算偏移：与槽位构建同序累加（曲目顺序即展平顺序，无需 indexOf）。
    final estOffsets = <String, double>{};
    var est = IaSpacing.xl; // ListView 顶部 padding
    for (final entry in groups.entries) {
      estOffsets[entry.key] = est;
      est += _estHeaderH + entry.value.length * _estRowH;
    }
    _estOffsets = estOffsets;

    final slots = <_Slot>[];
    var flat = 0;
    for (final entry in groups.entries) {
      slots.add(_Header(entry.key));
      for (final t in entry.value) {
        slots.add(_Song(t, flat++));
      }
    }
    slots.add(const _MusicPageEntry());

    final header = PageHeader(
      kicker: '音乐仓库',
      title: '曲库',
      subtitle: '${tracks.length} 首 · 按歌名字母排序 · 分类浏览见音乐页',
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
                    _Header(:final letter) => Container(
                      key: _groupKeys.putIfAbsent(letter, GlobalKey.new),
                      padding: const EdgeInsets.only(
                        top: IaSpacing.l,
                        bottom: IaSpacing.s,
                      ),
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
                    _Song(:final track, :final flatIndex) => SongRow(
                      track: track,
                      leading: CoverArt(
                        track: track,
                        size: IaSpacing.coverSmall,
                      ),
                      isPlaying: playingId == track.id,
                      isLiked:
                          ref.watch(favoriteProvider(track.id)).value ?? false,
                      onTap: () => ref
                          .read(playbackProvider.notifier)
                          .playTracks(tracks, startIndex: flatIndex),
                      onLongPress: () => showTrackMenu(context, ref, track),
                    ),
                    _MusicPageEntry() => Padding(
                      padding: const EdgeInsets.only(top: IaSpacing.l),
                      child: BigRow(
                        title: '音乐页 · 全部艺人 / 专辑 / 歌单',
                        onTap: () => Navigator.of(context).push(
                          zuneRoute<void>(
                            builder: (_) => const MusicMenuPage(),
                          ),
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
                    setState(() => _bigLetter = l);
                    _jumpTo(l);
                  },
                  onEnd: () => setState(() => _bigLetter = null),
                ),
              ),
              if (_bigLetter != null)
                IgnorePointer(
                  child: Center(
                    child: Text(
                      _bigLetter!,
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: IaType.light,
                        color: p.accent,
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
