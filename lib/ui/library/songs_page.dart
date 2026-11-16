/// 曲库屏（Hub 屏2）：全部歌曲按歌名字母排序，右缘字母导航轨。
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
  String? _bigLetter;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final tracks = ref.watch(tracksProvider(TrackSort.title)).value ?? const <Track>[];
    final playingId = ref.watch(playbackProvider.select((s) => s.current?.id));
    final edge = edgeInsets(context);
    final pad = hubPadding(context);

    final groups = <String, List<Track>>{};
    for (final t in tracks) {
      groups.putIfAbsent(letterKey(t.title), () => []).add(t);
    }
    final letters = groups.keys.toList();

    final slots = <_Slot>[];
    for (final entry in groups.entries) {
      slots.add(_Header(entry.key));
      for (var i = 0; i < entry.value.length; i++) {
        slots.add(_Song(entry.value[i], tracks.indexOf(entry.value[i])));
      }
    }
    slots.add(const _MusicPageEntry());

    if (tracks.isEmpty) {
      // 真实空态：未配置目录/未扫描时给出可见出路，不再是一片黑
      return ListView(
        padding: hubPadding(context),
        children: [
          const SizedBox(height: IaSpacing.xl),
          const PageHeader(
            kicker: '音乐仓库',
            title: '曲库',
            subtitle: '全部歌曲按歌名字母排序',
            trailing: SearchAction(),
          ),
          const SizedBox(height: IaSpacing.xxl),
          const EmptyState(
              title: '曲库还是空的',
              subtitle: '先在「设置 · 存储」添加音乐目录并扫描'),
          const SizedBox(height: IaSpacing.l),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
                zuneRoute<void>(builder: (_) => const StorageSubPage())),
            child: const Text('去添加音乐目录',
                style: TextStyle(fontSize: 13, color: IaColors.textHi)),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: pad,
          itemCount: slots.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: IaSpacing.s),
                child: PageHeader(
                  kicker: '音乐仓库',
                  title: '曲库',
                  subtitle:
                      '${tracks.length} 首 · 按歌名字母排序 · 分类浏览见音乐页',
                  trailing: const SearchAction(),
                ),
              );
            }
            final slot = slots[i - 1];
            final child = switch (slot) {
              _Header(:final letter) => Container(
                  key: _groupKeys.putIfAbsent(letter, GlobalKey.new),
                  padding: const EdgeInsets.only(top: IaSpacing.l, bottom: IaSpacing.s),
                  child: Text(letter,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: IaType.semibold,
                          letterSpacing: 1.2,
                          color: p.accent)),
                ),
              _Song(:final track, :final flatIndex) => SongRow(
                  track: track,
                  leading:
                      CoverArt(track: track, size: IaSpacing.coverSmall),
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
                    onTap: () => Navigator.of(context).push(zuneRoute<void>(
                        builder: (_) => const MusicMenuPage())),
                  ),
                ),
            };
            return child;
          },
        ),
        Positioned(
          right: edge.right > IaSpacing.gutter ? 4 : 2,
          top: topInset(context) + 176,
          bottom: 150,
          width: 20,
          child: LetterRail(
            letters: letters,
            onPick: (l) {
              setState(() => _bigLetter = l);
              final gk = _groupKeys[l];
              if (gk?.currentContext != null) {
                Scrollable.ensureVisible(gk!.currentContext!,
                    duration: const Duration(milliseconds: 220));
              }
            },
            onEnd: () => setState(() => _bigLetter = null),
          ),
        ),
        if (_bigLetter != null)
          IgnorePointer(
            child: Center(
              child: Text(_bigLetter!,
                  style: TextStyle(
                      fontSize: 64, fontWeight: IaType.light, color: p.accent)),
            ),
          ),
      ],
    );
  }
}
