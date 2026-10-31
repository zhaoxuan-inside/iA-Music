/// WS6 同步域测试夹具 —— 最小真实 WebDAV 服务器（DEC-010：无替身，本地真协议）。
///
/// * 用途：`app/test/sync/` 同步链路测试与人工冒烟。纯 Dart（仅 dart:io/
///   dart:convert/dart:typed_data + webdav_client_plus 做冒烟对拍），无 flutter
///   依赖，可直接 `dart run test/sync/webdav_fixture_server.dart` 起服务自检。
/// * 协议面（RFC 4918 最小形状）：OPTIONS / PROPFIND（Depth 0/1）/ GET / HEAD /
///   PUT / MKCOL / DELETE；构造或 start 给了 username/password 时启用 Basic Auth
///   （缺凭据/凭据错 → 401 + WWW-Authenticate）。响应 207 multistatus XML 用
///   `xmlns:D="DAV:"` 标准命名空间（href/displayname/getcontentlength/
///   getlastmodified/resourcetype，目录用 `<D:collection/>`），与 adapter 侧
///   webdav_client_plus 解析器严格对齐（冒烟阶段用该包真实解析对拍验证）。
/// * 语义按 RFC 收紧（真协议口径，替身不会这样拒绝）：PUT/MKCOL 父目录缺失 →
///   409（客户端须先 MKCOL——webdav_client_plus 的 write/mkdirAll 自带逐级
///   MKCOL）；已存在再 MKCOL → 405；PUT 指向目录 → 405；GET 缺失 → 404；
///   DELETE 缺失 → 404（客户端把 404 视为已删成功）。
/// * 存储：内存目录树（Map<规范化路径, _Entry>），进程退出即消失，测试无残留；
///   构造可选传 rootPath 作临时根目录标记（内存存储不落盘，保留参数对齐夹具约定）。
/// * mtime：PUT/MKCOL 记录服务器当前时间，经 `getlastmodified`（RFC 1123）回传
///   ——秒级精度，与真实 WebDAV 服务器一致（diff 的时间戳比较按此口径）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:webdav_client_plus/webdav_client_plus.dart';

/// 内存目录树条目。
class _Entry {
  _Entry.dir(this.modified) : isDir = true, bytes = Uint8List(0);

  _Entry.file(this.bytes, this.modified) : isDir = false;

  final bool isDir;
  final Uint8List bytes;
  DateTime modified;
}

/// 最小 WebDAV 服务器（内存存储，绑定 127.0.0.1 随机端口）。
class MiniWebDavServer {
  MiniWebDavServer({this.username, this.password, this.rootPath});

  /// Basic Auth 账号（两者都非空才启用校验；start 可再覆盖）。
  String? username;
  String? password;

  /// 可选临时根目录标记（内存存储不落盘；保留参数对齐夹具约定）。
  final String? rootPath;

  HttpServer? _server;

  /// 规范化路径 → 条目。键形如 `/dir/file.txt`（目录不带尾斜杠，根为 `/`）。
  final Map<String, _Entry> _store = {'/': _Entry.dir(DateTime.now())};

  /// 绑定 127.0.0.1 随机端口并开始服务，返回 baseUrl（含尾 `/`）。
  Future<Uri> start({String? username, String? password}) async {
    if (username != null) this.username = username;
    if (password != null) this.password = password;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(
      _handle,
      // 客户端中途断开等 socket 噪声不打断服务（fixture 传输噪声，非逻辑错误）。
      onError: (Object _) {},
    );
    return Uri.parse('http://127.0.0.1:${server.port}/');
  }

  /// 停止服务（测试 teardown；重复调用安全）。
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  /// 远端资源存在性断言面（测试用：直读内存树；path 相对 baseUrl）。
  bool exists(String path) {
    final clean =
        '/${path.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '')}';
    return _store.containsKey(clean);
  }

  // ── 请求分发 ──────────────────────────────────────────────────────────────

  Future<void> _handle(HttpRequest request) async {
    try {
      // 先整读请求体（PUT 需要；其余丢弃）——保持连接可复用、语义简单。
      final body = await _readBody(request);
      if (!_checkAuth(request)) {
        final response = request.response;
        response.statusCode = HttpStatus.unauthorized;
        response.headers.set(
          HttpHeaders.wwwAuthenticateHeader,
          'Basic realm="iA-Music"',
        );
        await response.close();
        return;
      }
      switch (request.method) {
        case 'OPTIONS':
          await _options(request);
        case 'PROPFIND':
          await _propfind(request);
        case 'GET' || 'HEAD':
          await _get(request);
        case 'PUT':
          await _put(request, body);
        case 'MKCOL':
          await _mkcol(request);
        case 'DELETE':
          await _delete(request);
        default:
          request.response.headers.set(
            HttpHeaders.allowHeader,
            _kAllowedMethods,
          );
          await _plain(
            request.response,
            HttpStatus.methodNotAllowed,
            'Method Not Allowed',
          );
      }
    } on Object catch (e) {
      // 夹具级兜底：逻辑错误必须留痕，不打成 200。
      try {
        await _plain(
          request.response,
          HttpStatus.internalServerError,
          'fixture error: $e',
        );
      } on Object {
        // 响应头已提交时无法再写 500——连接复位即断开（传输噪声）。
      }
    }
  }

  Future<Uint8List> _readBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await request.forEach(builder.add);
    return builder.takeBytes();
  }

  bool _checkAuth(HttpRequest request) {
    final user = username;
    final pass = password;
    if (user == null || pass == null) {
      return true;
    }
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Basic ')) {
      return false;
    }
    final String decoded;
    try {
      decoded = utf8.decode(base64.decode(header.substring(6).trim()));
    } on FormatException {
      return false;
    }
    return decoded == '$user:$pass';
  }

  // ── 方法实现 ──────────────────────────────────────────────────────────────

  static const String _kAllowedMethods =
      'OPTIONS, GET, HEAD, PUT, MKCOL, PROPFIND, DELETE';

  Future<void> _options(HttpRequest request) async {
    request.response.headers.set('DAV', '1, 2');
    request.response.headers.set(HttpHeaders.allowHeader, _kAllowedMethods);
    await _empty(request.response, HttpStatus.ok);
  }

  Future<void> _propfind(HttpRequest request) async {
    final path = _normalize(request.uri.path);
    final entry = _store[path];
    if (entry == null) {
      await _plain(request.response, HttpStatus.notFound, 'Not Found');
      return;
    }
    // Depth：0=仅自身；1=自身+直接子级。infinity 按 1 处理（最小实现；
    // webdav_client_plus 只用 0/1，请求体 prop 列表忽略——恒回全属性）。
    final depthHeader = request.headers.value('Depth') ?? '1';
    final depth = depthHeader == '0' ? 0 : 1;
    final resources = <MapEntry<String, _Entry>>[MapEntry(path, entry)];
    if (depth == 1 && entry.isDir) {
      final prefix = path == '/' ? '/' : '$path/';
      for (final key in _store.keys) {
        if (key == path || !key.startsWith(prefix)) {
          continue;
        }
        final rest = key.substring(prefix.length);
        if (!rest.contains('/')) {
          resources.add(MapEntry(key, _store[key]!));
        }
      }
      resources.sort((a, b) => a.key.compareTo(b.key));
    }
    final xml = _multiStatusXml(resources);
    await _respond(
      request.response,
      HttpStatus.multiStatus,
      utf8.encode(xml),
      contentType: 'application/xml; charset=utf-8',
    );
  }

  String _multiStatusXml(List<MapEntry<String, _Entry>> resources) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln('<D:multistatus xmlns:D="DAV:">');
    for (final resource in resources) {
      final isDir = resource.value.isDir;
      buffer
        ..writeln(' <D:response>')
        ..writeln('  <D:href>${_href(resource.key, isDir)}</D:href>')
        ..writeln('  <D:propstat>')
        ..writeln('   <D:prop>');
      if (isDir) {
        buffer.writeln('    <D:resourcetype><D:collection/></D:resourcetype>');
      } else {
        buffer
          ..writeln('    <D:resourcetype/>')
          ..writeln(
            '    <D:getcontentlength>${resource.value.bytes.length}</D:getcontentlength>',
          );
      }
      buffer
        ..writeln(
          '    <D:getlastmodified>${HttpDate.format(resource.value.modified.toUtc())}</D:getlastmodified>',
        )
        ..writeln(
          '    <D:displayname>${_xmlEscape(_displayName(resource.key))}</D:displayname>',
        )
        ..writeln('   </D:prop>')
        ..writeln('   <D:status>HTTP/1.1 200 OK</D:status>')
        ..writeln('  </D:propstat>')
        ..writeln(' </D:response>');
    }
    buffer.write('</D:multistatus>');
    return buffer.toString();
  }

  /// href：逐段百分号编码，目录带尾 `/`（webdav_client_plus 解析器按 RFC 4918
  /// 处理 percent-encoding）。
  String _href(String path, bool isDir) {
    if (path == '/') {
      return '/';
    }
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    return isDir ? '$encoded/' : encoded;
  }

  String _displayName(String path) =>
      path == '/' ? '/' : path.substring(path.lastIndexOf('/') + 1);

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  Future<void> _get(HttpRequest request) async {
    final entry = _store[_normalize(request.uri.path)];
    if (entry == null || entry.isDir) {
      await _plain(request.response, HttpStatus.notFound, 'Not Found');
      return;
    }
    final response = request.response;
    response.headers.set(
      HttpHeaders.lastModifiedHeader,
      HttpDate.format(entry.modified.toUtc()),
    );
    await _respond(
      response,
      HttpStatus.ok,
      entry.bytes,
      contentType: 'application/octet-stream',
      headOnly: request.method == 'HEAD',
    );
  }

  Future<void> _put(HttpRequest request, Uint8List body) async {
    final path = _normalize(request.uri.path);
    if (path == '/') {
      await _plain(
        request.response,
        HttpStatus.methodNotAllowed,
        'Cannot PUT to root',
      );
      return;
    }
    final existing = _store[path];
    if (existing != null && existing.isDir) {
      await _plain(
        request.response,
        HttpStatus.methodNotAllowed,
        'Cannot PUT to a collection',
      );
      return;
    }
    // RFC 4918 §9.7.1：父集合缺失 → 409（客户端须先 MKCOL）。
    final parent = _store[_parentOf(path)];
    if (parent == null || !parent.isDir) {
      await _plain(
        request.response,
        HttpStatus.conflict,
        'Parent collection does not exist',
      );
      return;
    }
    final created = existing == null;
    _store[path] = _Entry.file(body, DateTime.now());
    await _empty(
      request.response,
      created ? HttpStatus.created : HttpStatus.noContent,
    );
  }

  Future<void> _mkcol(HttpRequest request) async {
    final path = _normalize(request.uri.path);
    if (path == '/') {
      await _plain(
        request.response,
        HttpStatus.methodNotAllowed,
        'Root already exists',
      );
      return;
    }
    if (_store.containsKey(path)) {
      // RFC 4918 §9.3：已存在 → 405（webdav_client_plus 视 405 为成功）。
      await _plain(
        request.response,
        HttpStatus.methodNotAllowed,
        'Collection already exists',
      );
      return;
    }
    final parent = _store[_parentOf(path)];
    if (parent == null || !parent.isDir) {
      await _plain(
        request.response,
        HttpStatus.conflict,
        'Parent collection does not exist',
      );
      return;
    }
    _store[path] = _Entry.dir(DateTime.now());
    await _empty(request.response, HttpStatus.created);
  }

  Future<void> _delete(HttpRequest request) async {
    final path = _normalize(request.uri.path);
    final entry = _store[path];
    if (entry == null) {
      await _plain(request.response, HttpStatus.notFound, 'Not Found');
      return;
    }
    final keys = _store.keys
        .where((key) => key == path || key.startsWith('$path/'))
        .toList(growable: false);
    for (final key in keys) {
      _store.remove(key);
    }
    await _empty(request.response, HttpStatus.noContent);
  }

  // ── 路径与响应助手 ────────────────────────────────────────────────────────

  /// 规范化：percent-decode、折叠空段（多余斜杠）、去尾斜杠（根除外）。
  String _normalize(String rawPath) {
    final decoded = Uri.decodeComponent(rawPath);
    final segments = decoded
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return '/';
    }
    return '/${segments.join('/')}';
  }

  String _parentOf(String path) {
    final index = path.lastIndexOf('/');
    return index <= 0 ? '/' : path.substring(0, index);
  }

  Future<void> _respond(
    HttpResponse response,
    int status,
    List<int> body, {
    required String contentType,
    bool headOnly = false,
  }) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.parse(contentType);
    response.contentLength = body.length;
    if (!headOnly) {
      response.add(body);
    }
    await response.close();
  }

  Future<void> _empty(HttpResponse response, int status) async {
    response.statusCode = status;
    await response.close();
  }

  Future<void> _plain(HttpResponse response, int status, String text) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.text;
    final body = utf8.encode(text);
    response.contentLength = body.length;
    response.add(body);
    await response.close();
  }
}

// ── 冒烟自检入口 ──────────────────────────────────────────────────────────────
// `dart run test/sync/webdav_fixture_server.dart`：
// 1) 匿名服务 curl 风格自打（HttpClient 直发真实协议报文）；
// 2) Basic Auth 校验（无凭据 401、错误凭据 401、正确凭据 207）；
// 3) 用 webdav_client_plus 真实客户端对拍（PROPFIND XML 解析兼容性即验收口径）。

Future<void> main() async {
  try {
    await _smokeAnonymous();
    await _smokeAuth();
    await _smokeWithRealClient();
  } on Object catch (e) {
    stdout.writeln('FAIL: $e');
    exitCode = 1;
    return;
  }
  stdout.writeln('OK');
}

/// 极简断言（冒烟口径：首败即停）。
void _check(bool condition, String label) {
  if (!condition) {
    throw StateError('自测断言失败：$label');
  }
}

Future<(int, Uint8List, HttpHeaders)> _send(
  HttpClient http,
  Uri base,
  String method,
  String path, {
  Uint8List? body,
  String? basic,
  String? depth,
}) async {
  final request = await http.openUrl(method, base.resolve(path));
  if (basic != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $basic');
  }
  if (depth != null) {
    request.headers.set('Depth', depth);
  }
  request.headers.contentType = ContentType.binary;
  if (body != null) {
    request.contentLength = body.length;
    request.add(body);
  }
  final response = await request.close();
  final builder = BytesBuilder(copy: false);
  await response.forEach(builder.add);
  return (response.statusCode, builder.takeBytes(), response.headers);
}

String _basic(String user, String pass) =>
    base64Encode(utf8.encode('$user:$pass'));

Uint8List _bytes(String text) => utf8.encode(text);

Future<void> _smokeAnonymous() async {
  final server = MiniWebDavServer();
  final base = await server.start();
  final http = HttpClient();
  try {
    // PUT：创建 201 / 覆盖 204 / 父目录缺失 409。
    var (status, _, _) = await _send(
      http,
      base,
      'PUT',
      '/hello.txt',
      body: _bytes('hello webdav'),
    );
    _check(status == 201, 'PUT 创建应 201，实际 $status');
    (status, _, _) = await _send(
      http,
      base,
      'PUT',
      '/hello.txt',
      body: _bytes('hello again'),
    );
    _check(status == 204, 'PUT 覆盖应 204，实际 $status');
    (status, _, _) = await _send(
      http,
      base,
      'PUT',
      '/nodir/x.txt',
      body: _bytes('x'),
    );
    _check(status == 409, 'PUT 父目录缺失应 409，实际 $status');

    // MKCOL：创建 201 / 重复 405 / 父目录缺失 409。
    (status, _, _) = await _send(http, base, 'MKCOL', '/music');
    _check(status == 201, 'MKCOL 应 201，实际 $status');
    (status, _, _) = await _send(http, base, 'MKCOL', '/music/');
    _check(status == 405, 'MKCOL 重复应 405，实际 $status');
    (status, _, _) = await _send(http, base, 'MKCOL', '/a/b');
    _check(status == 409, 'MKCOL 父目录缺失应 409，实际 $status');

    // 多级目录 + 嵌套文件。
    (status, _, _) = await _send(http, base, 'MKCOL', '/music/pop');
    _check(status == 201, 'MKCOL 子目录应 201，实际 $status');
    (status, _, _) = await _send(
      http,
      base,
      'PUT',
      '/music/pop/song.mp3',
      body: _bytes('MP3DATA'),
    );
    _check(status == 201, 'PUT 嵌套文件应 201，实际 $status');

    // PROPFIND：Depth 1 含子项，Depth 0 只有自身。
    var (s, bodyBytes, _) = await _send(
      http,
      base,
      'PROPFIND',
      '/',
      body: _bytes(_kPropfindBody),
    );
    final listing = utf8.decode(bodyBytes);
    _check(s == 207, 'PROPFIND / Depth1 应 207，实际 $s');
    _check(listing.contains('multistatus'), '响应应是 multistatus');
    _check(listing.contains('hello.txt'), 'Depth1 应含 hello.txt');
    _check(listing.contains('<D:collection/>'), '目录应标 collection');
    _check(
      listing.contains('<D:getcontentlength>11</D:getcontentlength>'),
      '应含 hello.txt 的 getcontentlength（11 字节）',
    );
    (s, bodyBytes, _) = await _send(
      http,
      base,
      'PROPFIND',
      '/music/pop',
      body: _bytes(_kPropfindBody),
    );
    final nestedListing = utf8.decode(bodyBytes);
    _check(
      s == 207 &&
          nestedListing.contains('<D:getcontentlength>7</D:getcontentlength>'),
      '嵌套目录 PROPFIND 应含 song.mp3 的 getcontentlength（7 字节）',
    );
    (s, bodyBytes, _) = await _send(
      http,
      base,
      'PROPFIND',
      '/',
      body: _bytes(_kPropfindBody),
      depth: '0',
    );
    final self = utf8.decode(bodyBytes);
    _check(s == 207, 'PROPFIND / Depth0 应 207，实际 $s');
    _check(
      self.contains('<D:response>') && !self.contains('hello.txt'),
      'Depth0 不应列出子项',
    );

    // GET：命中与缺失。
    var (gs, gb, _) = await _send(http, base, 'GET', '/hello.txt');
    _check(gs == 200 && utf8.decode(gb) == 'hello again', 'GET 应回 200+最新内容');
    (gs, _, _) = await _send(http, base, 'GET', '/missing.txt');
    _check(gs == 404, 'GET 缺失应 404，实际 $gs');

    // DELETE：删除后 404（客户端视 404 为成功）。
    (status, _, _) = await _send(http, base, 'DELETE', '/hello.txt');
    _check(status == 204, 'DELETE 应 204，实际 $status');
    (status, _, _) = await _send(http, base, 'GET', '/hello.txt');
    _check(status == 404, '删除后 GET 应 404，实际 $status');
    (status, _, _) = await _send(http, base, 'DELETE', '/hello.txt');
    _check(status == 404, 'DELETE 缺失应 404，实际 $status');
  } finally {
    http.close();
    await server.stop();
  }
  stdout.writeln('匿名冒烟通过：PUT/MKCOL/PROPFIND/GET/DELETE');
}

Future<void> _smokeAuth() async {
  final server = MiniWebDavServer();
  final base = await server.start(username: 'u1', password: 'p1');
  final http = HttpClient();
  try {
    var (status, _, headers) = await _send(http, base, 'PROPFIND', '/');
    _check(status == 401, '无凭据应 401，实际 $status');
    _check(
      headers.value(HttpHeaders.wwwAuthenticateHeader) != null,
      '401 应带 WWW-Authenticate',
    );
    (status, _, _) = await _send(
      http,
      base,
      'PROPFIND',
      '/',
      basic: _basic('u1', 'wrong'),
    );
    _check(status == 401, '错误凭据应 401，实际 $status');
    (status, _, _) = await _send(
      http,
      base,
      'PROPFIND',
      '/',
      basic: _basic('u1', 'p1'),
    );
    _check(status == 207, '正确凭据应 207，实际 $status');
  } finally {
    http.close();
    await server.stop();
  }
  stdout.writeln('Basic Auth 冒烟通过：401/401/207');
}

const String _kPropfindBody =
    '<?xml version="1.0" encoding="utf-8"?>'
    '<D:propfind xmlns:D="DAV:"><D:prop>'
    '<D:resourcetype/><D:getcontentlength/><D:getlastmodified/><D:displayname/>'
    '</D:prop></D:propfind>';

/// webdav_client_plus 真实客户端对拍：adapter 侧解析器能吃下本夹具的响应
/// （PROPFIND XML 兼容性即验收口径）。
Future<void> _smokeWithRealClient() async {
  final server = MiniWebDavServer();
  final base = await server.start(username: 'u2', password: 'p2');
  final client = WebdavClient.basicAuth(
    url: base.toString(),
    user: 'u2',
    pwd: 'p2',
  );
  try {
    await client.ping();

    final payload = Uint8List.fromList(
      List<int>.generate(1024, (i) => i % 256),
    );
    await client.write('/smoke/deep/a.bin', payload); // 自动逐级 MKCOL 父目录

    await client.mkdirAll('/smoke/sub');
    await client.write('/smoke/sub/b.txt', _bytes('B'));

    final files = await client.readDir('/smoke/');
    final names = files.map((f) => f.name).toSet();
    _check(names.contains('deep'), 'readDir 应解析出目录 deep');
    _check(names.contains('sub'), 'readDir 应解析出目录 sub');

    final nested = await client.readDir('/smoke/deep');
    _check(
      nested.length == 1 && nested.first.name == 'a.bin' && !nested.first.isDir,
      'readDir 应解析出文件 a.bin',
    );
    _check(
      nested.first.size == payload.length,
      'getcontentlength 应解析为 ${payload.length}',
    );
    _check(nested.first.modified != null, 'getlastmodified 应可解析');

    final fetched = await client.read('/smoke/deep/a.bin');
    _check(
      fetched.length == payload.length && fetched[255] == payload[255],
      'read 应回到原字节',
    );

    await client.remove('/smoke/deep/a.bin');
    final after = await client.readDir('/smoke/deep');
    _check(after.isEmpty, '删除后 readDir 应为空');
  } finally {
    // WebdavClient 无公开 close()——进程退出即释放连接。
    await server.stop();
  }
  stdout.writeln('webdav_client_plus 真实客户端对拍通过');
}
