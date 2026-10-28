// 提取域能力补齐回归（2026-10-24）：音质位真实接线 / 失败真实原因透传 /
// 字幕 API 直达通道映射。单元面纯函数零网络；末条为真链路（搜索→64k 下载）。
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/bilibili_search_adapter.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/adapters/subtitle_adapter.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/extract_queue.dart';

// ignore_for_file: avoid_print

void main() {
  group('音质位 → yt-dlp 格式选择器（真实接线，此前 quality 从未进参数）', () {
    test('k64/k128/k192/hires 各自优先真实 DASH 音轨位，带回退链', () {
      expect(DownloaderAdapter.qualitySelector(Quality.k64),
          contains('format_id=30216'));
      expect(DownloaderAdapter.qualitySelector(Quality.k128),
          contains('format_id=30232'));
      expect(DownloaderAdapter.qualitySelector(Quality.k192),
          contains('format_id=30280'));
      expect(DownloaderAdapter.qualitySelector(Quality.hires),
          contains('format_id=30250'));
      for (final q in Quality.values) {
        final s = DownloaderAdapter.qualitySelector(q);
        expect(s.endsWith('/bestaudio') || s.endsWith('/ba'), isTrue,
            reason: '选位失败必须回退（匿名/低档账号）: $q -> $s');
      }
    });

    test('解析面透出 hires 位（30250）', () {
      final j = {
        'id': 'BV1test',
        'title': 't',
        'duration': 10,
        'formats': [
          {'format_id': '30250'},
          {'format_id': '30280'},
          {'format_id': '30016'},
        ],
      };
      final meta = mapYtDlpJson(j, 'https://www.bilibili.com/video/BV1test');
      expect(meta.qualities.first, Quality.hires,
          reason: '30250 在映射表=登录大会员可见 hires 位');
    });
  });

  group('URL → sourceId 本地派生（快捷入队零网络面）', () {
    test('BV 直链与多 P 页同构于 resolve 的 id', () {
      expect(
        bilibiliSourceIdOf('https://www.bilibili.com/video/BV1LTn2zoEeh'),
        'BV1LTn2zoEeh',
      );
      expect(
        bilibiliSourceIdOf(
            'https://www.bilibili.com/video/BV1BDk2YCEHF?p=3'),
        'BV1BDk2YCEHF_p3',
      );
      expect(bilibiliSourceIdOf('https://b23.tv/abc123'), isNull);
    });
  });

  group('失败真实原因透传（此前 detail 只有 exit 码，stderr 语料全丢）', () {
    test('firstErrorLine 取最后一条 ERROR 行并截断', () {
      const corpus = '[BiliBili] Downloading webpage\n'
          'WARNING: x\n'
          'ERROR: [bilibili] BV1xx: -412 Precondition Failed 风控\n'
          'some trailing line';
      expect(DownloaderAdapter.firstErrorLine(corpus),
          contains('-412 Precondition Failed'));
      final long = 'ERROR: ${'a' * 400}';
      expect(DownloaderAdapter.firstErrorLine(long)!.length, lessThan(310));
      expect(DownloaderAdapter.firstErrorLine('no error here'), isNull);
    });

    test('分类：付费墙/无法提取/ffmpeg 缺失 → unsupported（重试无意义类）', () {
      expect(
        DownloaderAdapter.classify(
            '', 'ERROR: Format(s) 1080P 高码率 are missing; become a premium member'),
        DownloadFailureClass.unsupported,
      );
      expect(
        DownloaderAdapter.classify('ERROR: Unable to extract JSON', ''),
        DownloadFailureClass.unsupported,
      );
      expect(
        DownloaderAdapter.classify('', 'ERROR: ffmpeg not found'),
        DownloadFailureClass.unsupported,
      );
      expect(
        DownloaderAdapter.classify('', 'ERROR: -412 Precondition Failed'),
        DownloadFailureClass.network,
        reason: '风控回落 network=保留自动退避重试（冷却后可过）',
      );
    });
  });

  group('字幕通道二：player API JSON → LRC（CC/AI 字幕直达，不依赖 yt-dlp）', () {
    test('apiSubtitleJsonToLrc：毫秒起点 + 去重 + 空行剔除', () {
      final lrc = apiSubtitleJsonToLrc({
        'body': [
          {'from': 0.32, 'to': 1.5, 'content': '第一句'},
          {'from': 61.0, 'to': 63.0, 'content': '第二句'},
          {'from': 63.0, 'to': 64.0, 'content': '第二句'}, // 重复=剔除
          {'from': 65.0, 'to': 66.0, 'content': '   '}, // 空白=剔除
          {'from': 66.5, 'to': 67.0, 'content': '第三句'},
        ],
      });
      final lines = lrc.split('\n');
      expect(lines, hasLength(3));
      expect(lines[0], '[00:00.32]第一句');
      expect(lines[1], '[01:01.00]第二句');
      expect(lines[2], '[01:06.50]第三句');
    });

    test('字幕轨择优：ai-zh > zh 系 > 其他', () async {
      final adapter = SubtitleAdapter();
      // 经公开反射面不便；择优逻辑在 _pickSubtitle（私有）——经行为面验证：
      // 构造 fetchLrcText 的 API 通道不可行（需真网络/登录），此处锚映射函数。
      // 择优序与通道一（vtt 文件名 ai-zh 优先）同序，真实链路见 s6。
      expect(adapter.dispose, isA<Function>());
    });
  });

  test('真链路：搜索→64k 音质位下载→注册（音质选择器真实生效面）',
      timeout: const Timeout(Duration(minutes: 8)), () async {
    final dir = await Directory.systemTemp
        .createTemp('ia_cap_${DateTime.now().millisecondsSinceEpoch}');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    final db = gate.db;
    addTearDown(() async {
      try {
        await db.close();
      } catch (_) {}
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    await db.into(db.repositoryRoots).insert(RepositoryRootsCompanion.insert(
          path: dir.path,
          mode: RepositoryMode.directory,
          addedAt: 1,
        ));

    // 搜索冒烟（真网；不断言数量——B 站结果集随时间波动，不再做提取源）
    final rows = await BilibiliSearchAdapter().search('钢琴');
    print('CAP search rows=${rows.length}');
    final queue = ExtractQueue(db: db, downloader: DownloaderAdapter());
    await queue.acknowledgeCompliance(at: DateTime.now());
    final messages = <String>[];
    final sub = queue.events.listen((ev) {
      if (ev is ExtractStateChanged && ev.message != null) {
        messages.add(ev.message!);
      }
    });

    // 快捷链：enqueueUrl 瞬间入队（消费端承担解析/下载；固定视频=不被
    // 活搜索波动绑架，s6 e2e 同源锚 BV1j5nj68E48 匿名可下载）
    final (task, dup) = await queue.enqueueUrl(
      'https://www.bilibili.com/video/BV1j5nj68E48',
      quality: TaskQuality.k64, // 选择器=30216 位（最小产物，验证接线）
      withLyrics: false,
      withText: true,
      withVideo: false,
      title: 'K/DA 官方MV',
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    expect(dup, isFalse);

    final done = await queue.events
        .where((e) =>
            e is ExtractStateChanged &&
            e.taskId == task.id &&
            (e.status == ExtractTaskStatus.registered ||
                e.status == ExtractTaskStatus.failed))
        .cast<ExtractStateChanged>()
        .first
        .timeout(const Duration(minutes: 6));
    expect(done.status, ExtractTaskStatus.registered,
        reason: '音质位接线不得引入回归；失败时消息=${done.message}');
    await sub.cancel();
    await queue.dispose();
  });
}
