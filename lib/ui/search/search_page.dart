/// 搜索页：本地曲库即时分组 + 已配置在线来源（B 站 / YouTube）聚合搜索。
///
/// 本地结果即时出现；点「在线来源」再查已登录的平台，结果可直接加入提取队列。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../services/collect/bilibili_client.dart';
import '../../services/collect/platform_store.dart';
import '../../services/collect/youtube_client.dart';
import '../../state/collect_providers.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/playlist_providers.dart';
import '../detail/detail_page.dart';
import '../settings/subpages.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

class MusicSearchPage extends ConsumerStatefulWidget {
  const MusicSearchPage({super.key});

  @override
  ConsumerState<MusicSearchPage> createState() => _MusicSearchPageState();
}

class _MusicSearchPageState extends ConsumerState<MusicSearchPage> {
  String _q = '';
  bool _online = false;
  bool _onlineLoading = false;
  String? _onlineError;
  List<Object> _onlineResults = const [];
  int _onlineToken = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final edge = edgeInsets(context);
    final q = _q.trim().toLowerCase();

    final tracks =
        ref.watch(tracksProvider(TrackSort.title)).value ?? const <Track>[];
    final artists = ref.watch(artistsProvider).value ?? const <ArtistGroup>[];
    final albums = ref.watch(albumsProvider).value ?? const <AlbumGroup>[];
    final pls = ref.watch(playlistListProvider).value ?? const <Playlist>[];

    List<T> hit<T>(Iterable<T> src, bool Function(T) test) =>
        q.isEmpty ? <T>[] : src.where(test).toList();

    final fts = q.isEmpty
        ? const <Track>[]
        : (ref.watch(ftsSearchProvider(q)).value ?? const <Track>[]);
    final hitTracks =
        hit(tracks, (t) => _match(q, [t.title, t.artistDisplay, t.albumDisplay]));
    for (final t in fts) {
      if (!hitTracks.any((x) => x.id == t.id)) {
        hitTracks.add(t);
      }
    }
    final hitArtists = hit(artists, (a) => _match(q, [a.artist]));
    final hitAlbums = hit(albums, (a) => _match(q, [a.album, a.artist]));
    final hitPls = hit(pls, (x) => _match(q, [x.name]));
    final playingId = ref.watch(playbackProvider.select((s) => s.current?.id));
    final localEmpty = hitTracks.isEmpty &&
        hitArtists.isEmpty &&
        hitAlbums.isEmpty &&
        hitPls.isEmpty;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      onChanged: _onQuery,
                      onSubmitted: (_) {
                        if (_online) {
                          unawaited(_searchOnline());
                        }
                      },
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: IaType.light,
                          letterSpacing: IaType.titleTracking,
                          color: IaColors.textHi),
                      decoration: InputDecoration(
                        hintText: '歌曲 / 艺人 / 专辑 / 歌单',
                        hintStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: IaType.light,
                            letterSpacing: IaType.titleTracking,
                            color: IaColors.textLow),
                        enabledBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: IaColors.hairlineStrong)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context)
                                    .extension<IaPalette>()!
                                    .accent)),
                        isDense: true,
                        contentPadding: const EdgeInsets.only(bottom: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: edge.left),
              child: Row(
                children: [
                  const ZuneChip(label: '本地曲库', active: true),
                  const SizedBox(width: IaSpacing.s),
                  ZuneChip(
                    label: _online ? '在线来源 · 开' : '在线来源',
                    active: _online,
                    onTap: () {
                      setState(() => _online = !_online);
                      if (_online) {
                        unawaited(_searchOnline());
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            Expanded(
              child: q.isEmpty
                  ? ListView(
                      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 40),
                      children: [
                        const SectionLabel('搜索'),
                        const SizedBox(height: IaSpacing.s),
                        const Text(
                          '本地曲库即时匹配，支持拼音全拼与首字母（如 zjl / zhoujielun）。\n'
                          '点「在线来源」同时搜索已登录的 B 站 / YouTube。',
                          style: TextStyle(
                              fontSize: 12.5, height: 1.6, color: IaColors.textLow),
                        ),
                      ],
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
                      children: [
                        if (_online) ..._onlineSection(),
                        const SectionHead(label: '本地曲库', meta: '即时'),
                        const SizedBox(height: IaSpacing.xs),
                        if (hitArtists.isNotEmpty) ...[
                          const SectionLabel('艺人'),
                          for (final a in hitArtists)
                            _TextRow(
                              text: a.artist,
                              onTap: () => Navigator.of(context).push(
                                  zuneRoute<void>(builder: (_) => DetailPage(
                                      type: DetailType.artist,
                                      id: artistKey(a.artist)))),
                            ),
                        ],
                        if (hitTracks.isNotEmpty) ...[
                          const SizedBox(height: IaSpacing.m),
                          const SectionLabel('歌曲'),
                          for (final t in hitTracks)
                            SongRow(
                              track: t,
                              leading:
                                  CoverArt(track: t, size: IaSpacing.coverSmall),
                              isPlaying: playingId == t.id,
                              isLiked: ref
                                      .watch(favoriteProvider(t.id))
                                      .value ??
                                  false,
                              onTap: () {
                                final qi = hitTracks.indexOf(t);
                                ref
                                    .read(playbackProvider.notifier)
                                    .playTracks(hitTracks,
                                        startIndex: qi < 0 ? 0 : qi);
                              },
                              onLongPress: () => showTrackMenu(context, ref, t),
                            ),
                        ],
                        if (hitAlbums.isNotEmpty) ...[
                          const SizedBox(height: IaSpacing.m),
                          const SectionLabel('专辑'),
                          for (final a in hitAlbums)
                            _TextRow(
                              text: '${a.album} · ${a.artist}',
                              onTap: () => Navigator.of(context).push(
                                  zuneRoute<void>(builder: (_) => DetailPage(
                                      type: DetailType.album,
                                      id: albumKey(a.album)))),
                            ),
                        ],
                        if (hitPls.isNotEmpty) ...[
                          const SizedBox(height: IaSpacing.m),
                          const SectionLabel('歌单'),
                          for (final x in hitPls)
                            _TextRow(
                              text: x.name,
                              onTap: () => Navigator.of(context).push(
                                  zuneRoute<void>(builder: (_) => DetailPage(
                                      type: DetailType.playlist,
                                      id: x.id.toString()))),
                            ),
                        ],
                        if (localEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: IaSpacing.m),
                            child: Text('本地曲库没有匹配的结果',
                                style: TextStyle(
                                    fontSize: 12.5, color: IaColors.textLow)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _onlineSection() {
    return [
      const SizedBox(height: IaSpacing.xs),
      SectionHead(
        label: '在线来源',
        meta: _onlineLoading
            ? '搜索中…'
            : 'B 站 · YouTube · 点击结果加入提取队列',
        trailing: IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, size: 17, color: IaColors.textLow),
          onPressed: _onlineLoading ? null : _searchOnline,
        ),
      ),
      if (_onlineLoading)
        const Padding(
          padding: EdgeInsets.only(top: IaSpacing.s),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (_onlineError != null) ...[
        const SizedBox(height: IaSpacing.s),
        Text(_onlineError!,
            style: const TextStyle(fontSize: 12, color: IaColors.error)),
        TextButton(
          onPressed: () => Navigator.of(context).push(
              zuneRoute<void>(builder: (_) => const CollectSubPage())),
          child: const Text('去设置 · 收集',
              style: TextStyle(fontSize: 12, color: IaColors.textLow)),
        ),
      ],
      for (final r in _onlineResults)
        _OnlineRow(item: r, onTap: () => _enqueueOnline(r)),
      if (!_onlineLoading &&
          _onlineError == null &&
          _onlineResults.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: IaSpacing.s),
          child: Text('在线来源没有结果',
              style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
        ),
      const SizedBox(height: IaSpacing.xl),
    ];
  }

  void _onQuery(String v) {
    setState(() {
      _q = v;
      _onlineResults = const [];
      _onlineError = null;
    });
    _debounce?.cancel();
    if (_online && v.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 650), () {
        unawaited(_searchOnline());
      });
    }
  }

  bool _match(String q, List<String> fields) {
    if (q.isEmpty) {
      return false;
    }
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  /// 聚合搜索已登录平台；未登录时给出明确出路。
  Future<void> _searchOnline() async {
    final q = _q.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _onlineResults = const [];
          _onlineError = null;
          _onlineLoading = false;
        });
      }
      return;
    }

    final bili =
        await ref.read(platformLoginProvider(PlatformId.bilibili).future);
    final yt = await ref.read(platformLoginProvider(PlatformId.youtube).future);
    if (!mounted) {
      return;
    }
    final ids = <PlatformId>[
      if (bili) PlatformId.bilibili,
      if (yt) PlatformId.youtube,
    ];
    if (ids.isEmpty) {
      setState(() {
        _onlineResults = const [];
        _onlineError = '还没有登录在线来源。可以在「设置 · 收集」登录 B 站 / YouTube。';
        _onlineLoading = false;
      });
      return;
    }

    final token = ++_onlineToken;
    setState(() {
      _onlineLoading = true;
      _onlineError = null;
    });

    final results = <Object>[];
    final errors = <String>[];
    for (final id in ids) {
      try {
        final list = switch (id) {
          PlatformId.bilibili =>
            await ref.read(bilibiliClientProvider).search(q),
          PlatformId.youtube =>
            await ref.read(youtubeClientProvider).search(q),
        };
        results.addAll(list);
      } on Object catch (e) {
        errors.add('${id == PlatformId.bilibili ? 'B 站' : 'YouTube'}：$e');
      }
    }
    if (!mounted || token != _onlineToken) {
      return;
    }
    setState(() {
      _onlineLoading = false;
      _onlineResults = results;
      _onlineError = errors.isEmpty ? null : errors.join('\n');
    });
  }

  /// 在线结果 → 提取队列（真实落库 + 驱动执行器）。
  Future<void> _enqueueOnline(Object r) async {
    final (source, url, title, artist) = switch (r) {
      BiliSearchItem b => (
          'bilibili',
          'https://www.bilibili.com/video/${b.bvid}',
          b.title,
          b.author,
        ),
      YtSearchItem y => (
          'youtube',
          'https://www.youtube.com/watch?v=${y.videoId}',
          y.title,
          y.author,
        ),
      _ => ('', '', '', ''),
    };
    if (source.isEmpty) {
      return;
    }
    final api = ref.read(collectTasksApiProvider);
    await api.enqueue(source, url, title: title, artist: artist);
    unawaited(api.drive());
    if (mounted) {
      showWpToast(context, title: '在线来源', message: '已加入提取队列：$title');
    }
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: IaSpacing.m, vertical: IaSpacing.m),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: IaColors.hairline))),
          child: Text(text,
              style: const TextStyle(
                  fontSize: IaType.list, color: IaColors.textHi)),
        ),
      ),
    );
  }
}

class _OnlineRow extends StatelessWidget {
  const _OnlineRow({required this.item, required this.onTap});

  final Object item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final (source, title, author, dur) = switch (item) {
      BiliSearchItem b => ('B 站', b.title, b.author, b.durationSec),
      YtSearchItem y => ('YouTube', y.title, y.author, y.durationSec),
      _ => ('', '', '', 0),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: IaSpacing.m, vertical: IaSpacing.m),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: IaColors.hairline))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: IaType.list, color: IaColors.textHi)),
                    const SizedBox(height: IaSpacing.xs),
                    Text('$source · $author · ${_dur(dur)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: IaColors.textLow)),
                  ],
                ),
              ),
              const SizedBox(width: IaSpacing.m),
              Icon(Icons.download_for_offline_outlined,
                  size: 20, color: p.accent),
            ],
          ),
        ),
      ),
    );
  }

  static String _dur(int sec) =>
      '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
}
