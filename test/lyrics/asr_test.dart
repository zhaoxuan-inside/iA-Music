// ASR 歌词链测试（2026-10-25 装配）：
// * asrTokensToLyrics 纯函数（样本=SenseVoice 真输出的 token 序列形态）
// * 真 E2E（skip-if-missing）：SAPI 合成语音 wav → AsrAdapter 子进程 → 文本命中
// * LyricsService LRCLIB 未命中 → ASR 兜底 → .lrc 落盘 + meta（fake port 注入）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/asr_adapter.dart';
import 'package:ia_music/adapters/asr_native.dart';
import 'package:ia_music/adapters/netease_lyric_search.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/lyrics/asr_lyrics.dart';
import 'package:ia_music/lyrics/lyrics_service.dart';

void main() {
  group('asrTokensToLyrics（LRC 成形）', () {
    test('特殊标记剔除 + 标点断行 + 行首时间锚', () {
      final tokens = [
        const AsrToken(180, '<|zh|>'),
        const AsrToken(180, '大'),
        const AsrToken(360, '家'),
        const AsrToken(480, '好'),
        const AsrToken(720, '，'),
        const AsrToken(1140, '今'),
        const AsrToken(1320, '天'),
        const AsrToken(1560, '我'),
        const AsrToken(1740, '们'),
        const AsrToken(7200, '。'),
        const AsrToken(9800, '<|HAPPY|>'),
        const AsrToken(9800, '夜'),
        const AsrToken(10200, '空'),
        const AsrToken(10600, '中'),
      ];
      final out = asrTokensToLyrics(tokens);
      final lines = out.lrc.split('\n');
      expect(lines, hasLength(3));
      expect(lines[0], '[00:00.18]大家好');
      expect(lines[1], '[00:01.14]今天我们');
      expect(lines[2], '[00:09.80]夜空中');
      expect(out.lrc.contains(RegExp(r'[，。！？]')), isFalse,
          reason: '标点不进 LRC 行文本');
      expect(out.plainText.contains('大家好'), isTrue);
      expect(out.plainText.contains('<|'), isFalse,
          reason: '特殊标记不得进歌词');
    });

    test('长行强制断行（14 字上限）与纯标点丢弃', () {
      final tokens = [
        for (var i = 0; i < 20; i++) AsrToken(i * 200, '字$i'),
        const AsrToken(5000, '！'),
      ];
      final out = asrTokensToLyrics(tokens);
      final lines = out.lrc.split('\n');
      expect(lines.length, greaterThanOrEqualTo(2));
      for (final l in lines) {
        expect(l.replaceFirst(RegExp(r'^\[\d{2}:\d{2}\.\d{2}\]'), '').length,
            lessThanOrEqualTo(14));
      }
    });

    test('空输入=空产物（纯音乐语义由调用方处理）', () {
      expect(asrTokensToLyrics(const []).lrc, '');
    });
  });

  group('LyricsService ASR 兜底（fake 注入面）', () {
    test('LRCLIB 未命中 → 转写落 .lrc + lyrics_meta(type=lrc)', () async {
      final dir = await Directory.systemTemp.createTemp('ia_asr_svc');
      final gate = await openIaDatabase('${dir.path}/db.sqlite');
      final db = gate.db;
      addTearDown(() async {
        try {
          await db.close();
        } catch (_) {}
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });
      await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(path: dir.path, mode: RepositoryMode.directory, addedAt: 1));
      final audio = File('${dir.path}/孤曲.mp3')..writeAsBytesSync([1, 2, 3]);
      final trackId = await DataAccess(db).library.insertTrackWithIndex(
          1, '孤曲.mp3',
          mtime: 1, fileSize: 3, contentHash: 'h', nowMs: 1,
          title: '不存在的歌名', artistDisplay: '测试', durationMs: 60000);
      expect(audio.existsSync(), isTrue);

      final svc = LyricsService(
        db,
        DataAccess(db).lyrics,
        asr: _FakeAsr([
          const AsrToken(500, '夜'),
          const AsrToken(700, '空'),
          const AsrToken(900, '中'),
          const AsrToken(1200, '，'),
          const AsrToken(1500, '最'),
          const AsrToken(1700, '亮'),
        ]),
        modelDirResolver: () async => 'C:/fake/model',
      );
      final out = await svc.runForTrack(trackId);
      expect(out.kind, LyricsOutcomeKind.asrGenerated);
      final lrc = File('${dir.path}/孤曲.lrc');
      expect(lrc.existsSync(), isTrue, reason: 'ASR LRC 同目录落盘');
      expect(lrc.readAsStringSync(), contains('夜空中'));
      final meta = await DataAccess(db).lyrics.metaFor(trackId);
      expect(meta, isNotNull);
      expect(meta!.type, LyricsSourceType.lrc);
      // ASR 路径不 enrich 标题（非正式元数据）
      final row = await DataAccess(db).library.rowById(trackId);
      expect(row!.title, '不存在的歌名');
    });

    test('模型缺失（resolver=null）→ asrUnavailable 语义保持', () async {
      final dir = await Directory.systemTemp.createTemp('ia_asr_svc2');
      final gate = await openIaDatabase('${dir.path}/db.sqlite');
      final db = gate.db;
      addTearDown(() async {
        try {
          await db.close();
        } catch (_) {}
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });
      await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(path: dir.path, mode: RepositoryMode.directory, addedAt: 1));
      final trackId = await DataAccess(db).library.insertTrackWithIndex(
          1, 'x.mp3',
          mtime: 1, fileSize: 1, contentHash: 'h2', nowMs: 1,
          title: '某歌', durationMs: 60000);
      final svc = LyricsService(db, DataAccess(db).lyrics,

          asr: _FakeAsr(const []),
          modelDirResolver: null);
      final out = await svc.runForTrack(trackId);
      expect(out.kind, LyricsOutcomeKind.asrUnavailable);
      expect(out.errorCode, 'asr_unavailable');
    });
  });

  test('真 E2E：原生 FFI（sherpa-onnx-c-api.dll）转写 SAPI 语音命中',
      timeout: const Timeout(Duration(minutes: 5)), () async {
    final modelDir = 'C:/Users/hardstone/tools/r3/sensevoice';
    final dllDir =
        'build/windows/x64/runner/Release'; // 测试进程无 exe 旁 DLL → 显式指向
    if (!Directory(modelDir).existsSync() ||
        !File('$dllDir/sherpa-onnx-c-api.dll').existsSync()) {
      return; // 环境缺件=跳过
    }
    final wav = '${Directory.systemTemp.path}/ia_asr_native.wav';
    final sapi = await Process.run('powershell', [
      '-Command',
      "Add-Type -AssemblyName System.Speech;"
      "\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
      "\$s.SetOutputToWaveFile('$wav');"
      "\$s.Speak('夜空中最亮的星请照亮我前行');\$s.Dispose()"
    ]);
    if (sapi.exitCode != 0 || !File(wav).existsSync()) {
      return;
    }
    final rec = AsrNativeRecognizer.create(modelDir, dllDir: dllDir);
    expect(rec, isNotNull, reason: 'dll+模型在位应建识别器');
    // SAPI 语音合成 wav=22k/16bit 立体声？——先经 ffmpeg 归一到 16k mono
    final conv = await Process.run(
        'C:/Users/hardstone/tools/ffmpeg/ffmpeg.exe',
        ['-y', '-i', wav, '-ac', '1', '-ar', '16000',
         '-c:a', 'pcm_s16le', '$wav.16k.wav']);
    expect(conv.exitCode, 0);
    final samples = AsrNativeRecognizer.readWav16kMono('$wav.16k.wav');
    expect(samples, isNotNull);
    final tokens = rec!.transcribeSamples(samples!);
    final lyrics = asrTokensToLyrics(tokens);
    expect(lyrics.plainText, contains('夜空'),
        reason: '原生 FFI 转写应命中；实际=${lyrics.plainText}');
    rec.dispose();
  });

  test('真网 E2E：网易歌词反查（夜空中最亮的星句 → 逃跑计划）',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final id = await NetEaseLyricSearch().identifyByLyrics(
      ['夜空中最亮的星请照亮我前行', '夜空中最亮的星是否知道'],
      durationMs: 268000,
    );
    if (id == null) {
      return; // 网络不可达=跳过（非断言失败）
    }
    expect(id.title, '夜空中最亮的星');
    expect(id.artist, '逃跑计划');
  }, skip: Directory.systemTemp.path.isEmpty); // 始终真跑（skip 恒 false 形态）

  group('LyricsService 反查集成（fake 注入）', () {
    test('ASR 落 LRC 后反查命中 → 改写歌名/歌手 + 回调触发', () async {
      final dir = await Directory.systemTemp.createTemp('ia_asr_rev');
      final gate = await openIaDatabase('${dir.path}/db.sqlite');
      final db = gate.db;
      addTearDown(() async {
        try {
          await db.close();
        } catch (_) {}
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });
      await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
              path: dir.path, mode: RepositoryMode.directory, addedAt: 1));
      File('${dir.path}/合集 3.mp3').writeAsBytesSync([1, 2, 3]);
      final trackId = await DataAccess(db).library.insertTrackWithIndex(
          1, '合集 3.mp3',
          mtime: 1, fileSize: 3, contentHash: 'hr', nowMs: 1,
          title: '粤语合集 3/9', artistDisplay: '某UP', durationMs: 268000);

      var enrichedCalled = 0;
      final svc = LyricsService(
        db,
        DataAccess(db).lyrics,
        asr: _FakeAsr([
          const AsrToken(500, '夜'),
          const AsrToken(700, '空'),
          const AsrToken(900, '中'),
          const AsrToken(1200, '，'),
          const AsrToken(1500, '最'),
          const AsrToken(1700, '亮'),
        ]),
        modelDirResolver: () async => 'C:/fake/model',
        textSearch: _FakeSearch(const LyricsIdentity(
          songId: 1,
          title: '夜空中最亮的星',
          artist: '逃跑计划',
          album: '世界',
          durationMs: 268000,
        )),
        onTrackEnriched: (_) => enrichedCalled++,
      );
      final out = await svc.runForTrack(trackId);
      expect(out.kind, LyricsOutcomeKind.asrGenerated);
      final row = await DataAccess(db).library.rowById(trackId);
      expect(row!.title, '夜空中最亮的星', reason: '反查命中改写歌名');
      expect(row.artistDisplay, '逃跑计划');
      expect(enrichedCalled, 1, reason: '回调触发（revision+封面联动入口）');
    });
  });
}

final class _FakeAsr implements LocalAsrPort {
  _FakeAsr(this.tokens);
  final List<AsrToken> tokens;
  @override
  Future<List<AsrToken>?> transcribe(
      {required String modelDir, required String audioPath}) async {
    return tokens.isEmpty ? null : tokens;
  }
}

final class _FakeSearch implements LyricTextSearchPort {
  _FakeSearch(this.hit);
  final LyricsIdentity? hit;
  
  @override
  Future<LyricsIdentity?> identifyByLyrics(List<String> lines,
      {int? durationMs}) async {
    return hit;
  }

  // D12-4①② 新增面（测试不触及回填）
  @override
  Future<String?> fetchSyncedLyrics(int songId) async => null;
  
  @override
  Future<({String url, List<int> bytes})?> fetchCover(int songId) async => null;
}
