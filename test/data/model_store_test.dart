/// ModelStore 全口径测试：本地 HTTP 真下载 + sha256 校验 + 登记记账 +
/// 文件丢失自愈 + 单飞并发。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/data/models/model_store.dart';

void main() {
  late IaDatabase db;
  late Directory modelsDir;
  late ModelStore store;
  late HttpServer server;
  var hits = 0;

  /// 测试载荷：16KB 确定性字节（非平凡内容，保证哈希有区分度）。
  late Uint8List payload;
  late String payloadSha;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    modelsDir = await Directory.systemTemp.createTemp('model_store_test');
    addTearDown(() => modelsDir.delete(recursive: true));
    addTearDown(db.close);
    store = ModelStore(db, modelsDir.path);

    payload = Uint8List.fromList([for (var i = 0; i < 16384; i++) i % 251]);
    payloadSha = sha256.convert(payload).toString();

    hits = 0;
    server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(server.close);
    server.listen((req) async {
      hits++;
      req.response.add(payload);
      await req.response.close();
    });
  });

  String url() => 'http://127.0.0.1:${server.port}/model.tflite';

  test('ensureReady：下载→校验→落盘→登记；二次调用零下载', () async {
    final path = await store.ensureReady(
        id: 'm1', url: url(), sha256: payloadSha, sizeBytes: payload.length);
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    expect(File(path).lengthSync(), payload.length);
    expect(hits, 1);

    final row = await db.modelDao.readyModel('m1');
    expect(row, isNotNull);
    expect(row!.sha256, payloadSha);
    expect(row.filePath, path);

    // 复用：登记命中零下载
    final path2 = await store.ensureReady(
        id: 'm1', url: url(), sha256: payloadSha, sizeBytes: payload.length);
    expect(path2, path);
    expect(hits, 1, reason: '登记命中不再下载');
  });

  test('sha256 不符：拒收 + temp 清理 + 无登记', () async {
    final path = await store.ensureReady(
        id: 'm2',
        url: url(),
        sha256: 'ff' * 32,
        sizeBytes: payload.length);
    expect(path, isNull, reason: '哈希不符判伪源');
    expect(hits, 1);
    expect(await db.modelDao.readyModel('m2'), isNull);
    expect(modelsDir.listSync(), isEmpty, reason: 'temp 已清理，无半截残留');
  });

  test('字节数不符：直接判废', () async {
    final path = await store.ensureReady(
        id: 'm3',
        url: url(),
        sha256: payloadSha,
        sizeBytes: payload.length + 1);
    expect(path, isNull);
    expect(modelsDir.listSync(), isEmpty);
  });

  test('文件丢失自愈：登记在但文件没了 → 重下', () async {
    final path = await store.ensureReady(
        id: 'm4', url: url(), sha256: payloadSha, sizeBytes: payload.length);
    File(path!).deleteSync();

    final path2 = await store.ensureReady(
        id: 'm4', url: url(), sha256: payloadSha, sizeBytes: payload.length);
    expect(path2, isNotNull);
    expect(File(path2!).existsSync(), isTrue);
    expect(hits, 2, reason: '登记失配 → 自愈重下');
  });

  test('换校验锚（模型升级）：登记锚失配 → 清位重下', () async {
    await db.modelDao.markReady(
        id: 'm6', url: url(), sha256: 'old-sha', filePath: 'whatever', sizeBytes: 0);

    final path = await store.ensureReady(
        id: 'm6', url: url(), sha256: payloadSha, sizeBytes: payload.length);
    expect(path, isNotNull);
    expect(hits, 1, reason: '登记锚与配置锚失配仍触发下载');
    expect((await db.modelDao.readyModel('m6'))!.sha256, payloadSha);
  });

  test('单飞：并发 ensureReady 共享一次下载', () async {
    // 慢速源给并发留窗口
    final slow = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(slow.close);
    var slowHits = 0;
    slow.listen((req) async {
      slowHits++;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      req.response.add(payload);
      await req.response.close();
    });

    final slowUrl = 'http://127.0.0.1:${slow.port}/m.tflite';
    final results = await Future.wait([
      store.ensureReady(
          id: 'm5', url: slowUrl, sha256: payloadSha, sizeBytes: payload.length),
      store.ensureReady(
          id: 'm5', url: slowUrl, sha256: payloadSha, sizeBytes: payload.length),
    ]);
    expect(results[0], isNotNull);
    expect(results[0], results[1], reason: '单飞共享同一次下载结果');
    expect(slowHits, 1);
  });
}
