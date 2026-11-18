/// Quickplay：Zune 软件首页的磁贴墙。
///
/// 大磁贴 + 小磁贴交错；点按立即播放，长按固定/解除固定。
/// 没有固定项时自动展示最近入库专辑，让这一屏永远有内容可看。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/quickplay.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/media_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/playlist_providers.dart';
import '../../state/quickplay_providers.dart';
import '../detail/detail_page.dart';
import '../settings/subpages.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';
import '../shared/wp_motion.dart';

class QuickplayPage extends ConsumerWidget {
  const QuickplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qp = ref.watch(quickplayProvider);
    final recent =
        ref.watch(recentAddedAlbumsProvider).value ?? const <AlbumGroup>[];
    final recommendations = [
      for (final a in recent.take(6))
        QuickplayPin(
          kind: QuickplayKind.album,
          key: albumKey(a.album),
          title: a.album,
          subtitle: a.artist,
        ),
    ];
    final tiles = qp.pins.isNotEmpty ? qp.pins : recommendations;

    return HubPage(
      header: PageHeader(
        kicker: '钉在墙上的',
        title: '快速播放',
        subtitle: qp.pins.isNotEmpty
            ? '${qp.pins.length} 个固定项 · 点按播放 · 长按磁贴解除'
            : recommendations.isNotEmpty
            ? '还没有固定项 · 先看看最近添加 · 长按可固定'
            : '把喜欢的专辑、艺人、歌单钉在这里',
        trailing: const SearchAction(),
      ),
      children: [
        if (tiles.isEmpty) const _QuickplayEmpty() else _Mosaic(pins: tiles),
        const SizedBox(height: IaSpacing.m),
        const Text(
          '点按播放 · 长按固定 / 解除固定',
          style: TextStyle(fontSize: 11, color: IaColors.textLow),
        ),
      ],
    );
  }
}

/* ── 磁贴墙 ───────────────────────────────────────────────────────── */

class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.pins});

  final List<QuickplayPin> pins;

  @override
  Widget build(BuildContext context) {
    const gap = IaSpacing.m;
    final rows = <Widget>[];
    var i = 0;
    while (i < pins.length) {
      if (i % 3 == 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: AspectRatio(
              aspectRatio: 2.02,
              child: FeatherIn(
                index: i,
                child: _PinTile(pin: pins[i], big: true),
              ),
            ),
          ),
        );
        i++;
      } else {
        final a = pins[i];
        final b = i + 1 < pins.length ? pins[i + 1] : null;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.94,
                    child: FeatherIn(
                      index: i,
                      child: _PinTile(pin: a, big: false),
                    ),
                  ),
                ),
                if (b != null) ...[
                  const SizedBox(width: gap),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.94,
                      child: FeatherIn(
                        index: i + 1,
                        child: _PinTile(pin: b, big: false),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
        i += b == null ? 1 : 2;
      }
    }
    return Column(children: rows);
  }
}

class _PinTile extends ConsumerWidget {
  const _PinTile({required this.pin, required this.big});

  final QuickplayPin pin;
  final bool big;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final qp = ref.watch(quickplayProvider);
    final pinned = qp.isPinned(pin.kind, pin.key);

    return Material(
      key: ValueKey('qp-${pin.id}'),
      color: Colors.transparent,
      child: TiltOnPress(
        child: InkWell(
          onTap: () => _play(context, ref),
          onLongPress: () => _menu(context, ref, pinned),
          // WP8 Live Tile：磁贴周期性绕纵轴翻面（相位按种子错开，永不同步）。
          child: HubTileFlip(
            phaseSeed: pin.title.hashCode ^ pin.kind.index,
            front: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (pinned)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(height: 2, color: p.accent),
                    ),
                  _PinFace(pin: pin, big: big),
                ],
              ),
            ),
            back: _PinBack(pin: pin, big: big, pinned: pinned),
          ),
        ),
      ),
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final tracks = switch (pin.kind) {
      QuickplayKind.album => await ref.read(
        albumTracksProvider(pin.key).future,
      ),
      QuickplayKind.artist => await ref.read(
        artistTracksProvider(pin.key).future,
      ),
      QuickplayKind.playlist => await ref.read(
        playlistTracksProvider(int.tryParse(pin.key) ?? 0).future,
      ),
    };
    if (!context.mounted) {
      return;
    }
    if (tracks.isEmpty) {
      showWpToast(context, title: '快速播放', message: '这一项还没有可播放的曲目');
      return;
    }
    await ref.read(playbackProvider.notifier).playTracks(tracks);
  }

  void _menu(BuildContext context, WidgetRef ref, bool pinned) {
    showWpMenu(
      context,
      title: pin.title,
      items: [
        (
          pinned ? '解除固定' : '固定到快速播放',
          () async {
            await ref.read(quickplayProvider.notifier).toggle(pin);
          },
        ),
        ('打开详情', () => _openDetail(context)),
        ('立即播放', () => _play(context, ref)),
      ],
    );
  }

  void _openDetail(BuildContext context) {
    final type = switch (pin.kind) {
      QuickplayKind.album => DetailType.album,
      QuickplayKind.artist => DetailType.artist,
      QuickplayKind.playlist => DetailType.playlist,
    };
    Navigator.of(context).push(
      zuneRoute<void>(
        builder: (_) => DetailPage(type: type, id: pin.key),
      ),
    );
  }

  static String _kindLabel(QuickplayKind kind) => switch (kind) {
    QuickplayKind.album => '专辑',
    QuickplayKind.artist => '艺人',
    QuickplayKind.playlist => '歌单',
  };
}

/// 磁贴正面：封面 + 压暗渐变 + 分类 kicker + 标题。
class _PinFace extends ConsumerWidget {
  const _PinFace({required this.pin, required this.big});

  final QuickplayPin pin;
  final bool big;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final qp = ref.watch(quickplayProvider);
    final pinned = qp.isPinned(pin.kind, pin.key);
    final file = _coverFile(ref);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (file != null)
          Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 560,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _Fallback(pin: pin),
          )
        else
          _Fallback(pin: pin),
        // 底部压暗，保证标题永远读得清。
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.42, 1],
              colors: [Color(0x14000000), Color(0x66000000), Color(0xE6000000)],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(big ? IaSpacing.l : IaSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _PinTile._kindLabel(pin.kind).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: IaType.semibold,
                      letterSpacing: 1.6,
                      color: p.accent,
                    ),
                  ),
                  const Spacer(),
                  if (pinned) Icon(Icons.push_pin, size: 15, color: p.accent),
                ],
              ),
              const Spacer(),
              Text(
                pin.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: big ? 28 : 18,
                  height: 1.1,
                  fontWeight: IaType.light,
                  letterSpacing: IaType.titleTracking,
                  color: IaColors.textHi,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                pin.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: big ? 11.5 : 10.5,
                  color: IaColors.textMid,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  File? _coverFile(WidgetRef ref) {
    Track? track;
    switch (pin.kind) {
      case QuickplayKind.album:
        track = ref.watch(albumTracksProvider(pin.key)).value?.firstOrNull;
        break;
      case QuickplayKind.artist:
        track = ref.watch(artistTracksProvider(pin.key)).value?.firstOrNull;
        break;
      case QuickplayKind.playlist:
        track = ref
            .watch(playlistTracksProvider(int.tryParse(pin.key) ?? 0))
            .value
            ?.firstOrNull;
        break;
    }
    if (track == null) {
      return null;
    }
    final file = ref.watch(coverProvider((track.id, track.coverPath))).value;
    return file != null && file.existsSync() ? file : null;
  }
}

/// 磁贴背面（WP8 Flip 模板信息面）：黑底 + 首字水印 + 操作提示。
class _PinBack extends StatelessWidget {
  const _PinBack({required this.pin, required this.big, required this.pinned});

  final QuickplayPin pin;
  final bool big;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return Container(
      color: IaColors.canvas,
      foregroundDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: IaColors.hairlineStrong)),
      ),
      padding: EdgeInsets.all(big ? IaSpacing.l : IaSpacing.m),
      child: Stack(
        children: [
          Positioned(
            right: -2,
            top: -14,
            child: Text(
              pin.title.isEmpty ? '♪' : pin.title[0],
              style: TextStyle(
                fontSize: big ? 96 : 64,
                height: 1,
                fontWeight: IaType.light,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _PinTile._kindLabel(pin.kind).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: IaType.semibold,
                      letterSpacing: 1.6,
                      color: p.accent,
                    ),
                  ),
                  const Spacer(),
                  if (pinned) Icon(Icons.push_pin, size: 15, color: p.accent),
                ],
              ),
              const Spacer(),
              Text(
                pin.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: big ? 22 : 15,
                  height: 1.15,
                  fontWeight: IaType.light,
                  letterSpacing: IaType.titleTracking,
                  color: IaColors.textHi,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '点按播放 · 长按固定 / 解除',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: big ? 11.5 : 10,
                  color: IaColors.textMid,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.pin});

  final QuickplayPin pin;

  @override
  Widget build(BuildContext context) {
    final h = (pin.title.hashCode.abs() * 47) % 360;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, h.toDouble(), 0.42, 0.30).toColor(),
            HSLColor.fromAHSL(
              1,
              ((h + 40) % 360).toDouble(),
              0.55,
              0.10,
            ).toColor(),
          ],
        ),
      ),
      child: Center(
        child: Text(
          pin.title.isEmpty ? '♪' : pin.title[0],
          style: TextStyle(
            fontSize: 64,
            fontWeight: IaType.light,
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

class _QuickplayEmpty extends StatelessWidget {
  const _QuickplayEmpty();

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return AspectRatio(
      aspectRatio: 1.58,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(zuneRoute<void>(builder: (_) => const CollectSubPage())),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                p.accent.withValues(alpha: 0.55),
                const Color(0xFF160A12),
                IaColors.canvas,
              ],
            ),
            border: Border(left: BorderSide(color: p.accent, width: 3)),
          ),
          padding: const EdgeInsets.all(IaSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把喜欢的\n钉在这里',
                style: TextStyle(
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: IaType.light,
                  letterSpacing: IaType.titleTracking,
                  color: IaColors.textHi,
                ),
              ),
              const SizedBox(height: IaSpacing.s),
              const Text(
                '去收集音乐 ›',
                style: TextStyle(fontSize: 12, color: IaColors.textMid),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
