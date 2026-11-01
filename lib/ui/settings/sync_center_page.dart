/// 同步中心（WS6/REQ-SYNC-01..08）：通道卡+表单（连接测试通过才可保存）
/// + 状态面板（上次同步/待同步计数/进度/失败摘要）+ 冲突副本入口 +
/// 墓碑说明（删除仅传播记录——PRD hard guardrail）。
library;

import 'dart:async';
import 'dart:convert';


import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/sync/sync_engine.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class SyncCenterPage extends StatefulWidget {
  const SyncCenterPage({super.key, required this.hub});

  final LibraryHub hub;

  @override
  State<SyncCenterPage> createState() => _SyncCenterPageState();
}

class _SyncCenterPageState extends State<SyncCenterPage> {
  SyncChannelData? _channel;
  LastSyncStateData? _lastSync;
  int _conflictCount = 0;
  SyncEngineState _engineState = SyncEngineState.idle;
  String? _stateReason;
  String? _currentFile;
  SyncSummary? _lastSummary;
  bool _busy = false;

  SyncChannelType _pickType = SyncChannelType.webdav;
  final _baseUrl = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _remoteDir = TextEditingController(text: 'iA-Music/');

  StreamSubscription<SyncEvent>? _sub;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    _sub = widget.hub.sync.engine?.events.listen(_onEvent);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _baseUrl.dispose();
    _username.dispose();
    _password.dispose();
    _remoteDir.dispose();
    super.dispose();
  }

  void _onEvent(SyncEvent e) {
    if (!mounted) return;
    switch (e) {
      case SyncStateChanged(:final state, :final reason):
        setState(() {
          _engineState = state;
          _stateReason = reason;
          if (state == SyncEngineState.idle) {
            _currentFile = null;
          }
        });
        if (state == SyncEngineState.idle) {
          unawaited(_reload());
        }
      case SyncProgressEvent(:final relPath, :final sentBytes, :final totalBytes):
        if (relPath.startsWith('FAILED:')) {
          return;
        }
        if (totalBytes > 0) {
          setState(() => _currentFile =
              '$relPath ${(sentBytes * 100 / totalBytes).toStringAsFixed(0)}%');
        }
    }
  }

  Future<void> _reload() async {
    final channel = await widget.hub.data.sync.currentChannel();
    final lastSync =
        channel == null ? null : await _data.sync.lastSyncFor(channel.id);
    final conflicts = await widget.hub.data.sync.listConflicts();
    if (!mounted) return;
    setState(() {
      _channel = channel;
      _lastSync = lastSync;
      _conflictCount = conflicts.length;
    });
  }

  DataAccess get _data => widget.hub.data;

  Future<void> _saveChannel() async {
    if (_busy) return;
    final credentials = _pickType == SyncChannelType.webdav
        ? _password.text
        : _password.text; // GitHub PAT / OAuth 凭据 JSON 同走密文位
    setState(() => _busy = true);
    try {
      final error = await widget.hub.sync.applyChannel(
        type: _pickType,
        baseUrl: _baseUrl.text.trim(),
        credentialsValue: credentials,
        username: _username.text.trim().isEmpty ? null : _username.text.trim(),
        remoteDir: _remoteDir.text.trim().isEmpty
            ? 'iA-Music/'
            : _remoteDir.text.trim(),
      );
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sOf(context).syncSaved)));
        unawaited(_reload());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final summary = await widget.hub.sync.syncNow();
      if (mounted && summary != null) {
        setState(() => _lastSummary = summary);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      unawaited(_reload());
    }
  }

  Future<void> _disconnect() async {
    await widget.hub.sync.detachChannel();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sOf(context).syncDisconnected)));
    }
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('sync_center_page'),
      appBar: AppBar(title: Text(t.syncCenterTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ① 通道卡列表（REQ-SYNC-01；OneDrive/GDrive=通道池注册位）
          for (final (type, label, note) in [
            (SyncChannelType.webdav, t.syncChannelWebdav, t.syncWebdavNote),
            (SyncChannelType.github, t.syncChannelGithub, t.syncGithubNote),
            (SyncChannelType.onedrive, t.syncChannelOnedrive, ''),
            (SyncChannelType.gdrive, t.syncChannelGdrive, ''),
          ])
            ListTile(
              key: ValueKey('sync_channel_${type.name}'),
              leading: Icon(
                _channel?.type == type ? IaIcon.checkCircle : IaIcon.link,
                color: _channel?.type == type ? p.accent : p.secondaryText,
              ),
              title: Text(label),
              subtitle: note.isEmpty ? null : Text(note, style: TextStyle(fontSize: 12, color: p.secondaryText)),
              selected: _channel?.type == type,
              onTap: () => setState(() => _pickType = type),
            ),
          const SizedBox(height: 8),
          // ② 表单（连接测试通过才可保存）
          _formCard(p, t),
          const SizedBox(height: 16),
          // ③ 状态面板（REQ-SYNC-07）
          _statusCard(p, t),
          const SizedBox(height: 16),
          // ④ 墓碑说明（PRD hard guardrail 文案面）
          Text(
            t.syncTombstoneNote,
            style: TextStyle(fontSize: 12, color: p.secondaryText, height: 1.6),
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('sync_conflicts_entry'),
            dense: true,
            leading: Icon(IaIcon.close, size: 18, color: p.secondaryText),
            title: Text(t.syncConflictCopies(_conflictCount)),
            onTap: _conflictCount == 0
                ? null
                : () => unawaited(_openConflicts()),
          ),
        ],
      ),
    );
  }

  Widget _formCard(IaPalette p, AppLocalizations t) {
    final isGithub = _pickType == SyncChannelType.github;
    final isOAuth = _pickType == SyncChannelType.onedrive ||
        _pickType == SyncChannelType.gdrive;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('sync_base_url'),
              controller: _baseUrl,
              decoration: InputDecoration(
                labelText: isGithub
                    ? t.syncServerAddress
                    : t.syncServerAddress,
                hintText: isGithub
                    ? 'https://github.com/{owner}/{repo}'
                    : 'https://dav.example.com/dav/',
              ),
            ),
            if (!isOAuth) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _username,
                decoration: InputDecoration(labelText: t.syncAccount),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('sync_credentials'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText:
                    isGithub ? t.syncToken : (isOAuth ? t.syncToken : t.syncPassword),
              ),
            ),
            if (!isOAuth) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _remoteDir,
                decoration: InputDecoration(labelText: t.syncRemoteDir),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_channel != null)
                  TextButton(
                    key: const ValueKey('sync_disconnect'),
                    onPressed: _busy ? null : () => unawaited(_disconnect()),
                    child: Text(t.syncDisconnect),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('sync_save'),
                  onPressed:
                      _busy || _baseUrl.text.trim().isEmpty || _password.text.isEmpty
                          ? null
                          : () => unawaited(_saveChannel()),
                  child: Text(t.syncSaveChannel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(IaPalette p, AppLocalizations t) {
    final lastText = _lastSync?.lastCompletedAt == null
        ? t.syncNever
        : t.syncLastSync(_fmtTime(_lastSync!.lastCompletedAt!));
    final stateText = switch (_engineState) {
      SyncEngineState.transferring => t.syncRunning,
      SyncEngineState.paused =>
        t.syncStatePaused(_stateReason ?? ''),
      SyncEngineState.needsReauth => t.syncNeedsReauth,
      SyncEngineState.suspendedDisk => t.syncSuspendedDisk,
      SyncEngineState.debounce => t.syncRunning,
      _ => _channel == null ? t.syncNoChannel : t.syncIdle,
    };
    final summaryJson = _lastSync?.summaryJson;
    final summary = _lastSummary ??
        (summaryJson == null
            ? null
            : () {
                try {
                  return SyncSummary.fromJson(
                      (jsonDecode(summaryJson) as Map).cast<String, dynamic>());
                } on FormatException {
                  return null;
                }
              }());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(IaIcon.refresh,
                    size: 20,
                    color: _engineState == SyncEngineState.transferring
                        ? p.accent
                        : p.secondaryText),
                const SizedBox(width: 10),
                Expanded(child: Text(stateText)),
              ],
            ),
            const SizedBox(height: 8),
            Text(lastText,
                style: TextStyle(
                    fontSize: 12,
                    color: p.secondaryText,
                    fontFeatures: kIaNumericFeatures)),
            if (summary != null) ...[
              const SizedBox(height: 4),
              Text(
                t.syncSummary(summary.uploaded, summary.downloaded, summary.failed),
                style: TextStyle(
                    fontSize: 12,
                    color: p.secondaryText,
                    fontFeatures: kIaNumericFeatures),
              ),
            ],
            if (_currentFile != null) ...[
              const SizedBox(height: 4),
              Text(t.syncCurrentFile(_currentFile!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.accent)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  key: const ValueKey('sync_now'),
                  onPressed: _busy || _channel == null
                      ? null
                      : () => unawaited(_syncNow()),
                  icon: Icon(IaIcon.refresh),
                  label: Text(t.syncNow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd $hh:$mi';
  }

  Future<void> _openConflicts() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ConflictCopiesPage(hub: widget.hub),
    ));
    unawaited(_reload());
  }
}

/// dart:convert 兼容入口（避免直接 import 冲突——本文件已 import convert）。

/// 冲突副本页（REQ-SYNC-04：查看/删除副本）。
final class ConflictCopiesPage extends StatefulWidget {
  const ConflictCopiesPage({super.key, required this.hub});

  final LibraryHub hub;

  @override
  State<ConflictCopiesPage> createState() => _ConflictCopiesPageState();
}

class _ConflictCopiesPageState extends State<ConflictCopiesPage> {
  List<ConflictCopy> _rows = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final rows = await widget.hub.data.sync.listConflicts();
    if (mounted) {
      setState(() {
        _rows = rows;
        _loaded = true;
      });
    }
  }

  Future<void> _delete(ConflictCopy c) async {
    await widget.hub.data.sync.softDeleteConflict(
      c.id,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sOf(context).conflictDeleted)));
    }
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('conflict_copies_page'),
      appBar: AppBar(title: Text(t.conflictCopiesTitle)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text(t.syncNever,
                      style:
                          TextStyle(fontSize: 13, color: p.secondaryText)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final c in _rows)
                      Card(
                        key: ValueKey('conflict_${c.id}'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${c.originKind} #${c.originLocalId}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text('${t.conflictWinner}: ${c.winnerValueJson}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, color: p.secondaryText)),
                              Text('${t.conflictLoser}: ${c.loserPayloadJson}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, color: p.secondaryText)),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  key: ValueKey('conflict_delete_${c.id}'),
                                  onPressed: () => unawaited(_delete(c)),
                                  child: Text(t.conflictDelete),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
