/// 登录态持久化 + 登录后刷新链路（B 站 / YouTube 共用）。
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/services/collect/platform_store.dart';
import 'package:ia_music/services/settings/settings_service.dart';
import 'package:ia_music/state/collect_providers.dart';

void main() {
  late IaDatabase db;
  late PlatformStore store;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // 触发建表
    store = PlatformStore(SettingsService(db.settingsDao));
  });

  tearDown(() async => db.close());

  test('cookie 落库 → loggedIn true；清除 → false', () async {
    expect(await store.loggedIn(PlatformId.bilibili), isFalse);
    await store.saveCookies(PlatformId.bilibili, 'SESSDATA=abc; bili_jct=def');
    expect(await store.loggedIn(PlatformId.bilibili), isTrue);

    await store.clearCookies(PlatformId.bilibili);
    expect(await store.loggedIn(PlatformId.bilibili), isFalse);
  });

  test('epoch bump 后 platformLoginProvider 重新读取登录态', () async {
    final container = ProviderContainer(overrides: [
      platformStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(
        platformLoginProvider(PlatformId.bilibili), (_, _) {},
        fireImmediately: true);
    addTearDown(sub.close);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      container.read(platformLoginProvider(PlatformId.bilibili)).value,
      isFalse,
    );

    await store.saveCookies(PlatformId.bilibili, 'SESSDATA=abc');
    container.read(platformLoginEpochProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      container.read(platformLoginProvider(PlatformId.bilibili)).value,
      isTrue,
    );

    await store.clearCookies(PlatformId.bilibili);
    container.read(platformLoginEpochProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      container.read(platformLoginProvider(PlatformId.bilibili)).value,
      isFalse,
    );
  });

  test('YouTube 登录态同一链路', () async {
    final container = ProviderContainer(overrides: [
      platformStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(
        platformLoginProvider(PlatformId.youtube), (_, _) {},
        fireImmediately: true);
    addTearDown(sub.close);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      container.read(platformLoginProvider(PlatformId.youtube)).value,
      isFalse,
    );
    await store.saveCookies(PlatformId.youtube, 'SAPISID=abc');
    container.read(platformLoginEpochProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      container.read(platformLoginProvider(PlatformId.youtube)).value,
      isTrue,
    );
  });
}
