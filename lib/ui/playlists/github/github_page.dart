/// 拉取歌单页：URL 输入 → 拉取 → 预览 → 导入 → 队列。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../services/github/github_playlist_service.dart';
import '../../../state/collect_providers.dart';
import '../../../state/diagnostics.dart';
import '../../../state/providers.dart';
import '../../shared/ui_kit.dart';

class GithubPage extends ConsumerStatefulWidget {
  const GithubPage({super.key});

  @override
  ConsumerState<GithubPage> createState() => _GithubPageState();
}

class _GithubPageState extends ConsumerState<GithubPage> {
  final _urlCtrl = TextEditingController(); // 无预填——URL 由用户粘贴
  bool _fetching = false;
  String? _error;
  ({String name, List<GithubTrack> tracks})? _result;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: IaSpacing.m),
            Text('拉取歌单',
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            const SizedBox(height: IaSpacing.m),
            const Text('粘贴歌单清单 URL，拉取现成歌单：每首含 来源 / 搜索词 / 来源地址 / 歌手 / 歌名 / 歌词',
                style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.l),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    style: const TextStyle(
                        fontSize: 13,
                        color: IaColors.textHi,
                        fontWeight: IaType.regular),
                    decoration: const InputDecoration(
                      hintText: '歌单清单 URL…',
                    ),
                  ),
                ),
                const SizedBox(width: IaSpacing.m),
                TextButton(
                  onPressed: _fetching ? null : _fetch,
                  child: Text(_fetching ? '拉取中…' : '拉取',
                      style: TextStyle(
                          fontSize: 13, color: p.accent)),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: IaSpacing.m),
              Text(_error!,
                  style:
                      const TextStyle(fontSize: 12.5, color: IaColors.error)),
            ],
            if (_result != null) ...[
              const SizedBox(height: IaSpacing.xl),
              Text(_result!.name,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: IaType.light,
                      color: IaColors.textHi)),
              const SizedBox(height: IaSpacing.m),
              for (final t in _result!.tracks)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: IaSpacing.m, vertical: IaSpacing.m),
                  decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: IaColors.hairline))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t.title} · ${t.artist}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: IaType.list,
                                    color: IaColors.textHi)),
                            Text('${t.source} · ${t.url}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: IaColors.textLow)),
                          ],
                        ),
                      ),
                      Text(t.lyrics.isNotEmpty ? '歌词 ✓' : '歌词 —',
                          style: const TextStyle(
                              fontSize: 11, color: IaColors.textLow)),
                    ],
                  ),
                ),
              const SizedBox(height: IaSpacing.l),
              Text('${_result!.tracks.length} 首 · 直链音频直接下载，平台页面进入提取队列',
                  style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
              const SizedBox(height: IaSpacing.l),
              TextButton(
                onPressed: _importing ? null : _import,
                child: Text(_importing ? '导入中…' : '确认导入',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: IaType.light,
                        color: p.accent)),
              ),
            ],
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('清单格式'),
            const SizedBox(height: IaSpacing.m),
            Container(
              padding: const EdgeInsets.all(IaSpacing.l),
              decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: IaColors.hairlineStrong))),
              child: const Text(
                '{\n'
                '  "name": "歌单名",\n'
                '  "tracks": [ {\n'
                '    "source": "来源标识",      // 由 URL 路由到音频源插件\n'
                '    "query": "搜索词",\n'
                '    "url": "歌曲来源地址",\n'
                '    "artist": "歌手",\n'
                '    "title": "歌名",\n'
                '    "lyrics": "[00:01.00]… 歌词(LRC/纯文本)"\n'
                '  } ]\n'
                '}',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    color: IaColors.textLow,
                    fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetch() async {
    setState(() {
      _fetching = true;
      _error = null;
      _result = null;
    });
    try {
      final url = Uri.parse(_urlCtrl.text.trim());
      final result = await ref.read(githubPlaylistServiceProvider).fetch(url);
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    } on Object catch (e, st) {
      // 失败进日志追踪（页面 _error 只是临时的，页面销毁即失）
      unawaited(ref
          .read(diagnosticsProvider.notifier)
          .record('GitHub 歌单', e, st));
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _fetching = false);
      }
    }
  }

  Future<void> _import() async {
    final result = _result;
    if (result == null) {
      return;
    }
    setState(() => _importing = true);
    try {
      final service = ref.read(githubPlaylistServiceProvider);
      final dirs = await ref.read(cacheDirsProvider.future);
      await service.import(
          name: result.name, tracks: result.tracks, cacheDir: dirs.lyrics);
      // 启动真实下载（直链音频）/任务状态流转
      await ref.read(collectRunnerProvider.future).then((runner) => runner.runOnce());
      if (!mounted) {
        return;
      }
      if (mounted) {
        showWpToast(context,
            title: '歌单',
            message: '已导入「${result.name}」· ${result.tracks.length} 首进入提取队列');
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } on Object catch (e, st) {
      // 失败进日志追踪（页面 _error 只是临时的，页面销毁即失）
      unawaited(ref
          .read(diagnosticsProvider.notifier)
          .record('GitHub 歌单', e, st));
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }
}
