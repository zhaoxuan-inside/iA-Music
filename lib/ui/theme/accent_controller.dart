/// 动态取色控制器（D12-6）：当前播放封面主色 → 主题 seed（重写版）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/theme/cover_seed.dart';

final class AccentController extends ValueNotifier<Color?> {
  AccentController(this._covers) : super(null);

  final CoverChain _covers;
  final Map<int, Color?> _cache = {};
  StreamSubscription<int?>? _sub;
  PlaybackService? _bound;
  int? _extractingFor;

  /// 绑定播放域（换曲 → 提取 → scheme 通知；重绑安全）。
  void bind(PlaybackService service) {
    if (_bound == service) return;
    _bound = service;
    unawaited(_sub?.cancel());
    _sub = service.status
        .map((s) => s.currentTrack?.id)
        .distinct()
        .listen((id) => unawaited(_update(id)));
    unawaited(_update(service.snapshot.currentTrack?.id));
  }

  /// 解绑（回品牌绿基板）。
  void unbind() {
    unawaited(_sub?.cancel());
    _sub = null;
    _bound = null;
    if (value != null) value = null;
  }

  Future<void> _update(int? trackId) async {
    if (trackId == null) {
      if (value != null) value = null;
      return;
    }
    if (_cache.containsKey(trackId)) {
      value = _cache[trackId];
      return;
    }
    if (_extractingFor == trackId) return;
    _extractingFor = trackId;
    try {
      final res = await _covers.decide(trackId);
      Color? seed;
      if (res.bytes != null) {
        seed = await extractCoverSeedFromBytes(res.bytes!);
      } else if (res.localPath != null) {
        seed = await extractCoverSeedFromPath(res.localPath!);
      }
      if (_cache.length > 512) _cache.clear();
      _cache[trackId] = seed;
      if (_bound?.snapshot.currentTrack?.id == trackId) {
        value = seed; // 迟到结果只认当前曲
      }
    } finally {
      if (_extractingFor == trackId) _extractingFor = null;
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
    _bound = null;
    super.dispose();
  }
}
