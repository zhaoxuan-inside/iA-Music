/// 搜索页：本地曲库即时分组 + 已启用音频源插件聚合搜索。
///
/// 本地结果即时出现；点「在线来源」再查已登录的插件，结果可直接加入提取队列。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../state/collect_providers.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/playlist_providers.dart';
import '../detail/detail_page.dart';
import '../settings/link_extract_page.dart';
import '../settings/plugins_page.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

/// 在线搜索结果（跨插件统一形状）。
class SearchHit {
  const SearchHit({
    required this.pluginId,
    required this.pluginName,
    required this.url,
    required this.title,
    required this.artist,
    required this.durationSec,
  });

  final String pluginId;
  final String pluginName;
  final String url;
  final String title;
  final String artist;
  final int durationSec;
}

class MusicSearchPage extends ConsumerStatefulWidget {
  const MusicSearchPage({super.key});

  @override
  ConsumerState<MusicSearchPage> createState() => _MusicSearchPageState();
}

class _MusicSearchPageState extends ConsumerState<MusicSearchPage> {
  /// 过滤用查询词（150ms 防抖后才更新——原每按键即时 setState，
  /// 全库 4 张表 × contains 在每次击键同步重跑）。
  String _q = '';
  bool _online = false;
  bool _onlineLoading = false;
  String? _onlineError;
  List<SearchHit> _onlineResults = const [];
  int _onlineToken = 0;
  Timer? _debounce;
  Timer? _onlineDebounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _onlineDebounce?.cancel();
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
    final favs = ref.watch(favoritesSetProvider).value ?? const <int>{};
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
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(context).push(zuneRoute<void>(
                        builder: (_) => const LinkExtractPage())),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('从链接提取 ›',
                          style:
                              TextStyle(fontSize: 11, color: IaColors.textLow)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            Expanded(
              child: q.isEmpty
                  ? ListView(
                      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 40),
                      children: const [
                        SectionLabel('搜索'),
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
                              isLiked: favs.contains(t.id),
                              missing: t.missing,
                              onTap: () => ref
                                  .read(playbackProvider.notifier)
                                  .playTrack(t, queue: hitTracks),
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
        meta: _onlineLoading ? '搜索中…' : '已登录的音频源插件',
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
              zuneRoute<void>(builder: (_) => const PluginsPage())),
          child: const Text('去「插件」管理音频源',
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
    _debounce?.cancel();
    _onlineDebounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _q = v;
        _onlineResults = const [];
        _onlineError = null;
      });
    });
    if (_online && v.trim().isNotEmpty) {
      _onlineDebounce = Timer(const Duration(milliseconds: 650), () {
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

  /// 聚合搜索已登录的音频源插件；未登录时给出明确出路。
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

    final handles = await ref.read(sourceHandlesProvider.future);
    if (!mounted) {
      return;
    }
    // 只问已登录的插件（登录态在插件沙箱里，宿主只见状态）
    final logged = <SourcePluginHandle>[];
    for (final h in handles) {
      final st = await ref.read(sourceAuthStatusProvider(h.id).future);
      if (st.loggedIn) {
        logged.add(h);
      }
    }
    if (!mounted) {
      return;
    }
    if (logged.isEmpty) {
      setState(() {
        _onlineResults = const [];
        _onlineError = '还没有登录在线来源。可以在「设置 · 收集」登录已安装的音频源插件。';
        _onlineLoading = false;
      });
      return;
    }

    final token = ++_onlineToken;
    setState(() {
      _onlineLoading = true;
      _onlineError = null;
    });

    final results = <SearchHit>[];
    final errors = <String>[];
    for (final h in logged) {
      try {
        final list = await h.search(q);
        results.addAll([
          for (final item in list)
            SearchHit(
              pluginId: h.id,
              pluginName: h.name,
              url: '${item['url'] ?? ''}',
              title: '${item['title'] ?? ''}',
              artist: '${item['artist'] ?? ''}',
              durationSec: (item['durationSec'] as num?)?.toInt() ?? 0,
            ),
        ]);
      } on Object catch (e) {
        errors.add('${h.name}：$e');
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
  Future<void> _enqueueOnline(SearchHit r) async {
    if (r.url.isEmpty) {
      return;
    }
    final api = ref.read(collectTasksApiProvider);
    await api.enqueue(r.pluginId, r.url, title: r.title, artist: r.artist);
    unawaited(api.drive());
    if (mounted) {
      showWpToast(context, title: '在线来源', message: '已加入提取队列：${r.title}');
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

  final SearchHit item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final source = item.pluginName;
    final title = item.title;
    final author = item.artist;
    final dur = item.durationSec;
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
                    Text('$source · $author · ${formatDuration(dur * 1000)}',
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
}
