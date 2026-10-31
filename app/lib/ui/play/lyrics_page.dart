/// 歌词页（Harmonoid/DEC-012：居中滚动 + 当前行 accent + 点行 seek +
/// 来源角标（D12-5）+ 底部迷你条）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/play/mini_player.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class LrcLine {
  const LrcLine(this.ms, this.text);
  final int ms;
  final String text;
}

/// LRC 解析（多时间标签展开；无标签/空行丢弃；按时间排序）。
List<LrcLine> parseLrc(String raw) {
  final tag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  final out = <LrcLine>[];
  for (final line in const LineSplitter().convert(raw)) {
    final matches = tag.allMatches(line).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = line.substring(matches.last.end).trim();
    if (text.isEmpty) continue;
    for (final m in matches) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final fracRaw = m.group(3);
      var frac = 0;
      if (fracRaw != null && fracRaw.isNotEmpty) {
        frac = int.parse(fracRaw.padRight(3, '0'));
      }
      out.add(LrcLine((min * 60 + sec) * 1000 + frac, text));
    }
  }
  out.sort((a, b) => a.ms.compareTo(b.ms));
  return out;
}

final class LyricsPage extends StatefulWidget {
  const LyricsPage({
    super.key,
    required this.service,
    required this.data,
    this.covers,
  });

  final PlaybackService service;
  final DataAccess data;
  final CoverChain? covers;

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  static const double _lineExtent = 48;

  List<LrcLine> _lines = const [];
  String? _sourceType;
  bool _loaded = false;
  int? _loadedFor;
  int _lastScrolled = -1;
  final ScrollController _scroll = ScrollController();
  StreamSubscription<PlaybackSnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    final svc = widget.service;
    unawaited(_load(svc.snapshot.currentTrack?.id));
    _sub = svc.status
        .listen((s) => unawaited(_load(s.currentTrack?.id)));
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(int? trackId) async {
    if (trackId == null || trackId == _loadedFor) return;
    final meta = await widget.data.lyrics.metaFor(trackId);
    List<LrcLine> lines = const [];
    final rel = meta?.lrcPath;
    if (rel != null) {
      var path = rel;
      if (!File(path).isAbsolute) {
        // lrcPath 落账为仓库相对路径（extract_queue/enrich/lyrics_service 惯例），
        // 与播放侧 joinAbs 同口径拼根；根缺失（仓库被移除）则读取失败走降级。
        final row = await widget.data.library.rowById(trackId);
        final roots = await widget.data.library.rootsSnapshot();
        final root = row == null
            ? null
            : roots.where((r) => r.id == row.rootId).firstOrNull;
        if (root != null) {
          path = PlaybackService.joinAbs(root.path, rel);
        }
      }
      try {
        lines = parseLrc(await File(path).readAsString());
      } catch (_) {
        lines = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      _loadedFor = trackId;
      _lines = lines;
      _sourceType = meta?.type.name;
      _loaded = true;
      _lastScrolled = -1;
    });
  }

  int _indexAt(int posMs) {
    if (_lines.isEmpty) return -1;
    var lo = 0, hi = _lines.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lines[mid].ms <= posMs) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  void _scrollTo(int index) {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (index * _lineExtent + _lineExtent / 2 - viewport / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('lyrics_page'),
      appBar: AppBar(
        title: Text(t.lyricsTitle),
        actions: [
          if (_sourceType != null)
            Padding(
              key: const ValueKey('lyrics_source_badge'),
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  switch (_sourceType) {
                    'lrc' => 'LRCLIB',
                    'subtitle' => t.sourceBiliSubtitle,
                    'asr' => t.sourceAsr,
                    _ => _sourceType!,
                  },
                  style: TextStyle(
                    fontSize: 11,
                    color: p.secondaryText,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<PlaybackSnapshot>(
              initialData: widget.service.snapshot,
              stream: widget.service.status,
              builder: (context, snap) {
                final s = snap.data;
                final cur = s?.currentTrack;
                if (!_loaded || cur == null) {
                  return Center(
                      key: const ValueKey('lyrics_loading'),
                      child: Text(t.loading));
                }
                if (_lines.isEmpty) {
                  return Center(
                    key: const ValueKey('lyrics_empty'),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(IaIcon.lyrics, size: 48, color: p.secondaryText),
                          const SizedBox(height: 16),
                          Text(t.lyricsEmptyTitle,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            t.lyricsEmptyBody,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: p.secondaryText,
                                height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final idx = _indexAt(s?.positionMs ?? 0);
                if (idx != _lastScrolled) {
                  _lastScrolled = idx;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollTo(idx));
                }
                return ListView.builder(
                  key: const ValueKey('lyrics_list'),
                  controller: _scroll,
                  itemExtent: _lineExtent,
                  padding: const EdgeInsets.symmetric(vertical: 120),
                  itemCount: _lines.length,
                  itemBuilder: (context, i) {
                    final line = _lines[i];
                    final active = i == idx;
                    final passed = i < idx;
                    return InkWell(
                      key: ValueKey('lyrics_line_$i'),
                      onTap: () => unawaited(widget.service.seekTo(line.ms)),
                      child: Center(
                        child: Text(
                          line.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? p.accent
                                : (passed
                                    ? p.secondaryText
                                    : p.secondaryText.withValues(alpha: 0.55)),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.covers != null)
            SidebarMiniPlayer(
              key: const ValueKey('lyrics_strip'),
              service: widget.service,
              data: widget.data,
              covers: widget.covers!,
            ),
        ],
      ),
    );
  }
}
