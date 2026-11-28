/// 默认插件安装器测试——随包资产 → 注册表：首装/幂等/版本升级/墓碑。
library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/plugins/default_plugins.dart';
import 'package:ia_music/plugins/plugin_manifest.dart';
import 'package:ia_music/plugins/plugin_registry.dart';

void main() {
  late Directory dir;
  late PluginRegistry registry;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('default_plugins_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    registry = PluginRegistry(dir: dir.path);
  });

  test('首装：随包插件全部入册且默认启用', () async {
    final changed = await ensureDefaultPlugins(registry, const {});
    expect(changed, containsAll(['app.iamusic.bilibili', 'app.iamusic.youtube']));

    final all = await registry.list();
    expect(all.map((p) => p.manifest.id),
        containsAll(['app.iamusic.bilibili', 'app.iamusic.youtube']));
    expect(all.every((p) => p.enabled), isTrue);
    expect((await registry.byId('app.iamusic.bilibili'))!.sha256, isNotEmpty);
  });

  test('幂等：重复调用不重复安装不误升级', () async {
    await ensureDefaultPlugins(registry, const {});
    final before = await registry.byId('app.iamusic.bilibili');

    final changed = await ensureDefaultPlugins(registry, const {});

    expect(changed, isEmpty);
    final after = await registry.byId('app.iamusic.bilibili');
    expect(after!.installedAt, before!.installedAt);
    expect((await registry.list()), hasLength(defaultPluginAssets.length));
  });

  test('版本升级：随包版本更高则覆盖，启用态保留', () async {
    const older = '''
/*!
{ "id": "app.iamusic.bilibili", "name": "B 站音频源", "version": "0.9.0",
  "api": 1, "capabilities": ["source"] }
*/
async function match(url) { return null; }
''';
    await registry.installFromSource(older);
    await registry.setEnabled('app.iamusic.bilibili', false);

    final changed = await ensureDefaultPlugins(registry, const {});

    expect(changed, contains('app.iamusic.bilibili'));
    final p = await registry.byId('app.iamusic.bilibili');
    expect(p!.manifest.version, '1.0.0');
    expect(p.enabled, isFalse, reason: '升级不清掉用户的启停决定');
  });

  test('墓碑：用户卸载过的默认插件不再回装', () async {
    // 先装一次（模拟历史版本），随后用户卸载
    await ensureDefaultPlugins(registry, const {});
    await registry.uninstall('app.iamusic.youtube');

    final changed =
        await ensureDefaultPlugins(registry, {'app.iamusic.youtube'});

    expect(changed, isNot(contains('app.iamusic.youtube')));
    expect(await registry.byId('app.iamusic.youtube'), isNull);
    // bilibili 不受影响
    expect(await registry.byId('app.iamusic.bilibili'), isNotNull);
  });

  test('compareVersions：三段数值语义', () {
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('1.1.0', '1.0.0'), 1);
    expect(compareVersions('0.9.9', '1.0.0'), -1);
    expect(compareVersions('1.0', '1.0.0'), 0, reason: '缺段按 0');
    expect(compareVersions('1.0.10', '1.0.9'), 1, reason: '数值而非字典序');
  });

  test('随包资产清单合规：解析得到默认 id', () async {
    for (final asset in defaultPluginAssets) {
      final m = parsePluginManifest(await rootBundle.loadString(asset));
      expect(m.id, isNotEmpty, reason: asset);
    }
  });
}
