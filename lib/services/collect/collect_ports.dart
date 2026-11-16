/// 收集域客户端端口：提取执行所需的最小接口。
///
/// CollectRunner 只依赖本端口（不依赖具体 HTTP 客户端），
/// 测试注入假实现即可覆盖整条提取管道。
library;

import 'bilibili_client.dart';
import 'youtube_client.dart';

/// B 站提取端口。
abstract class BiliCollectApi {
  Future<BiliVideoInfo> videoInfo(String bvid);
  Future<BiliAudioStream> audioStream(String bvid, String aid, int cid);
  Future<String> downloadAudio(BiliAudioStream stream, String filePath,
      {void Function(int received, int total)? onProgress});
  Future<List<BiliSubtitle>> subtitles(String? aid, int cid);
  Future<String?> subtitleLrc(String subtitleUrl);
}

/// YouTube 提取端口。
abstract class YtCollectApi {
  Future<(Map<String, dynamic> videoDetails, YtAudioStream stream)>
      resolveAudio(String videoId);
  Future<String> downloadAudio(YtAudioStream stream, String filePath,
      {void Function(int received, int total)? onProgress});
}
