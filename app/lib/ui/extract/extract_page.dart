/// 提取页（B 站 → 本地曲库 · DEC-012 重写）：
/// 合规声明门禁 → 链接/关键词解析卡 → 入队（歌词+字幕选项）→ 任务队列实时面。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:contracts/contracts.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/extract_queue.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class ExtractPage extends StatefulWidget {
  const ExtractPage({super.key, required this.hub, this.prefill});

  final LibraryHub hub;

  /// 预填输入（搜索页链接/BV 跳转缝）。
  final String? prefill;

  @override
  State<ExtractPage> createState() => ExtractPageState();
}

class ExtractPageState extends State<ExtractPage> {
  final TextEditingController _controller = TextEditingController();
  bool _compliant = false;
  List<ResolvedMeta> _parsed = const [];
  bool _parsing = false;
  String _parseError = '';
  bool _withLyrics = true;
  bool _withText = true;
  Map<int, ExtractTask> _tasks = {};
  final Map<int, String> _messages = {};
  StreamSubscription<ExtractQueueEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.prefill ?? '';
    unawaited(_init());
    _sub = widget.hub.extract.events.listen(_onEvent);
  }

  Future<void> _init() async {
    final ok = await widget.hub.extract.isComplianceAcknowledged();
    final tasks = await widget.hub.data.extract.recentTasks();
    if (!mounted) return;
    setState(() {
      _compliant = ok;
      _tasks = {for (final t in tasks) t.id: t};
    });
    if (_controller.text.isNotEmpty) {
      await _parse();
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _controller.dispose();
    super.dispose();
  }

  void _onEvent(ExtractQueueEvent e) {
    if (e is ExtractStateChanged) {
      if (!mounted) return;
      setState(() {
        final existing = _tasks[e.taskId];
        if (existing != null) {
          _tasks[e.taskId] = existing.copyWith(status: e.status);
        }
        _messages[e.taskId] = e.message ?? '';
      });
    }
  }

  Future<void> _ack() async {
    await widget.hub.extract
        .acknowledgeCompliance(at: DateTime.now());
    if (mounted) setState(() => _compliant = true);
  }

  Future<void> _parse() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _parsing = true;
      _parseError = '';
      _parsed = const [];
    });
    try {
      final metas = await widget.hub.extract.parseLinkText(text);
      if (mounted) setState(() => _parsed = metas);
    } catch (e) {
      if (mounted) setState(() => _parseError = sOf(context).parseFailed('$e'));
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _enqueue(ResolvedMeta meta) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final (task, isNew) = await widget.hub.extract.enqueue(
      meta,
      quality: TaskQuality.k192,
      withLyrics: _withLyrics,
      withText: _withText,
      nowMs: now,
    );
    if (mounted) {
      setState(() => _tasks[task.id] = task);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNew
            ? sOf(context).taskEnqueued(meta.title)
            : sOf(context).taskExists),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('extract_page'),
      appBar: AppBar(title: Text(t.navExtract)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_compliant) ...[
            _ComplianceCard(p: p, onAck: () => unawaited(_ack())),
          ] else ...[
            Text(
              t.extractTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.05,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.extractIntro,
              style: TextStyle(fontSize: 12, color: p.secondaryText),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('extract_input'),
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    onSubmitted: (_) => unawaited(_parse()),
                    decoration: InputDecoration(
                      hintText: t.extractInputHint,
                      prefixIcon:
                          Icon(IaIcon.link, size: 20, color: p.secondaryText),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('extract_parse'),
                  tooltip: t.parseAction,
                  onPressed: _parsing ? null : () => unawaited(_parse()),
                  icon: Icon(IaIcon.extract),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilterChip(
                  key: const ValueKey('extract_opt_lyrics'),
                  label: Text(t.optOnlineLyrics),
                  selected: _withLyrics,
                  onSelected: (v) => setState(() => _withLyrics = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  key: const ValueKey('extract_opt_text'),
                  label: Text(t.optBiliSubtitle),
                  selected: _withText,
                  onSelected: (v) => setState(() => _withText = v),
                ),
              ],
            ),
            if (_parseError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_parseError,
                    style: TextStyle(fontSize: 13, color: p.error)),
              ),
            if (_parsed.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < _parsed.length; i++)
                _metaCard(p, _parsed[i], i),
            ],
            const SizedBox(height: 24),
            Text(
              t.taskQueueTitle,
              key: const ValueKey('extract_queue_title'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_tasks.isEmpty)
              Padding(
                key: const ValueKey('extract_queue_empty'),
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  t.taskQueueEmpty,
                  style: TextStyle(fontSize: 13, color: p.secondaryText),
                ),
              )
            else
              for (final task in _tasks.values.toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
                _taskRow(p, task),
          ],
        ],
      ),
    );
  }

  Widget _metaCard(dynamic p, ResolvedMeta m, int i) {
    return Card(
      key: ValueKey('extract_meta_$i'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title.isEmpty ? sOf(context).untitled : m.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${m.uploader} · ${iaMmss(m.durationMs)}',
                    style: TextStyle(fontSize: 12, color: p.secondaryText),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              key: ValueKey('extract_enqueue_$i'),
              onPressed: () => unawaited(_enqueue(m)),
              child: Text(sOf(context).extractAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskRow(dynamic p, ExtractTask task) {
    final t = sOf(context);
    final statusText = switch (task.status) {
      ExtractTaskStatus.resolved => t.statusResolved,
      ExtractTaskStatus.gating => t.statusGating,
      ExtractTaskStatus.gated => t.statusGated,
      _ => task.status.name,
    };
    final lastMsg = _messages[task.id] ?? '';
    return Padding(
      key: ValueKey('extract_task_${task.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title ?? task.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: task.status == ExtractTaskStatus.gated
                      ? p.error
                      : p.secondaryText,
                ),
              ),
            ],
          ),
          if (lastMsg.isNotEmpty)
            Text(
              lastMsg,
              key: ValueKey('extract_task_msg_${task.id}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: p.secondaryText),
            ),
        ],
      ),
    );
  }
}

final class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard({required this.p, required this.onAck});

  final dynamic p;
  final VoidCallback onAck;

  @override
  Widget build(BuildContext context) {
    final t = sOf(context);
    return Card(
      key: const ValueKey('extract_compliance'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(IaIcon.shield, size: 22, color: p.accent),
                const SizedBox(width: 10),
                Text(t.complianceTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              t.complianceBody,
              style: TextStyle(
                  fontSize: 13, color: p.secondaryText, height: 1.8),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('extract_ack'),
              onPressed: onAck,
              icon: Icon(IaIcon.check),
              label: Text(t.complianceAck),
            ),
          ],
        ),
      ),
    );
  }
}
