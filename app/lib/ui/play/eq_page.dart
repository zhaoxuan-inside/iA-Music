/// 音效页（S3 结论：mpv_audio_kit 单 Player 不暴露 EQ 波段——明示不支持）。
library;

import 'package:flutter/material.dart';

import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class EqPage extends StatelessWidget {
  const EqPage({super.key, required this.service});

  final PlaybackService service;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('eq_page'),
      appBar: AppBar(title: Text(t.eqTitle)),
      body: Center(
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
      ),
    );
  }
}
