/// 沉浸播放页：大封面 + 控制 + 歌词/队列两块侧栏（宽屏）或 Tab（窄屏）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/lyrics.dart';
import '../../domain/entities/playback.dart';
import '../../domain/entities/track.dart';
import '../../l10n/app_localizations.dart';
import '../../state/library_providers.dart';
import '../../state/media_providers.dart';
import '../../state/playback_controller.dart';
import '../shared/common.dart' hide TrackRow;

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  bool _showLyrics = false;
  bool _showQueue = false;
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.ia;
    final snap = ref.watch(playbackProvider);
    final track = snap.current;

    if (track == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: AppBar(),
        body: EmptyState(icon: Icons.music_note_outlined, title: s.emptyQueue),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= 880;
    final side = wide
        ? (_showLyrics || _showQueue)
            ? (_showLyrics ? const _LyricsPane() as Widget : const _QueuePane())
            : null
        : null;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: Text(s.nowPlaying,
            style: TextStyle(fontSize: 14, color: p.secondaryText)),
        actions: [
          if (wide) ...[
            IconButton(
              tooltip: s.lyricsTitle,
              icon: Icon(Icons.lyrics, color: _showLyrics ? p.accent : p.secondaryText),
              onPressed: () => setState(() {
                _showLyrics = !_showLyrics;
                if (_showLyrics) _showQueue = false;
              }),
            ),
            IconButton(
              tooltip: s.queueTitle,
              icon: Icon(Icons.queue_music, color: _showQueue ? p.accent : p.secondaryText),
              onPressed: () => setState(() {
                _showQueue = !_showQueue;
                if (_showQueue) _showLyrics = false;
              }),
            ),
          ],
          const SizedBox(width: IaSpacing.s),
        ],
      ),
      body: wide
          ? Row(
              children: [
                Expanded(child: _PlayerBody(track: track, snap: snap, dragValue: _dragValue, onDrag: (v) => setState(() => _dragValue = v), onTogglePane: _togglePane, wide: true)),
                if (side != null)
                  Container(
                    width: 380,
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border(left: BorderSide(color: p.separator)),
                    ),
                    child: side,
                  ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: _showLyrics
                      ? const _LyricsPane()
                      : _showQueue
                          ? const _QueuePane()
                          : _PlayerBody(track: track, snap: snap, dragValue: _dragValue, onDrag: (v) => setState(() => _dragValue = v), onTogglePane: _togglePane, wide: false),
                ),
                if (_showLyrics || _showQueue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: IaSpacing.l),
                    child: TextButton(
                      onPressed: () => setState(() {
                        _showLyrics = false;
                        _showQueue = false;
                      }),
                      child: Text(s.nowPlaying,
                          style: TextStyle(color: p.secondaryText)),
                    ),
                  ),
              ],
            ),
    );
  }

  void _togglePane({bool lyrics = false, bool queue = false}) {
    setState(() {
      _showLyrics = lyrics;
      _showQueue = queue;
    });
  }
}

class _PlayerBody extends ConsumerWidget {
  const _PlayerBody({
    required this.track,
    required this.snap,
    required this.dragValue,
    required this.onDrag,
    required this.onTogglePane,
    this.wide = true,
  });

  final Track track;
  final PlaybackSnapshot snap;
  final double? dragValue;
  final ValueChanged<double> onDrag;
  final void Function({bool lyrics, bool queue}) onTogglePane;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ia;
    final s = S.of(context);
    final ctrl = ref.read(playbackProvider.notifier);
    final maxSec = (snap.durationMs > 0 ? snap.durationMs / 1000.0 : 0.0);
    final value = dragValue ?? snap.positionMs / 1000.0;

    final fav = ref.watch(favoriteProvider(track.id)).value ?? false;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(IaSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: CoverArt(track: track, size: double.infinity),
              ),
              const SizedBox(height: IaSpacing.xl),
              Text(track.title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.mainText),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: IaSpacing.xs),
              Text(track.artistDisplay,
                  style: TextStyle(fontSize: 14, color: p.secondaryText),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: IaSpacing.l),
              Row(children: [
                Text(_fmt(snap.positionMs),
                    style: TextStyle(fontSize: 11.5, color: p.secondaryText)),
                Expanded(
                  child: Slider(
                    value: maxSec > 0 ? value.clamp(0.0, maxSec) : 0,
                    max: maxSec > 0 ? maxSec : 1,
                    onChanged: maxSec > 0 ? onDrag : null,
                    onChangeEnd: (v) {
                      ctrl.seekTo((v * 1000).round());
                      onDrag(0);
                    },
                  ),
                ),
                Text(_fmt(snap.durationMs),
                    style: TextStyle(fontSize: 11.5, color: p.secondaryText)),
              ]),
              const SizedBox(height: IaSpacing.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.shuffle,
                        color: snap.shuffle ? p.accent : p.secondaryText),
                    onPressed: ctrl.toggleShuffle,
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: p.mainText, size: 32),
                    onPressed: ctrl.previous,
                  ),
                  InkWell(
                    onTap: ctrl.togglePlay,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent),
                      child: Icon(
                        snap.loading
                            ? Icons.hourglass_top
                            : (snap.playing ? Icons.pause : Icons.play_arrow),
                        size: 32,
                        color: p.onAccent,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: p.mainText, size: 32),
                    onPressed: ctrl.next,
                  ),
                  IconButton(
                    icon: Icon(fav ? Icons.favorite : Icons.favorite_outline,
                        color: fav ? p.heart : p.secondaryText),
                    onPressed: () async {
                      final cur = await ref.read(dbActionsProvider).isFavorite(track.id);
                      await ref.read(dbActionsProvider).setFavorite(track.id, !cur);
                    },
                  ),
                ],
              ),
              if (!wide) ...[
                const SizedBox(height: IaSpacing.m),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => onTogglePane(lyrics: true),
                      icon: Icon(Icons.lyrics, size: 18, color: p.secondaryText),
                      label: Text(s.lyricsTitle,
                          style: TextStyle(color: p.secondaryText)),
                    ),
                    const SizedBox(width: IaSpacing.l),
                    TextButton.icon(
                      onPressed: () => onTogglePane(queue: true),
                      icon: Icon(Icons.queue_music, size: 18, color: p.secondaryText),
                      label: Text(s.queueTitle,
                          style: TextStyle(color: p.secondaryText)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricsPane extends ConsumerStatefulWidget {
  const _LyricsPane();

  @override
  ConsumerState<_LyricsPane> createState() => _LyricsPaneState();
}

class _LyricsPaneState extends ConsumerState<_LyricsPane> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final s = S.of(context);
    final track = ref.watch(currentTrackProvider);
    final snap = ref.watch(playbackProvider);
    final lyrics = track == null
        ? const AsyncData<LyricsResult?>(null)
        : ref.watch(trackLyricsProvider(track.id));

    final result = lyrics.value;
    final doc = result?.doc;
    final offset = result?.offsetMs ?? 0;

    if (doc == null || doc.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics, size: 44, color: p.secondaryText.withValues(alpha: 0.5)),
            const SizedBox(height: IaSpacing.m),
            Text(s.lyricsEmpty, style: TextStyle(color: p.secondaryText)),
          ],
        ),
      );
    }

    final currentLine = doc.lineIndexAt(snap.positionMs - offset);

    // 当前行滚动
    if (currentLine != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) {
          return;
        }
        const itemExtent = 44.0;
        final target = (currentLine * itemExtent - MediaQuery.sizeOf(context).height / 3)
            .clamp(0.0, _scroll.position.maxScrollExtent);
        if ((_scroll.offset - target).abs() > itemExtent * 1.5) {
          _scroll.animateTo(target,
              duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
        }
      });
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(IaSpacing.xl),
      itemCount: doc.lines.length,
      itemExtent: 44,
      itemBuilder: (_, i) {
        final active = i == currentLine;
        return InkWell(
          onTap: () {
            ref
                .read(playbackProvider.notifier)
                .seekTo(doc.lines[i].tMs + offset);
          },
          child: Container(
            alignment: Alignment.centerLeft,
            child: Text(
              doc.lines[i].text.isEmpty ? '· · ·' : doc.lines[i].text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: active ? 17 : 14.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? p.accent : p.secondaryText.withValues(alpha: 0.85),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QueuePane extends ConsumerWidget {
  const _QueuePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ia;
    final s = S.of(context);
    final snap = ref.watch(playbackProvider);

    if (snap.queue.isEmpty) {
      return Center(
          child: Text(s.emptyQueue, style: TextStyle(color: p.secondaryText)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(IaSpacing.l),
          child: Row(
            children: [
              Text(s.queueTitle,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.mainText)),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(playbackProvider.notifier).clearQueue(),
                child: Text(s.clearQueue,
                    style: TextStyle(fontSize: 12.5, color: p.secondaryText)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: snap.queue.length,
            itemBuilder: (_, i) {
              final t = snap.queue[i];
              final active = i == snap.index;
              return ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: IaSpacing.l),
                leading: active
                    ? Icon(Icons.graphic_eq, size: 18, color: p.accent)
                    : Text('${i + 1}',
                        style: TextStyle(fontSize: 12, color: p.secondaryText)),
                title: Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: active ? p.accent : p.mainText,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                subtitle: Text(t.artistDisplay,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: Icon(Icons.close, size: 16, color: p.secondaryText),
                  onPressed: () =>
                      ref.read(playbackProvider.notifier).removeFromQueue(i),
                ),
                onTap: () async {
                  await ref
                      .read(playbackProvider.notifier)
                      .playTracks(snap.queue, startIndex: i);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

String _fmt(int ms) {
  final m = ms ~/ 60000;
  final sec = (ms % 60000) ~/ 1000;
  return '$m:${sec.toString().padLeft(2, '0')}';
}
