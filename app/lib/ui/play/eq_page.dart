/// 音效页（WS1/REQ-PLAY-07：EQ 直桥真实现——预设 + 5 段 ±12dB，
/// 拖动实时生效并持久化；引擎不支持端回落「明示不支持」面板）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// 预设增益（dB，5 段 60/230/910/3.6k/14k）。
const List<double> _kPresetDefault = [0, 0, 0, 0, 0];
const List<double> _kPresetPop = [2, 0, -1, 2, 1];
const List<double> _kPresetRock = [4, 2, -1, 2, 4];
const List<double> _kPresetClassical = [3, 1, 0, 2, 3];
const List<double> _kPresetJazz = [2, 1, -1, 2, 2];
const List<double> _kPresetBass = [6, 4, 1, 0, 0];

/// 频段轴标（PRD §3.2 口径：60Hz/230Hz/910Hz/3.6kHz/14kHz）。
const List<String> _kBandLabels = ['60', '230', '910', '3.6k', '14k'];

final class EqPage extends StatefulWidget {
  const EqPage({super.key, required this.service});

  final PlaybackService service;

  @override
  State<EqPage> createState() => _EqPageState();
}

final class _EqPageState extends State<EqPage> {
  late List<double> _gains = List.of(widget.service.eqGains);
  bool? _supported = true; // null=未知（初始应用中）；false=明示不支持

  @override
  void initState() {
    super.initState();
    // 回显持久化增益（同值重放一次即可验证引擎是否支持；失败→明示面板）
    unawaited(() async {
      final ok = await widget.service.setEqBands(_gains);
      if (mounted) {
        setState(() => _supported = ok);
      }
    }());
  }

  Future<void> _apply(List<double> gains) async {
    final ok = await widget.service.setEqBands(gains);
    if (!mounted) {
      return;
    }
    setState(() {
      _supported = ok;
      if (ok) {
        _gains = List.of(gains);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('eq_page'),
      appBar: AppBar(title: Text(t.eqTitle)),
      body: _supported == false ? _unsupported(p, t) : _editor(p, t),
    );
  }

  Widget _unsupported(IaPalette p, AppLocalizations t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(IaIcon.equalizer, size: 48, color: p.secondaryText),
              const SizedBox(height: 16),
              Text(t.eqUnsupportedTitle,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                t.eqUnsupportedBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: p.secondaryText, height: 1.6),
              ),
            ],
          ),
        ),
      );

  Widget _editor(IaPalette p, AppLocalizations t) {
    final presets = <(String, List<double>)>[
      (t.eqPresetDefault, _kPresetDefault),
      (t.eqPresetPop, _kPresetPop),
      (t.eqPresetRock, _kPresetRock),
      (t.eqPresetClassical, _kPresetClassical),
      (t.eqPresetJazz, _kPresetJazz),
      (t.eqPresetBass, _kPresetBass),
    ];
    final isCustom = !presets.any((e) => _sameGains(e.$2));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(t.eqBandsNote,
            style: TextStyle(fontSize: 12, color: p.secondaryText)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, gains) in presets)
              ChoiceChip(
                key: ValueKey('eq_preset_$label'),
                label: Text(label),
                selected: _sameGains(gains),
                onSelected: (_) => unawaited(_apply(gains)),
              ),
            if (isCustom)
              ChoiceChip(
                key: const ValueKey('eq_preset_custom'),
                label: Text(t.eqPresetCustom),
                selected: true,
                onSelected: null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _kBandLabels.length; i++) _bandRow(i, p, t),
      ],
    );
  }

  bool _sameGains(List<double> preset) {
    for (var i = 0; i < 5; i++) {
      if (preset[i].toStringAsFixed(1) != _gains[i].toStringAsFixed(1)) {
        return false;
      }
    }
    return true;
  }

  Widget _bandRow(int i, IaPalette p, AppLocalizations t) {
    final g = _gains[i];
    return Row(
      key: ValueKey('eq_band_$i'),
      children: [
        SizedBox(
          width: 44,
          child: Text(
            t.eqBandLabel(_kBandLabels[i]),
            style: TextStyle(
                fontSize: 12,
                color: p.secondaryText,
                fontFeatures: kIaNumericFeatures),
          ),
        ),
        Expanded(
          child: Slider(
            key: ValueKey('eq_slider_$i'),
            value: g.clamp(-12.0, 12.0),
            min: -12,
            max: 12,
            divisions: 24,
            label: '${g > 0 ? '+' : ''}${g.toStringAsFixed(1)} dB',
            onChanged: (v) => setState(() => _gains[i] = v),
            onChangeEnd: (v) =>
                unawaited(_apply(List.of(_gains)..[i] = v)),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '${g > 0 ? '+' : ''}${g.toStringAsFixed(1)}',
            textAlign: TextAlign.end,
            style: TextStyle(
                fontSize: 12,
                color: g == 0 ? p.secondaryText : p.accent,
                fontFeatures: kIaNumericFeatures),
          ),
        ),
      ],
    );
  }
}
