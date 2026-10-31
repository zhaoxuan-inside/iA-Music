/// 歌词页（Harmonoid/DEC-012：居中滚动 + 当前行 accent + 点行 seek +
/// 来源角标（D12-5）+ 底部迷你条；WS4：偏移调整/粘贴歌词/生成歌词/预览编辑）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/lyrics/lyrics_service.dart';
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

/// 行序列化（偏移写回 .lrc 用；REQ-LYR-03 保存语义）。
String serializeLrc(List<LrcLine> lines) {
  final b = StringBuffer();
  for (final l in lines) {
    final total = (l.ms / 1000).round();
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    final frac = (l.ms % 1000).toString().padLeft(3, '0');
    b.writeln('[$mm:$ss.$frac]${l.text}');
  }
  return b.toString();
}

final class LyricsPage extends StatefulWidget {
  const LyricsPage({
    super.key,
    required this.service,
    required this.data,
    this.covers,
    this.hub,
  });

  final PlaybackService service;
  final DataAccess data;
  final CoverChain? covers;

  /// 组合根（WS4 生成歌词面；null=生成入口隐藏）。
  final LibraryHub? hub;

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  static const double _lineExtent = 48;
  static const int _offsetStepMs = 500;
  static const int _offsetClampMs = 10000;

  List<LrcLine> _lines = const [];
  String? _sourceType;
  bool _loaded = false;
  int? _loadedFor;
  int _lastScrolled = -1;
  final ScrollController _scroll = ScrollController();
  StreamSubscription<PlaybackSnapshot>? _sub;

  Track? _track; // 行数据（根路径解析/落盘锚）
  String? _lrcAbsPath; // 已解析的 .lrc 绝对路径（写回/预览用）
  int _offsetMs = 0; // REQ-LYR-03：单曲偏移（DB lyrics_meta.offsetMs）
  bool _busy = false; // 生成中
  double _fontSize = 17; // REQ-ONB-04 歌词字号（设置 s/m/l → 15/17/20）

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
    final row = await widget.data.library.rowById(trackId);
    final fsRaw = await widget.data.shell.value('lyrics.fontSize');
    final fs = switch (fsRaw) {
      's' => 15.0,
      'l' => 20.0,
      _ => 17.0,
    };
    List<LrcLine> lines = const [];
    String? absPath;
    final rel = meta?.lrcPath;
    if (rel != null) {
      var path = rel;
      if (!File(path).isAbsolute) {
        // lrcPath 落账为仓库相对路径（extract_queue/enrich/lyrics_service 惯例），
        // 与播放侧 joinAbs 同口径拼根；根缺失（仓库被移除）则读取失败走降级。
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
        absPath = path;
      } catch (_) {
        lines = const [];
      }
    } else if (meta?.type == LyricsSourceType.paste &&
        (meta?.sourceText ?? '').isNotEmpty) {
      // 纯文本粘贴（REQ-LYR-04）：静态展示（无时间轴高亮）
      lines = [
        for (final l in const LineSplitter()
            .convert(meta!.sourceText!)
            .where((l) => l.trim().isNotEmpty))
          LrcLine(-1, l.trim()),
      ];
    }
    if (!mounted) return;
    setState(() {
      _loadedFor = trackId;
      _lines = lines;
      _sourceType = meta?.type.name;
      _track = row;
      _lrcAbsPath = absPath;
      _offsetMs = meta?.offsetMs ?? 0;
      _fontSize = fs;
      _loaded = true;
      _lastScrolled = -1;
    });
  }

  /// 时间轴应用偏移（正=歌词延后）：高亮定位与点行 seek 统一口径。
  int _shiftedMs(LrcLine l) => l.ms < 0 ? l.ms : l.ms + _offsetMs;

  int _indexAt(int posMs) {
    if (_lines.isEmpty) return -1;
    var lo = 0, hi = _lines.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_shiftedMs(_lines[mid]) <= posMs) {
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

  // ── WS4：偏移 ────────────────────────────────────────────

  Future<void> _saveOffset(int newOffset, {bool writeBack = false}) async {
    final trackId = _loadedFor;
    if (trackId == null) return;
    final meta = await widget.data.lyrics.metaFor(trackId);
    if (writeBack && _lrcAbsPath != null && _lines.isNotEmpty) {
      // 写回文件（时间戳平移）+ edited=true（enrich 覆写守卫线）+ 归零 DB 偏移
      final shifted = [
        for (final l in _lines)
          l.ms < 0 ? l : LrcLine(l.ms + _offsetMs, l.text),
      ];
      final f = File(_lrcAbsPath!);
      try {
        await f.writeAsString(serializeLrc(shifted), flush: true);
      } on FileSystemException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(sOf(context).modelDownloadFailed)));
        return;
      }
      await widget.data.lyrics.upsertMeta(
        trackId: trackId,
        type: meta?.type ?? LyricsSourceType.lrc,
        offsetMs: 0,
        lrcPath: meta?.lrcPath,
        sourceText: meta?.sourceText,
        edited: true,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await widget.data.lyrics.upsertMeta(
        trackId: trackId,
        type: meta?.type ?? LyricsSourceType.none,
        offsetMs: newOffset.clamp(-_offsetClampMs, _offsetClampMs),
        lrcPath: meta?.lrcPath,
        sourceText: meta?.sourceText,
        edited: meta?.edited ?? false,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sOf(context).lyricsOffsetSaved)));
    final t = _loadedFor;
    setState(() => _loadedFor = null); // 强制重载
    unawaited(_load(t));
  }

  void _openOffsetSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final p = sheetCtx.ia;
        final tt = sOf(sheetCtx);
        return StatefulBuilder(builder: (sheetCtx, setSheet) {
          final cur = _offsetMs;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tt.lyricsOffset,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        key: const ValueKey('lyrics_offset_down'),
                        onPressed: () {
                          final v =
                              (cur - _offsetStepMs).clamp(-_offsetClampMs, _offsetClampMs);
                          setState(() => _offsetMs = v);
                          setSheet(() {});
                        },
                        icon: Icon(IaIcon.back),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          tt.lyricsOffsetValue(
                              (cur / 1000).toStringAsFixed(1)),
                          key: const ValueKey('lyrics_offset_value'),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: p.accent,
                              fontFeatures: kIaNumericFeatures),
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const ValueKey('lyrics_offset_up'),
                        onPressed: () {
                          final v =
                              (cur + _offsetStepMs).clamp(-_offsetClampMs, _offsetClampMs);
                          setState(() => _offsetMs = v);
                          setSheet(() {});
                        },
                        icon: Icon(IaIcon.arrowForward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const ValueKey('lyrics_offset_reset'),
                        onPressed: cur == 0
                            ? null
                            : () {
                                setState(() => _offsetMs = 0);
                                setSheet(() {});
                              },
                        child: Text(tt.lyricsOffsetReset),
                      ),
                      const SizedBox(width: 8),
                      if (_lrcAbsPath != null && _lines.isNotEmpty)
                        FilledButton.tonal(
                          key: const ValueKey('lyrics_offset_write'),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            unawaited(_saveOffset(cur, writeBack: true));
                          },
                          child: Text(tt.lyricsOffsetWriteBack),
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const ValueKey('lyrics_offset_save'),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          unawaited(_saveOffset(cur));
                        },
                        child: Text(tt.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ── WS4：粘贴歌词（REQ-LYR-04） ──────────────────────────

  Future<void> _pasteLyrics() async {
    final trackId = _loadedFor;
    if (trackId == null) return;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(sOf(dlgCtx).lyricsPaste),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: const ValueKey('lyrics_paste_input'),
            controller: controller,
            maxLines: 10,
            autofocus: true,
            decoration:
                InputDecoration(hintText: sOf(dlgCtx).lyricsPasteHint),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text(sOf(dlgCtx).cancel)),
          FilledButton(
            key: const ValueKey('lyrics_paste_save'),
            onPressed: () => Navigator.pop(dlgCtx, controller.text.trim()),
            child: Text(sOf(dlgCtx).save),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    await _savePastedLyrics(trackId, text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(sOf(context).lyricsPasteSaved)));
  }

  /// 粘贴落库：含 `[mm:ss` → .lrc 旁车落盘（type=lrc, edited=true）；
  /// 纯文本 → type=paste + sourceText 内嵌（静态展示）。
  Future<void> _savePastedLyrics(int trackId, String text) async {
    final row = await widget.data.library.rowById(trackId);
    final meta = await widget.data.lyrics.metaFor(trackId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (text.contains('[') && row != null) {
      final roots = await widget.data.library.rootsSnapshot();
      final root = roots.where((r) => r.id == row.rootId).firstOrNull;
      if (root != null) {
        final rel =
            row.relPath.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
        final abs = PlaybackService.joinAbs(root.path, rel);
        final f = File(abs);
        if (!f.existsSync()) {
          f.createSync(recursive: false);
        }
        await f.writeAsString('$text\n', flush: true);
        await widget.data.lyrics.upsertMeta(
          trackId: trackId,
          type: LyricsSourceType.lrc,
          offsetMs: 0,
          lrcPath: rel,
          sourceText: meta?.sourceText,
          edited: true,
          nowMs: now,
        );
      }
    } else {
      await widget.data.lyrics.upsertMeta(
        trackId: trackId,
        type: LyricsSourceType.paste,
        offsetMs: meta?.offsetMs ?? 0,
        lrcPath: meta?.lrcPath,
        sourceText: text,
        edited: true,
        nowMs: now,
      );
    }
    final t = trackId;
    setState(() => _loadedFor = null);
    unawaited(_load(t));
  }

  // ── WS4：生成歌词（REQ-LYR-05/LYRAI-01..04） ─────────────

  Future<bool> _modelPresent() async {
    for (final m in await widget.data.shell.modelsAll()) {
      if (m.modelId.contains('sensevoice') &&
          m.status == ModelStatus.present &&
          (m.localPath ?? '').isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _generate() async {
    final hub = widget.hub;
    final trackId = _loadedFor;
    if (hub == null || trackId == null || _busy) return;
    if (!await _modelPresent()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sOf(context).lyricsGenNoModel)));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final outcome = await hub.extract.lyrics.runForTrack(trackId);
      if (!mounted) return;
      setState(() => _busy = false);
      if (outcome.kind == LyricsOutcomeKind.asrGenerated &&
          outcome.lrcPath != null) {
        final t = trackId;
        setState(() => _loadedFor = null); // 重载新歌词
        unawaited(_load(t));
        await _previewDialog(outcome.lrcPath!, trackId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(sOf(context).lyricsGenStarted)));
      }
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sOf(context).modelDownloadFailed)));
      }
    }
  }

  /// 生成结果预览编辑（REQ-LYRAI-04：可修正错别字后保存 → .lrc + edited）。
  Future<void> _previewDialog(String lrcPath, int trackId) async {
    var path = lrcPath;
    if (!File(path).isAbsolute) {
      final row = _track;
      final roots = await widget.data.library.rootsSnapshot();
      final root = row == null
          ? null
          : roots.where((r) => r.id == row.rootId).firstOrNull;
      if (root != null) {
        path = PlaybackService.joinAbs(root.path, path);
      }
    }
    String content = '';
    try {
      content = await File(path).readAsString();
    } on FileSystemException {
      return;
    }
    if (!mounted) return;
    final controller = TextEditingController(text: content);
    final edited = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(sOf(dlgCtx).lyricsPreviewTitle),
        content: SizedBox(
          width: 480,
          height: 360,
          child: TextField(
            key: const ValueKey('lyrics_preview_input'),
            controller: controller,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text(sOf(dlgCtx).cancel)),
          FilledButton(
            key: const ValueKey('lyrics_preview_save'),
            onPressed: () => Navigator.pop(dlgCtx, controller.text),
            child: Text(sOf(dlgCtx).lyricsPreviewSave),
          ),
        ],
      ),
    );
    if (edited == null || edited == content) return;
    await File(path).writeAsString('$edited\n', flush: true);
    final meta = await widget.data.lyrics.metaFor(trackId);
    await widget.data.lyrics.upsertMeta(
      trackId: trackId,
      type: meta?.type ?? LyricsSourceType.asr,
      offsetMs: meta?.offsetMs ?? 0,
      lrcPath: meta?.lrcPath,
      sourceText: meta?.sourceText,
      edited: true,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sOf(context).lyricsPreviewSaved)));
    final t = trackId;
    setState(() => _loadedFor = null);
    unawaited(_load(t));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    final hasTrack = _loadedFor != null;
    return Scaffold(
      key: const ValueKey('lyrics_page'),
      appBar: AppBar(
        title: Text(t.lyricsTitle),
        actions: [
          if (hasTrack && widget.hub != null)
            IconButton(
              key: const ValueKey('lyrics_gen'),
              tooltip: t.lyricsGen,
              onPressed: _busy ? null : () => unawaited(_generate()),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(IaIcon.autoFix, color: p.secondaryText),
            ),
          if (hasTrack)
            IconButton(
              key: const ValueKey('lyrics_paste'),
              tooltip: t.lyricsPaste,
              onPressed: () => unawaited(_pasteLyrics()),
              icon: Icon(IaIcon.edit, color: p.secondaryText),
            ),
          if (hasTrack)
            IconButton(
              key: const ValueKey('lyrics_offset'),
              tooltip: t.lyricsOffset,
              onPressed: _openOffsetSheet,
              icon: Icon(IaIcon.equalizer, color: p.secondaryText),
            ),
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
                          const SizedBox(height: 20),
                          // 两个出路（PRD 冷启动：生成 / 粘贴）
                          if (widget.hub != null)
                            FilledButton.icon(
                              key: const ValueKey('lyrics_gen_cta'),
                              onPressed:
                                  _busy ? null : () => unawaited(_generate()),
                              icon: Icon(IaIcon.autoFix),
                              label: Text(t.lyricsGen),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            key: const ValueKey('lyrics_paste_cta'),
                            onPressed: () => unawaited(_pasteLyrics()),
                            icon: Icon(IaIcon.edit),
                            label: Text(t.lyricsPaste),
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
                final staticMode =
                    _lines.first.ms < 0; // 纯文本粘贴=无时间轴静态展示
                return ListView.builder(
                  key: const ValueKey('lyrics_list'),
                  controller: _scroll,
                  itemExtent: _lineExtent,
                  padding: const EdgeInsets.symmetric(vertical: 120),
                  itemCount: _lines.length,
                  itemBuilder: (context, i) {
                    final line = _lines[i];
                    final active = !staticMode && i == idx;
                    final passed = !staticMode && i < idx;
                    return InkWell(
                      key: ValueKey('lyrics_line_$i'),
                      onTap: staticMode || line.ms < 0
                          ? null
                          : () => unawaited(widget.service
                              .seekTo(_shiftedMs(line).clamp(0, 1 << 31))),
                      child: Center(
                        child: Text(
                          line.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _fontSize,
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
