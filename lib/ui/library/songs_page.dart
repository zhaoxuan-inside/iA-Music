/// 曲库屏（Hub 屏2）：全部歌曲按歌名字母排序，右缘字母导航轨。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/letter.dart';
import '../../state/playback_controller.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
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

    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
          itemCount: slots.length,
          itemBuilder: (context, i) {
            final slot = slots[i];
            final child = switch (slot) {
              _Header(:final letter) => Container(
                  key: _groupKeys.putIfAbsent(letter, () => GlobalKey()),
                  padding: const EdgeInsets.only(top: IaSpacing.l, bottom: IaSpacing.s),
                  child: Text(letter,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: IaType.semibold,
                          letterSpacing: 1.2,
                          color: p.accent)),
                ),
              _Song(:final track, :final flatIndex) => Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CoverArt(track: track, size: IaSpacing.coverSmall),
                    Expanded(
                      child: SongRow(
                        track: track,
                        isPlaying: playingId == track.id,
                        isLiked:
                            ref.watch(favoriteProvider(track.id)).value ?? false,
                        onTap: () => ref
                            .read(playbackProvider.notifier)
                            .playTracks(tracks, startIndex: flatIndex),
                        onLongPress: () => showTrackMenu(context, ref, track),
                      ),
                    ),
                  ],
                ),
            };
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: edge.left),
              child: child,
            );
          },
        ),
        Positioned(
          right: edge.right > IaSpacing.gutter ? 4 : 2,
          top: 70,
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
