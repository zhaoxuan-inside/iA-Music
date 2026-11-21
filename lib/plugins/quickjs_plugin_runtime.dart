/// QuickJS 沙箱实现（quickjs_engine，QuickJS-NG 0.14，全平台同引擎）。
///
/// 桥协议（docs/PLUGIN.md §3）：
/// * 同步通道（JS `sendMessage` 直接拿返回值）：`ia.crypto` / `ia.kv.get`
///   / `ia.kv.set` / `ia.log`；
/// * 异步通道（JS 挂起 Promise → Dart 完成时 evaluate 回调存根）：
///   `ia.fetch`。
/// 会话调用：插件全局 async 函数 → Promise 经引擎 `handlePromise` 等待落定
/// （20ms 轮询 + pending job 驱动）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

import 'plugin_registry.dart';
import 'plugin_runtime.dart';

/// 宿主注入的桥预置代码：在任何插件源码之前求值。
/// 约定 `IA.*` 能力面 + 宿主完成回调存根（内部实现，非插件契约）。
const String _iaPrelude = '''
var __IA_PENDING = {};
var __IA_SEQ = -1;
function __IA_CALL_ASYNC(channel, payload) {
  return new Promise(function (resolve, reject) {
    __IA_SEQ += 1;
    var id = __IA_SEQ;
    __IA_PENDING[id] = { resolve: resolve, reject: reject };
    sendMessage(channel, JSON.stringify({ id: id, payload: payload }));
  });
}
function __IA_COMPLETE(id, ok, json) {
  var p = __IA_PENDING[id];
  if (!p) return;
  delete __IA_PENDING[id];
  if (ok) { p.resolve(JSON.parse(json)); } else { p.reject(new Error(JSON.parse(json))); }
}
function __IA_INVOKE(fnName, argsJson) {
  // 外层 promise 落定为「字符串」（双层 JSON）——引擎的 promise→Dart
  // 转换对对象结果走 Dart toString 不可解析，字符串结果两分支均可靠。
  return Promise.resolve().then(function () {
    var fn = globalThis[fnName];
    if (typeof fn !== 'function') {
      throw new Error('插件未定义全局函数 ' + fnName);
    }
    return fn.apply(globalThis, JSON.parse(argsJson));
  }).then(
    function (v) { return JSON.stringify({ ok: true, value: JSON.stringify(v === undefined ? null : v) }); },
    function (e) { return JSON.stringify({ ok: false, value: String((e && e.message) || e) }); }
  );
}
var IA = {
  fetch: function (req) { return __IA_CALL_ASYNC('ia.fetch', req || {}); },
  kvGet: function (key) { return sendMessage('ia.kv.get', JSON.stringify({ key: String(key) })); },
  kvSet: function (key, value) {
    return sendMessage('ia.kv.set',
        JSON.stringify({ key: String(key), value: value === undefined ? null : String(value) }));
  },
  md5: function (s) { return sendMessage('ia.crypto', JSON.stringify({ op: 'md5', data: String(s) })); },
  sha256: function (s) { return sendMessage('ia.crypto', JSON.stringify({ op: 'sha256', data: String(s) })); },
  hmacSha256: function (key, s) {
    return sendMessage('ia.crypto', JSON.stringify({ op: 'hmac', key: String(key), data: String(s) }));
  },
  log: function () {
    var a = Array.prototype.slice.call(arguments).map(function (x) {
      try { return typeof x === 'string' ? x : JSON.stringify(x); } catch (_) { return String(x); }
    });
    sendMessage('ia.log', JSON.stringify(a));
  }
};
''';

class QuickJsPluginRuntime implements PluginRuntimePort {
  const QuickJsPluginRuntime({required this.registry});

  /// 凭据沙箱（KV）与日志落地。
  final PluginRegistry registry;

  @override
  Future<PluginSession> open(InstalledPlugin plugin) async {
    final session = _QuickJsSession._(plugin, registry);
    session._init();
    return session;
  }
}

class _QuickJsSession implements PluginSession {
  _QuickJsSession._(this.plugin, this.registry);

  final InstalledPlugin plugin;
  final PluginRegistry registry;

  late final JavascriptRuntime _rt;
  final _logs = <String>[];

  @override
  List<String> get logs => List.unmodifiable(_logs);

  void _init() {
    _rt = getJavascriptRuntime(xhr: false);
    _registerChannels();
    _rt.evaluate(_iaPrelude);
    _rt.evaluate(registry.loadSource(plugin));
  }

  void _registerChannels() {
    _rt.onMessage('ia.crypto', (dynamic args) {
      final op = args['op'] as String?;
      final data = args['data'] as String? ?? '';
      final bytes = utf8.encode(data);
      switch (op) {
        case 'md5':
          return md5.convert(bytes).toString();
        case 'sha256':
          return sha256.convert(bytes).toString();
        case 'hmac':
          final key = utf8.encode(args['key'] as String? ?? '');
          return Hmac(sha256, key).convert(bytes).toString();
        default:
          return '';
      }
    });
    _rt.onMessage('ia.kv.get', (dynamic args) {
      return registry.kvGetSync(plugin.manifest.id, args['key'] as String);
    });
    _rt.onMessage('ia.kv.set', (dynamic args) {
      registry.kvSetSync(plugin.manifest.id, args['key'] as String,
          args['value'] as String?);
      return 'ok';
    });
    _rt.onMessage('ia.log', (dynamic args) {
      if (args is List<Object?>) {
        _logs.add(args.map((e) => e?.toString() ?? 'null').join(' '));
      }
      return null;
    });
    _rt.onMessage('ia.fetch', (dynamic args) {
      final id = args['id'] as int;
      final req = (args['payload'] as Map<String, Object?>?) ?? const {};
      _doFetch(req).then(
        (resp) => _complete(id, true, jsonEncode(resp)),
        onError: (Object e) => _complete(id, false, jsonEncode('$e')),
      );
      return null;
    });
  }

  Future<Map<String, Object?>> _doFetch(Map<String, Object?> req) async {
    final url = req['url'] as String? ?? '';
    if (Uri.tryParse(url)?.hasScheme != true) {
      throw const PluginInvokeException('IA.fetch：url 非法');
    }
    final client = HttpClient();
    try {
      final method = (req['method'] as String? ?? 'GET').toUpperCase();
      final request = await client.openUrl(method, Uri.parse(url));
      (req['headers'] as Map<String, Object?>? ?? const {})
          .forEach((k, v) => request.headers.set(k, v.toString()));
      final body = req['body'] as String?;
      if (body != null) {
        request.add(utf8.encode(body));
      }
      final resp =
          await request.close().timeout(const Duration(seconds: 20));
      final respBody = await resp.transform(utf8.decoder).join();
      final headers = <String, String>{};
      resp.headers.forEach((k, vs) => headers[k] = vs.join(', '));
      return {'status': resp.statusCode, 'headers': headers, 'body': respBody};
    } finally {
      client.close();
    }
  }

  void _complete(int id, bool ok, String json) {
    _rt.evaluate('__IA_COMPLETE($id, $ok, ${jsonEncode(json)})');
    _rt.executePendingJob();
  }

  @override
  Future<Object?> call(String fn, List<Object?> args,
      {Duration? timeout}) async {
    final effective = timeout ?? const Duration(seconds: 30);
    final JsEvalResult promise;
    try {
      final cmd =
          '__IA_INVOKE(${jsonEncode(fn)}, ${jsonEncode(jsonEncode(args))})';
      promise = _rt.evaluate(cmd);
    } on Object catch (e) {
      throw PluginInvokeException('求值失败：$e');
    }
    final JsEvalResult settled;
    try {
      settled = await _rt.handlePromise(promise, timeout: effective);
    } on TimeoutException {
      throw PluginInvokeException('调用超时（${effective.inSeconds}s）：$fn');
    } on Object catch (e) {
      throw PluginInvokeException('沙箱内部错误：$e');
    }
    // 落定值是双层 JSON 字符串（见 __IA_INVOKE）。引擎两分支的呈现形态：
    // Future 分支 = 信封 JSON 本体；轮询分支 = 外面再包一层 JSON 引号。
    final Object? envelope;
    try {
      final first = jsonDecode(settled.stringResult);
      envelope = first is String ? jsonDecode(first) : first;
    } on FormatException {
      throw PluginInvokeException('结果不可解析：${settled.stringResult}');
    }
    if (envelope is! Map<String, Object?>) {
      throw PluginInvokeException('结果形态异常：${settled.stringResult}');
    }
    final ok = envelope['ok'] as bool? ?? false;
    final value = envelope['value'] as String?;
    if (!ok) {
      throw PluginInvokeException(value ?? '未知错误');
    }
    return value == null ? null : jsonDecode(value);
  }

  @override
  void dispose() => _rt.dispose();
}
