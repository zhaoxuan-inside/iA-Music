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
      if (mounted) setState(() => _localRows = const []);
      return;
    }
    if (_inflight) return;
    _inflight = true;
    try {
      final rows = await widget.hub.data.library.search(q);
      if (mounted) setState(() => _localRows = rows);
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
        quality: TaskQuality.k192,
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

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('search_page'),
      body: ListView(
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
    );
  }

  List<Widget> _localBody(dynamic p) {
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
    if (_localRows.isEmpty) {
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
    return [
      for (var i = 0; i < _localRows.length; i++)
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
    ];
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
