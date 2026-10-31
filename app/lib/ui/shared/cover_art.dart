/// 封面组件（CoverChain 决议：内嵌 → 同名图 → fetched 缓存 → 在线链；
/// 缺失=首字母色块）。重写版（DEC-012 D12-2）。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ia_music/adapters/cover_fetch_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class CoverArt extends StatefulWidget {
  const CoverArt({
    super.key,
    required this.trackId,
    required this.title,
    required this.data,
    this.chain,
    this.size = 48,
    this.radius,
  });

  final int trackId;
  final String title;
  final DataAccess data;
  final CoverChain? chain;
  final double size;

  /// 圆角（默认按尺寸：大图 16 / 缩略 8）。
  final double? radius;

  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt> {
  CoverFetchAdapter? _owned;
  late CoverChain _chain;
  late Future<CoverResolution> _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  void _resolve() {
    _owned?.close();
    _owned = widget.chain == null ? CoverFetchAdapter() : null;
    _chain = widget.chain ?? CoverChain(widget.data, _owned!);
    _future = _chain.decide(widget.trackId);
  }

  @override
  void didUpdateWidget(CoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId ||
        oldWidget.chain != widget.chain ||
        oldWidget.data.db != widget.data.db) {
      _resolve();
    }
  }

  @override
  void dispose() {
    _owned?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim();
    final p = context.ia;
    final placeholder = ColoredBox(
      key: ValueKey('cover_placeholder_${widget.trackId}'),
      color: p.lifted,
      child: Center(
        child: Text(
          title.isEmpty ? '♪' : title.characters.first,
          style: TextStyle(
            color: p.secondaryText,
            fontSize: widget.size < 80 ? 20 : 56,
          ),
        ),
      ),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        widget.size.isFinite ? (widget.size * dpr).round() : null;
    final radius = widget.radius ??
        (widget.size >= 120 ? IaRadius.cover : IaRadius.coverSm);
    return Semantics(
      label: '${widget.title} ${sOf(context).coverSuffix}',
      image: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: FutureBuilder<CoverResolution>(
            future: _future,
            builder: (context, snap) {
              final result = snap.data;
              if (result?.bytes != null) {
                return Image.memory(
                  result!.bytes!,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  key: ValueKey('cover_image_${widget.trackId}'),
                  errorBuilder: (_, _, _) => placeholder,
                );
              }
              if (result?.localPath != null) {
                return Image.file(
                  File(result!.localPath!),
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  key: ValueKey('cover_image_${widget.trackId}'),
                  errorBuilder: (_, _, _) => placeholder,
                );
              }
              return placeholder;
            },
          ),
        ),
      ),
    );
  }
}
