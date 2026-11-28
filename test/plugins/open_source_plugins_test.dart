/// 开放音频源六件套（jamendo / internetarchive / audius / librivox / podcast /
/// subsonic）验证：真引擎加载 + 离线可测入口。
///
/// 与 builtin_plugins_test 同口径：网络入口（search/resolve/stream/lyrics 真
/// 远端部分）真机端到端；这里锁死——清单合规、契约函数齐全、match 认领/拒绝、
/// authKind/authImport 校验逻辑、纯函数（时长解析/feed 解析/标识解析等）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/plugins/plugin_manifest.dart';
import 'package:ia_music/plugins/plugin_registry.dart';
import 'package:ia_music/plugins/plugin_runtime.dart';
import 'package:ia_music/plugins/quickjs_plugin_runtime.dart';

void main() {
  late Directory dir;
  late QuickJsPluginRuntime runtime;

  Future<PluginSession?> open(String file) async {
    final registry = PluginRegistry(dir: dir.path);
    final source = File(file).readAsStringSync();
    parsePluginManifest(source); // 清单合规
    final installed = await registry.installFromSource(source);
    try {
      return await runtime.open(installed);
    } on Object catch (e) {
      // ignore: avoid_print
      print('跳过（引擎库不可用）：$e');
      return null;
    }
  }

  /// 契约函数全部定义（名单来自 docs/PLUGIN.md §3.2；__IA_HAS 为预置内省）。
  Future<void> expectContract(PluginSession session, String tag) async {
    for (final fn in [
      'match', 'authKind', 'authStart', 'authPoll', 'authImport',
      'authStatus', 'authLogout', 'search', 'resolve', 'stream', 'lyrics',
    ]) {
      expect(await session.call('__IA_HAS', [fn]), true,
          reason: '$tag 缺契约函数 $fn');
    }
  }

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('open_source_plugins_test');
    runtime = QuickJsPluginRuntime(registry: PluginRegistry(dir: dir.path));
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  test('六件套清单合规：id / capabilities 就位', () {
    final expectIds = {
      'plugins/jamendo.plugin.js': 'app.iamusic.jamendo',
      'plugins/internetarchive.plugin.js': 'app.iamusic.internetarchive',
      'plugins/audius.plugin.js': 'app.iamusic.audius',
      'plugins/librivox.plugin.js': 'app.iamusic.librivox',
      'plugins/podcast.plugin.js': 'app.iamusic.podcast',
      'plugins/subsonic.plugin.js': 'app.iamusic.subsonic',
    };
    expectIds.forEach((file, id) {
      final m = parsePluginManifest(File(file).readAsStringSync());
      expect(m.id, id, reason: file);
      expect(m.activeCapabilities, ['source'], reason: file);
    });
  });

  test('jamendo：契约齐全 + match + cookie 型认证 + client_id 校验', () async {
    final session = await open('plugins/jamendo.plugin.js');
    if (session == null) {
      return;
    }
    await expectContract(session, 'jamendo');

    expect(
        await session.call(
            'match', ['https://www.jamendo.com/track/1234/some-song-slug']),
        {'id': 'jamendo:track:1234'});
    expect(
        await session.call('match', ['https://www.jamendo.com/album/99/x']),
        {'id': 'jamendo:album:99'});
    expect(await session.call('match', ['https://example.com/x']), isNull);

    expect(await session.call('authKind', []), {'kind': 'cookie'});

    final bad = await session.call('authImport', ['not-a-client-id']) as Map;
    expect(bad['ok'], false);
    final ok = await session
        .call('authImport', ['0123456789ABCDEF0123456789abcdef']) as Map;
    expect(ok['ok'], true);
    // 凭据落在插件沙箱（kv.json），宿主不经手
    final kv = PluginRegistry(dir: dir.path);
    expect(kv.kvGetSync('app.iamusic.jamendo', 'client_id'),
        '0123456789abcdef0123456789abcdef');
    final status = await session.call('authStatus', []) as Map;
    expect(status['loggedIn'], true);
    session.dispose();
  });

  test('internetarchive：契约齐全 + match + parseDurSec 双形态', () async {
    final session = await open('plugins/internetarchive.plugin.js');
    if (session == null) {
      return;
    }
    await expectContract(session, 'internetarchive');

    expect(await session.call('match', ['https://archive.org/details/etree_123']),
        {'id': 'etree_123'});
    expect(await session.call('match', ['https://example.org/details/x']), isNull);
    expect(await session.call('authKind', []), {'kind': 'none'});

    // metadata 的 length 兼容秒数与 MM:SS 两种形态
    expect(await session.call('parseDurSec', ['4:33']), 273);
    expect(await session.call('parseDurSec', ['273.6']), 274);
    expect(await session.call('parseDurSec', ['1:02:03']), 3723);
    expect(await session.call('parseDurSec', ['']), 0);
    session.dispose();
  });

  test('audius：契约齐全 + permalink 尾段数字解析 + authKind none', () async {
    final session = await open('plugins/audius.plugin.js');
    if (session == null) {
      return;
    }
    await expectContract(session, 'audius');

    expect(
        await session.call(
            'match', ['https://audius.co/artist/song-name-370899']),
        {'id': '370899'});
    expect(await session.call('match', ['https://audius.co/just-handle']),
        isNull, reason: '个人主页不是曲目，不认领');
    expect(await session.call('match', ['https://example.com/a/b-1']), isNull);
    expect(await session.call('authKind', []), {'kind': 'none'});
    session.dispose();
  });

  test('librivox：契约齐全 + 项目页认领保留路径拒绝 + rss/slug 解析', () async {
    final session = await open('plugins/librivox.plugin.js');
    if (session == null) {
      return;
    }
    await expectContract(session, 'librivox');

    expect(
        await session.call('match',
            ['https://librivox.org/the-count-of-monte-cristo-by-alexandre-dumas/']),
        {'id': 'the-count-of-monte-cristo-by-alexandre-dumas'});
    expect(await session.call('match', ['https://librivox.org/rss/47']), isNull,
        reason: 'rss 是保留路径');
    expect(await session.call('match', ['https://librivox.org/pages/help/']),
        isNull, reason: 'pages 是保留路径');
    expect(await session.call('match', ['https://example.com/foo-bar-baz-qux/']),
        isNull);
    expect(await session.call('authKind', []), {'kind': 'none'});

    expect(await session.call('rssIdFromPage',
        ['<link href="https://librivox.org/rss/47" />']), 47);
    expect(await session.call('rssIdFromPage', ['nothing here']), 0);
    expect(await session.call('artistFromSlug', ['alice-by-lewis-carroll']),
        'Lewis Carroll');
    session.dispose();
  });

  test('podcast：契约齐全 + feed 认领裸音频拒绝 + RSS 解析 + ext 映射', () async {
    final session = await open('plugins/podcast.plugin.js');
    if (session == null) {
      return;
    }
    await expectContract(session, 'podcast');

    expect(await session.call('match', ['https://lexfridman.com/feed/podcast/']),
        {'id': 'https://lexfridman.com/feed/podcast/'});
    expect(await session.call('match', ['https://example.com/feed.xml']),
        {'id': 'https://example.com/feed.xml'});
    expect(await session.call('match', ['podcast://ep?url=a%2Fb']), {'id': 'podcast://ep?url=a%2Fb'});
    // 裸音频直链让给宿主 direct 通道；普通页面不认领
    expect(await session.call('match', ['https://example.com/ep.mp3']), isNull);
    expect(await session.call('match', ['https://example.com/page']), isNull);
    expect(await session.call('authKind', []), {'kind': 'none'});

    const rss = '''
<rss><channel><title> <![CDATA[示例播客]]> </title>
<item><title> <![CDATA[第 1 期：开场]]> </title>
<enclosure url="https://cdn.example/e1.mp3" length="15360000" type="audio/mpeg" />
<itunes:duration>45:30</itunes:duration></item>
<item><title>无 enclosure 的条目该被跳过</title></item>
<item><title>第 2 期</title>
<enclosure url="https://cdn.example/e2.m4a" length="0" type="audio/mp4" /></item>
</channel></rss>''';
    final parsed = await session.call('parseFeed', [rss]) as Map;
    expect(parsed['title'], '示例播客');
    final eps = parsed['episodes'] as List;
    expect(eps, hasLength(2));
    expect((eps[0] as Map)['title'], '第 1 期：开场');
    expect((eps[0] as Map)['url'], 'https://cdn.example/e1.mp3');
    expect((eps[0] as Map)['durationSec'], 2730, reason: 'itunes:duration 优先');
    expect((eps[1] as Map)['durationSec'], 0, reason: '无时长无字节数不硬造');

    expect(await session.call('extOf', ['https://cdn.example/e1.mp3', '']), 'mp3');
    expect(await session.call('extOf', ['https://cdn.example/noext', 'audio/mp4']), 'm4a');
    session.dispose();
  });

  test('subsonic：契约齐全 + subsonic:// 认领 + 凭据格式校验（无网络）', () async {
    final session = await open('plugins/subsonic.plugin.js');
    if (session == null) {
      return;
    }
    await expectContract(session, 'subsonic');

    expect(await session.call('match', ['subsonic://song/123']),
        {'id': 'song:123'});
    expect(await session.call('match', ['subsonic://album/9']),
        {'id': 'album:9'});
    expect(await session.call('match', ['https://nas.example/rest/x']), isNull);
    expect(await session.call('authKind', []), {'kind': 'cookie'});

    // 行数不足直接拒（不触网）；合格三行会现场 ping，属真机端到端
    final bad = await session.call('authImport', ['http://nas:4533\nadmin']) as Map;
    expect(bad['ok'], false);
    final badProto = await session
        .call('authImport', ['nas.example\nadmin\npw']) as Map;
    expect(badProto['ok'], false, reason: '地址必须带 http(s) 协议头');
    session.dispose();
  });

  test('宿主「分p」后缀剥离：各源 search 前置清洗口径一致', () async {
    final session = await open('plugins/jamendo.plugin.js');
    if (session == null) {
      return;
    }
    expect(await session.call('stripFenp', ['夜曲分p']), '夜曲');
    expect(await session.call('stripFenp', ['lofi分P']), 'lofi');
    expect(await session.call('stripFenp', ['夜曲']), '夜曲');
    session.dispose();
  });
}
