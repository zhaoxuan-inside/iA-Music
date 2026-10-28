/// 提取页 P-EXTRACT（S6 · REQ-EXT-01..08/ONB-03）：
/// * 合规门禁：未确认声明 → 声明卡拦截（下载前置门禁位）。
/// * 解析卡：标题/UP 主/时长/音质选择（REQ-EXT-01）。
/// * 队列：串行任务列表（进度/失败清单/重复/done），完成后 Toast。
/// * 空态：「在 B 站点分享→复制链接，粘贴到这里」引导。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/extract_queue.dart';

final class ExtractPage extends StatefulWidget {
  const ExtractPage({super.key, required this.data, required this.queue});

  final DataAccess data;
  final ExtractQueue queue;

  @override
  State<ExtractPage> createState() => _ExtractPageState();
}

class _ExtractPageState extends State<ExtractPage> {
  final _linkController = TextEditingController();
  bool? _complianceAcked;
  List<ExtractTask>? _tasks;

  /// 解析中的链接→卡数据（REQ-EXT-01 展示）。
  List<ResolvedMeta>? _resolved;
  String? _resolveError;
  bool _resolving = false;

  StreamSubscription<ExtractQueueEvent>? _queueSub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _queueSub = widget.queue.events.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final acked = await widget.queue.isComplianceAcknowledged();
    final rows = await (widget.data.db.select(widget.data.db.extractTasks)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
    if (mounted) {
      setState(() {
        _complianceAcked = acked;
        _tasks = rows;
      });
    }
  }

  Future<void> _acknowledgeCompliance() async {
    await widget.queue
        .acknowledgeCompliance(at: DateTime.now());
    await _refresh();
  }

  Future<void> _resolve() async {
    setState(() {
      _resolving = true;
      _resolveError = null;
      _resolved = null;
    });
    try {
      final metas = await widget.queue.parseLinkText(_linkController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _resolved = metas;
        _resolving = false;
      });
    } on ContractException catch (e) {
      if (mounted) {
        setState(() {
          _resolving = false;
          _resolveError = e.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _resolving = false;
          _resolveError = '链接解析失败：链接可能已失效，或该内容需要登录';
        });
      }
    }
  }

  /// 入队（默认=最高可用；勾选歌词联动 EXT-08）。
  bool _withLyrics = false;

  Future<void> _submit(ResolvedMeta meta) async {
    final quality = meta.qualities.first;
    try {
      await widget.queue.enqueue(meta,
          quality: _qualityOf(quality),
          withLyrics: _withLyrics,
          nowMs: DateTime.now().millisecondsSinceEpoch);
      await _refresh();
    } catch (_) {
      // 门禁（理论不可达：未区域已拦截）
      await _complianceGate();
    }
  }

  TaskQuality _qualityOf(Quality q) {
    switch (q) {
      case Quality.k64:
        return TaskQuality.k64;
      case Quality.k128:
        return TaskQuality.k128;
      case Quality.k192:
        return TaskQuality.k192;
      case Quality.hires:
        return TaskQuality.hires;
    }
  }

  Future<void> _complianceGate() async {
    setState(() => _complianceAcked = false);
  }

  @override
  Widget build(BuildContext context) {
    final acked = _complianceAcked;
    return Scaffold(
      key: const ValueKey('extract_page'),
      appBar: AppBar(
        key: const ValueKey('extract_back'),
        title: const Text('提取'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.maybePop(context)),
      ),
      body: acked == null
          ? const Center(child: CircularProgressIndicator())
          : !acked
              ? _complianceCard()
              : _mainBody(),
    );
  }

  Widget _complianceCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_outlined, size: 40),
            const SizedBox(height: 12),
            const Text('使用声明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              '提取功能仅用于个人备份自己有权合法访问的内容；使用即表示你了解并遵守内容平台的'
              '服务条款与版权要求。请勿提取你不拥有或无权访问的受保护内容。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('compliance_confirm'),
              onPressed: _acknowledgeCompliance,
              child: const Text('我已了解并确认'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('extract_input'),
                controller: _linkController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '粘贴 B 站分享链接',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('extract_resolve_btn'),
              onPressed: _resolving ? null : _resolve,
              child: _resolving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('解析链接'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_resolveError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _resolveError!,
              key: const ValueKey('resolve_error'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ...?_resolved?.map(_resolveCard),
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const ValueKey('extract_with_lyrics'),
          value: _withLyrics,
          onChanged: (v) => setState(() => _withLyrics = v ?? false),
          title: const Text('提取完成后同时生成歌词'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 12),
        const Text('任务队列', style: TextStyle(fontWeight: FontWeight.bold)),
        ...?_tasks?.map(_taskTile),
      ],
    );
  }

  Widget _resolveCard(ResolvedMeta m) {
    final dur = Duration(milliseconds: m.durationMs);
    return Card(
      key: ValueKey('resolve_card_${m.sourceId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(m.uploader),
            Text('${dur.inMinutes}分${dur.inSeconds % 60}秒'),
            const SizedBox(height: 6),
            Text('可选音质：${m.qualities.map(_qualityName).join(' / ')}（默认最高）'),
            const SizedBox(height: 10),
            FilledButton(
              key: ValueKey('extract_submit_${m.sourceId}'),
              onPressed: () => unawaited(_submit(m)),
              child: const Text('开始提取'),
            ),
          ],
        ),
      ),
    );
  }

  String _qualityName(Quality q) {
    switch (q) {
      case Quality.k64:
        return '64k';
      case Quality.k128:
        return '128k';
      case Quality.k192:
        return '192k';
      case Quality.hires:
        return 'hires';
    }
  }

  Widget _taskTile(ExtractTask t) {
    final icon = switch (t.status) {
      ExtractTaskStatus.resolved => Icons.schedule,
      ExtractTaskStatus.downloading || ExtractTaskStatus.transcoding =>
        Icons.downloading,
      ExtractTaskStatus.paused => Icons.pause_circle_outline,
      ExtractTaskStatus.registered => Icons.check_circle,
      ExtractTaskStatus.failed || ExtractTaskStatus.dup => Icons.error_outline,
      ExtractTaskStatus.gating || ExtractTaskStatus.gated => Icons.lock_outline,
    };
    return Card(
      key: ValueKey('extract_task_${t.id}'),
      child: ListTile(
        leading: Icon(icon,
            color: t.status == ExtractTaskStatus.registered
                ? Colors.green
                : t.status == ExtractTaskStatus.failed || t.status == ExtractTaskStatus.dup
                    ? Colors.red
                    : null),
        title: Text(
          t.title ?? t.url,
          key: ValueKey('extract_task_${t.id}_title'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.status.name}${t.progressPct > 0 && t.status == ExtractTaskStatus.downloading ? '${t.progressPct.toStringAsFixed(1)}%' : ''}'),
            if (t.progressPct > 0 && t.status == ExtractTaskStatus.downloading)
              LinearProgressIndicator(value: t.progressPct / 100),
            if (t.status == ExtractTaskStatus.dup)
              const Text('这首歌已在曲库中（匹配来源链接）'),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (t.status == ExtractTaskStatus.failed || t.status == ExtractTaskStatus.dup)
            IconButton(
              key: ValueKey('extract_retry_${t.id}'),
              icon: const Icon(Icons.refresh),
              onPressed: () => unawaited(widget.queue.reEnqueue(t.id).then((_) => _refresh())),
            ),
          if (t.status == ExtractTaskStatus.downloading || t.status == ExtractTaskStatus.paused)
            IconButton(
              key: ValueKey('extract_cancel_${t.id}'),
              icon: const Icon(Icons.close),
              onPressed: () => unawaited(widget.queue.cancelTask(t.id).then((_) => _refresh())),
            ),
        ]),
      ),
    );
  }
}
