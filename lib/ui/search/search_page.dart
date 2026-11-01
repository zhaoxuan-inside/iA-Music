/// 搜索页（本地曲库 + B 站发现双模式 · DEC-012 重写）。
///
/// * 本地：FTS 即时检索（data.library.search）→ 点行起播。
/// * B 站：关键词搜索（SearchPort，未登录可搜）→ 结果行「提取」入队
///   （默认开歌词+字幕）；粘贴链接/ BV 直接解析提取。
/// * AuthRequiredSearchException → 引导扫码登录。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:contracts/contracts.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/extract/extract_page.dart';
import 'package:ia_music/ui/library/albums_page.dart';
import 'package:ia_music/ui/library/artists_page.dart';
import 'package:ia_music/ui/playlists/playlists_page.dart';
import 'package:ia_music/ui/login/bili_login_page.dart';
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/shared/track_menu.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.hub,
    required this.ensurePlayback,
    this.accent,
  });

  final LibraryHub hub;
  final Future<PlaybackService> Function() ensurePlayback;

  /// 动态取色（B 站封面预览不参与；预留装配位）。
  final dynamic accent;

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _biliMode = false;

  List<Track> _localRows = const [];
  List<SearchResult> _biliRows = const [];
  String _biliError = '';

  /// 分区结果（WS5/REQ-NAV-04：歌手/专辑/歌单；展开态=查看全部）。
  List<({Artist artist, int count, int sampleTrackId})> _artistHits = const [];
  List<({Album album, int count, int sampleTrackId})> _albumHits = const [];
  List<Playlist> _playlistHits = const [];
  final Set<String> _expandedSections = {};

  /// 错误性质：true=风控要求登录（显示扫码 CTA）；false=网络/其他（重试）。
  bool _biliErrorIsAuth = false;
  bool _biliLoading = false;
  bool _inflight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQuery);
    _controller.dispose();
    super.dispose();
  }

  void _onQuery() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_biliMode) {
        unawaited(_searchBili(enter: false));
      } else {
        unawaited(_searchLocal());
      }
    });
  }

  Future<void> _searchLocal() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _localRows = const [];
          _artistHits = const [];
          _albumHits = const [];
          _playlistHits = const [];
          _expandedSections.clear();
        });
      }
      return;
    }
    if (_inflight) return;
    _inflight = true;
    try {
      final rows = await widget.hub.data.library.search(q);
      // 分区结果（WS5/REQ-NAV-04：歌手/专辑/歌单；每区 ≤3 条 + 查看全部）
      final artists = await widget.hub.data.library.searchArtistsNamed(q);
      final albums = await widget.hub.data.library.searchAlbumsNamed(q);
      final playlists = await widget.hub.data.library.searchPlaylistsNamed(q);
      if (mounted) {
        setState(() {
          _localRows = rows;
          _artistHits = artists;
          _albumHits = albums;
          _playlistHits = playlists;
          _expandedSections.clear();
        });
      }
    } finally {
      _inflight = false;
    }
  }

  Future<void> _searchBili({bool enter = true}) async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    if (RegExp(r'https?://|www\.|bv[0-9A-Za-z]{10}', caseSensitive: false)
        .hasMatch(q)) {
      await _openExtract(q); // 链接/BV → 提取页解析
      return;
    }
    setState(() {
      _biliLoading = true;
      _biliError = '';
      _biliErrorIsAuth = false;
    });
    try {
      final rows = await widget.hub.searchAdapter.search(q, limit: 20);
      if (mounted) {
        setState(() => _biliRows = rows);
      }
    } on AuthRequiredSearchException catch (e) {
      if (mounted) {
        setState(() {
          _biliError = e.message;
          _biliErrorIsAuth = true; // 平台风控要求登录 → 才引导扫码
        });
      }
    } on SocketException catch (_) {
      if (mounted) {
        setState(() => _biliError = sOf(context).biliNetworkError);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _biliError = sOf(context).searchFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _biliLoading = false);
    }
  }

  Future<void> _extractResult(SearchResult r) async {
    try {
      await widget.hub.extract.enqueueUrl(
        r.url,
        // 快捷入队=默认最高音质（PRD REQ-EXT-01；登录 Cookie 自动携带）
        quality: TaskQuality.hires,
        withLyrics: true,
        withText: true,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sOf(context).extractQueued(r.title))),
        );
      }
    } on StateError {
      // 合规门禁未确认 → 提取页承担声明卡。
      await _openExtract(r.url);
    }
  }

  Future<void> _openExtract([String? prefill]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ExtractPage(hub: widget.hub, prefill: prefill),
    ));
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BiliLoginPage(auth: widget.hub.authAdapter),
    ));
  }

  Future<void> _playLocal(List<Track> rows, int index) async {
    final svc = await widget.ensurePlayback();
    await svc.playTrackIds(
      [for (final t in rows) t.id],
      startIndex: index,
    );
  }

  /// 行上下文菜单（WS2）：起播域就绪后弹出（服务面：下一首播放可用）。
  Future<void> _openTrackMenu(Track track) async {
    final svc = await widget.ensurePlayback();
    if (!mounted) return;
    await showTrackMenu(
      context,
      track: track,
      hub: widget.hub,
      service: svc,
      onChanged: () => unawaited(_searchLocal()),
    );
  }

  /// 分区跳转（复用各域详情页；REQ-NAV-04 分区→详情闭环）。
  Future<void> _openArtistDetail(int artistId) async {
    final hit = (await widget.hub.data.library.artistsWithCounts())
        .where((e) => e.artist.id == artistId)
        .firstOrNull;
    if (hit == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ArtistDetailPage(
        hub: widget.hub,
        artist: hit.artist,
        sampleTrackId: hit.sampleTrackId,
        playTracks: (ids, {startIndex = 0}) async {
          final svc = await widget.ensurePlayback();
          await svc.playTrackIds(ids, startIndex: startIndex);
          return svc;
        },
        onPlayRequested: () {},
      ),
    ));
  }

  Future<void> _openAlbumDetail(int albumId, int sampleTrackId, String name) async {
    final album = (await widget.hub.data.library.albumsWithCounts())
        .where((e) => e.album.id == albumId)
        .map((e) => e.album)
        .firstOrNull;
    if (album == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AlbumDetailPage(
        hub: widget.hub,
        album: album,
        count: 0,
        sampleTrackId: sampleTrackId,
        playTracks: (ids, {startIndex = 0}) async {
          final svc = await widget.ensurePlayback();
          await svc.playTrackIds(ids, startIndex: startIndex);
          return svc;
        },
        onPlayRequested: () {},
      ),
    ));
  }

  Future<void> _openPlaylistDetail(int playlistId, String name) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlaylistDetailPage(
        playlistId: playlistId,
        title: name,
        data: widget.hub.data,
        ensurePlayback: widget.ensurePlayback,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('search_page'),
      // 视觉打磨：内容列限宽居中（与设置页同口径）。
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            t.navSearch,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.05,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('search_input'),
                  controller: _controller,
                  onSubmitted: (_) => unawaited(_searchBili()),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: _biliMode
                        ? t.searchHintBili
                        : t.searchHintLocal,
                    prefixIcon: Icon(IaIcon.search,
                        size: 20, color: p.secondaryText),
                  ),
                ),
              ),
              if (_biliMode) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('search_go'),
                  tooltip: t.navSearch,
                  onPressed: () => unawaited(_searchBili()),
                  icon: Icon(IaIcon.arrowForward),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            key: const ValueKey('search_mode'),
            segments: [
              ButtonSegment(value: false, label: Text(t.segmentLocal)),
              ButtonSegment(value: true, label: Text(t.segmentBili)),
            ],
            selected: {_biliMode},
            onSelectionChanged: (s) {
              setState(() => _biliMode = s.first);
              if (_biliMode) {
                unawaited(_searchBili(enter: false));
              } else {
                unawaited(_searchLocal());
              }
            },
          ),
          const SizedBox(height: 16),
          if (!_biliMode) ..._localBody(p) else ..._biliBody(p),
        ],
          ),
        ),
      ),
    );
  }

  List<Widget> _localBody(IaPalette p) {
    final t = sOf(context);
    if (_controller.text.isEmpty) {
      return [
        Center(
          key: const ValueKey('search_local_empty'),
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Text(
              t.searchLocalHint,
              style: TextStyle(fontSize: 13, color: p.secondaryText),
            ),
          ),
        ),
      ];
    }
    if (_localRows.isEmpty &&
        _artistHits.isEmpty &&
        _albumHits.isEmpty &&
        _playlistHits.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Text(
              t.searchNoResults(_controller.text),
              style: TextStyle(fontSize: 13, color: p.secondaryText),
            ),
          ),
        ),
      ];
    }
    // 分区（REQ-NAV-04）：曲目 / 歌手 / 专辑 / 歌单；每区 ≤3 条 + 查看全部
    final tracksAll = _expandedSections.contains('tracks');
    final shownTracks = tracksAll ? _localRows : _localRows.take(3);
    return [
      if (_localRows.isNotEmpty) ...[
        _sectionHeader(t.navTracks, 'tracks', _localRows.length),
        for (var i = 0; i < shownTracks.length; i++)
          InkWell(
            key: ValueKey('search_local_row_$i'),
            onTap: () => unawaited(_playLocal(_localRows, i)),
            onLongPress: () => unawaited(_openTrackMenu(_localRows[i])),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CoverArt(
                    trackId: _localRows[i].id,
                    title: _localRows[i].title ?? '',
                    data: widget.hub.data,
                    chain: widget.hub.covers,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _localRows[i].title ?? sOf(context).untitled,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _localRows[i].artistDisplay ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: p.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    iaMmss(_localRows[i].durationMs ?? 0),
                    style: TextStyle(
                      fontSize: 12,
                      color: p.secondaryText,
                      fontFeatures: kIaNumericFeatures,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      if (_artistHits.isNotEmpty) ...[
        _sectionHeader(t.navArtists, 'artists', _artistHits.length),
        for (final e in (_expandedSections.contains('artists')
            ? _artistHits
            : _artistHits.take(3)))
          ListTile(
            key: ValueKey('search_artist_${e.artist.id}'),
            dense: true,
            leading: Icon(IaIcon.person, size: 20, color: p.secondaryText),
            title: Text(e.artist.name, maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(t.trackCount(e.count)),
            onTap: () {
              // 分区命中 → 跳转歌手详情页（复用 ArtistsPage 的详情构造）
              unawaited(_openArtistDetail(e.artist.id));
            },
          ),
      ],
      if (_albumHits.isNotEmpty) ...[
        _sectionHeader(t.navAlbums, 'albums', _albumHits.length),
        for (final e in (_expandedSections.contains('albums')
            ? _albumHits
            : _albumHits.take(3)))
          ListTile(
            key: ValueKey('search_album_${e.album.id}'),
            dense: true,
            leading: Icon(IaIcon.album, size: 20, color: p.secondaryText),
            title: Text(e.album.name, maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(t.trackCount(e.count)),
            onTap: () => unawaited(
                _openAlbumDetail(e.album.id, e.sampleTrackId, e.album.name)),
          ),
      ],
      if (_playlistHits.isNotEmpty) ...[
        _sectionHeader(t.navPlaylists, 'playlists', _playlistHits.length),
        for (final pl in (_expandedSections.contains('playlists')
            ? _playlistHits
            : _playlistHits.take(3)))
          ListTile(
            key: ValueKey('search_playlist_${pl.id}'),
            dense: true,
            leading: Icon(IaIcon.playlist, size: 20, color: p.secondaryText),
            title: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => unawaited(_openPlaylistDetail(pl.id, pl.name)),
          ),
      ],
    ];
  }

  /// 分区头：标题 + 计数 + 查看全部切换（≤3 条截断时才显示）。
  Widget _sectionHeader(String label, String key, int total) {
    final p = context.ia;
    final t = sOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p.secondaryText,
                  letterSpacing: 0.05)),
          const SizedBox(width: 8),
          Text('$total',
              style: TextStyle(
                  fontSize: 11,
                  color: p.secondaryText,
                  fontFeatures: kIaNumericFeatures)),
          const Spacer(),
          if (total > 3)
            TextButton(
              key: ValueKey('search_more_$key'),
              onPressed: () => setState(() {
                _expandedSections.contains(key)
                    ? _expandedSections.remove(key)
                    : _expandedSections.add(key);
              }),
              child: Text(t.searchViewAll,
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  List<Widget> _biliBody(dynamic p) {
    final t = sOf(context);
    if (_biliError.isNotEmpty) {
      return [
        Padding(
          key: const ValueKey('search_bili_error'),
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            children: [
              Text(_biliError,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: p.error)),
              const SizedBox(height: 12),
              if (_biliErrorIsAuth)
                FilledButton.icon(
                  key: const ValueKey('search_bili_login'),
                  onPressed: () => unawaited(_openLogin()),
                  icon: Icon(IaIcon.scanQr),
                  label: Text(t.scanLoginBili),
                )
              else
                FilledButton.tonalIcon(
                  key: const ValueKey('search_bili_retry'),
                  onPressed: () => unawaited(_searchBili()),
                  icon: Icon(IaIcon.refresh),
                  label: Text(t.retryAction),
                ),
            ],
          ),
        ),
      ];
    }
    if (_biliLoading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_controller.text.isNotEmpty && _biliRows.isEmpty) {
      return [
        Padding(
          key: const ValueKey('search_bili_empty'),
          padding: const EdgeInsets.only(top: 48),
          child: Center(
            child: Text(
              t.biliNoResults,
              style: TextStyle(fontSize: 13, color: p.secondaryText),
            ),
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < _biliRows.length; i++) _biliRow(p, _biliRows[i], i),
      const SizedBox(height: 12),
      Center(
        child: TextButton.icon(
          key: const ValueKey('search_extract_entry'),
          onPressed: () => unawaited(_openExtract()),
          icon: Icon(IaIcon.extract),
          label: Text(t.openExtractQueue),
        ),
      ),
    ];
  }

  Widget _biliRow(dynamic p, SearchResult r, int i) {
    return Padding(
      key: ValueKey('search_bili_row_$i'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(IaRadius.coverSm),
            child: SizedBox(
              width: 72,
              height: 44,
              child: r.coverUrl == null
                  ? ColoredBox(
                      color: p.lifted,
                      child: Icon(IaIcon.musicNote,
                          size: 20, color: p.secondaryText),
                    )
                  : Image.network(
                      r.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: p.lifted,
                        child: Icon(IaIcon.musicNote,
                            size: 20, color: p.secondaryText),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  sOf(context).biliRowMeta(
                      r.uploader, iaMmss(r.durationMs), iaPlayCount(r.playCount)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: ValueKey('search_bili_extract_$i'),
            tooltip: sOf(context).extractTooltip,
            onPressed: () => unawaited(_extractResult(r)),
            icon: Icon(IaIcon.download, size: 20),
          ),
        ],
      ),
    );
  }
}
