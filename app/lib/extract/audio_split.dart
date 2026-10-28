/// 音频拆分引擎（2026-10-25 需求：B 站歌曲合集单视频 → 按歌曲切分入库）。
///
/// 三层判定（REQ-EXT 拆分面）：
/// 1. 时长门：仅 > [splitDurationThresholdMs]（5 分钟）的产物才进入分析。
/// 2. 静音分析：ffmpeg `silencedetect` 找歌曲间静音带 → 带中点=切点；
///    贪心收敛保证每段 ≥ [minSegmentMs]（候选切点过多时先弃最弱切点）。
/// 3. 标题歌单匹配：视频标题里的 `《歌名》` 列表与段数一致时按序命名
///    （B 站合集标题的强信号，如「精选歌单《吴哥窟》《情意结》…」）。
///
/// 切分产物用 `-c copy` 无重编码（mp3 帧对齐，秒级完成，音质无损）。
/// 桌面形态限定（ffmpeg 工具链）；Android=诚实降级不拆分。
library;

import 'dart:io';

import 'package:ia_music/adapters/downloader_adapter.dart' show kFfmpegDir;

/// 超过该时长才做拆分分析（一首歌的正常时长上限）。
const int splitDurationThresholdMs = 5 * 60 * 1000;

/// 单段最小可接受时长（短于它不算一首歌）。
const int minSegmentMs = 45 * 1000;

/// 静音带最短时长（歌曲间隔通常 ≥1s；低于此不值得当切点）。
const double minSilenceSec = 1.2;

/// 静音判定阈值（合集母带常见底噪 -30dB 保守线）。
const String silenceNoiseFloor = '-30dB';

/// 切点上限（防御性：异常输入不做无限切分）。
const int maxSegments = 60;

/// 拆分计划中的一首歌。
final class SplitSegment {
  const SplitSegment({
    required this.startMs,
    required this.endMs,
    this.title,
  });
  final int startMs;
  final int endMs;

  /// 来自标题《》歌单匹配的曲名（null=未匹配，回退序号命名）。
  final String? title;

  int get durationMs => endMs - startMs;
}

/// ffmpeg silencedetect 输出 → 静音带中点（秒；时间轴升序）。
/// 行形态：`silence_start: 123.456` / `silence_end: 125.678 | silence_duration: 2.22`。
List<double> parseSilenceMidpoints(String ffmpegLog) {
  final starts = <double>[];
  final ends = <double>[];
  for (final line in ffmpegLog.split('\n')) {
    final l = line.trim();
    final s = RegExp(r'silence_start:\s*(-?[\d.]+)').firstMatch(l);
    if (s != null) {
      starts.add(double.tryParse(s.group(1)!) ?? 0);
      continue;
    }
    final e = RegExp(r'silence_end:\s*([\d.]+)').firstMatch(l);
    if (e != null) {
      ends.add(double.tryParse(e.group(1)!) ?? 0);
    }
  }
  final midpoints = <double>[];
  for (var i = 0; i < starts.length && i < ends.length; i++) {
    midpoints.add((starts[i] + ends[i]) / 2);
  }
  return midpoints..sort();
}

/// 从视频标题提取《》歌单（保持出现顺序；去空）。
List<String> extractSongList(String? title) {
  if (title == null || title.isEmpty) {
    return const [];
  }
  return RegExp('《([^《》]{1,64})》')
      .allMatches(title)
      .map((m) => m.group(1)!.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

/// 段数与歌单数一致 → 按序命名；否则全部 null（回退序号命名）。
List<String?> matchSegmentTitles(List<String> songs, int segmentCount) {
  if (songs.length != segmentCount) {
    return List<String?>.filled(segmentCount, null);
  }
  return songs;
}

/// 由静音中点规划分段（纯函数，单测覆盖）：
/// * 贪心收敛：段过短时弃掉"制造最短段"的切点，直至全部 ≥ [minSegmentMs]
///   或切点耗尽；段数 <2 或 > [maxSegments] → 不拆（返回空）。
List<SplitSegment> planSegments({
  required int durationMs,
  required List<double> silenceMidpoints,
  List<String> songList = const [],
  int minSegment = minSegmentMs,
}) {
  final totalMs = durationMs;
  // 切点裁剪到时间轴内
  var cuts = silenceMidpoints
      .map((s) => (s * 1000).round())
      .where((ms) => ms > 0 && ms < totalMs)
      .toList()
    ..sort();

  List<SplitSegment> build(List<int> points) {
    final bounds = [0, ...points, totalMs];
    return [
      for (var i = 0; i + 1 < bounds.length; i++)
        SplitSegment(startMs: bounds[i], endMs: bounds[i + 1]),
    ];
  }

  var segments = build(cuts);
  while (segments.length >= 2) {
    final shortest =
        segments.reduce((a, b) => a.durationMs <= b.durationMs ? a : b);
    if (shortest.durationMs >= minSegment) {
      break;
    }
    // 弃掉紧邻最短段右缘的切点（制造它的那个）；全弃 → 单段=不拆。
    final idx = segments.indexOf(shortest);
    if (idx == 0) {
      cuts.removeAt(0);
    } else {
      cuts.removeAt(idx - 1);
    }
    if (cuts.isEmpty) {
      return const [];
    }
    segments = build(cuts);
  }
  if (segments.length < 2 || segments.length > maxSegments) {
    return const [];
  }
  // 拆分意义校验：总长必须与音频时长吻合（解析错乱防御）
  final sum = segments.fold<int>(0, (acc, s) => acc + s.durationMs);
  if ((sum - totalMs).abs() > 2000) {
    return const [];
  }
  final titles = matchSegmentTitles(songList, segments.length);
  return [
    for (var i = 0; i < segments.length; i++)
      SplitSegment(
        startMs: segments[i].startMs,
        endMs: segments[i].endMs,
        title: titles[i],
      ),
  ];
}

/// 分析产物是否需要拆分；需要则返回分段计划（不需要=空表）。
/// 诚实降级：ffmpeg 拉不起/超时/解析失败 → 空（保持整轨注册）。
Future<List<SplitSegment>> detectSplit({
  required String audioPath,
  required int durationMs,
  String? videoTitle,
}) async {
  if (durationMs <= splitDurationThresholdMs) {
    return const [];
  }
  final ffmpeg = '${kFfmpegDir.replaceAll('\\', '/')}/ffmpeg.exe';
  if (!File(ffmpeg).existsSync()) {
    return const [];
  }
  final songList = extractSongList(videoTitle);
  // 已有精确歌单且与"预期歌曲数"对不上时长门时仍走静音分析（歌单只做命名）。
  final log = await _runSilenceDetect(ffmpeg, audioPath);
  if (log == null) {
    return const [];
  }
  final midpoints = parseSilenceMidpoints(log);
  return planSegments(
    durationMs: durationMs,
    silenceMidpoints: midpoints,
    songList: songList,
  );
}

Future<String?> _runSilenceDetect(String ffmpeg, String audioPath) async {
  try {
    final r = await Process.run(ffmpeg, [
      '-hide_banner',
      '-nostats',
      '-i', audioPath,
      '-af', 'silencedetect=noise=$silenceNoiseFloor:d=$minSilenceSec',
      '-f', 'null', '-',
    ]);
    if (r.exitCode != 0) {
      return null;
    }
    // silencedetect 输出在 stderr（ffmpeg 日志面）
    return '${r.stderr}';
  } on Exception {
    return null;
  }
}

/// 按计划切分音频（`-c copy` 无重编码）到 [outputDir]；返回产物文件列表。
/// 命名=`$baseName NN.mp3`（注册时再迁入仓库改正式名）。
Future<List<File>> splitAudio({
  required String audioPath,
  required String outputDir,
  required List<SplitSegment> segments,
  required String baseName,
}) async {
  final ffmpeg = '${kFfmpegDir.replaceAll('\\', '/')}/ffmpeg.exe';
  final out = <File>[];
  final safeBase = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    final seq = "${i + 1}".padLeft(2, '0');
    final target = File('$outputDir/$safeBase $seq.mp3');
    final r = await Process.run(ffmpeg, [
      '-hide_banner',
      '-nostats',
      '-y',
      '-ss', (seg.startMs / 1000).toStringAsFixed(3),
      '-to', (seg.endMs / 1000).toStringAsFixed(3),
      '-i', audioPath,
      '-c', 'copy',
      target.path,
    ]);
    if (r.exitCode != 0 || !target.existsSync()) {
      // 单段失败 → 已产出的段全部作废（不留半套拆分产物）
      for (final f in out) {
        try {
          f.deleteSync();
        } on Exception {
          // 删除失败=残留由 OS 临时策略回收
        }
      }
      return const [];
    }
    out.add(target);
  }
  return out;
}

/// LRC 时间轴偏移（拆分曲的字幕文本链：全视频 LRC → 本段窗口）。
/// `[mm:ss.xx]text` 行落在 [startMs,endMs) 内平移 -startMs；界外丢弃。
String shiftLrc(String lrc, int startMs, int endMs) {
  final out = <String>[];
  final ts = RegExp(r'^\[(\d{1,3}):(\d{2})[.](\d{1,3})\](.*)$');
  for (final line in lrc.split('\n')) {
    final m = ts.firstMatch(line.trim());
    if (m == null) {
      continue; // 非时间轴行（元数据/空行）不保留——段 LRC 保持纯时间轴
    }
    final mm = int.parse(m.group(1)!);
    final ss = int.parse(m.group(2)!);
    final frac = m.group(3)!.padRight(3, '0').substring(0, 3);
    final at = (mm * 60 + ss) * 1000 + int.parse(frac);
    if (at < startMs || at >= endMs) {
      continue;
    }
    final shifted = at - startMs;
    final nmm = (shifted ~/ 60000).toString().padLeft(2, '0');
    final nss = ((shifted ~/ 1000) % 60).toString().padLeft(2, '0');
    final nfrac = (shifted % 1000).toString().padLeft(3, '0').substring(0, 2);
    out.add('[$nmm:$nss.$nfrac]${m.group(4)}');
  }
  return out.join('\n');
}
