// lib/services/data_transfer_service.dart
/// 局域网数据互传服务
/// 提供 HTTP Server 用于接收资源列表，支持跨设备传输配置数据
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DataTransferService {
  HttpServer? _server;
  int _port = 8188;
  String? _localIp;
  bool _isRunning = false;

  /// 接收到的资源列表回调
  final StreamController<List<Map<String, dynamic>>> _resourceController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  bool get isRunning => _isRunning;
  String? get localIp => _localIp;
  int get port => _port;
  String? get serverUrl => _localIp != null ? 'http://$_localIp:$_port' : null;
  Stream<List<Map<String, dynamic>>> get onResourceReceived => _resourceController.stream;

  /// 获取本机局域网 IP 地址
  Future<String?> getLocalIp() async {
    final interfaces = await NetworkInterface.list();
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return null;
  }

  /// 启动接收服务器
  Future<bool> startServer() async {
      if (_isRunning) return true;

      _localIp = await getLocalIp();
      if (_localIp == null) return false;

      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        _isRunning = true;

        _server!.listen((HttpRequest request) {
          _handleRequest(request);
        });
        return true;
      } catch (e) {
        _isRunning = false;
        return false;
      }
    }

  /// 停止服务器
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isRunning = false;
  }

  /// 处理 HTTP 请求
  void _handleRequest(HttpRequest request) {
    // CORS 支持
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      request.response.close();
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' && path == '/info') {
      // 返回服务信息
      _sendJson(request.response, {
        'device': Platform.localHostname,
        'version': '1.0.0',
        'ip': _localIp,
        'port': _port,
      });
    } else if (request.method == 'POST' && path == '/resources') {
      // 接收资源列表
      _receiveResources(request);
    } else {
      request.response.statusCode = 404;
      request.response.write('Not Found');
      request.response.close();
    }
  }

  /// 接收资源数据
  Future<void> _receiveResources(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // 返回成功响应
      _sendJson(request.response, {'status': 'ok', 'message': '接收成功'});

      // 解析资源列表
      if (data.containsKey('sources') && data['sources'] is List) {
        final sources = (data['sources'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _resourceController.add(sources);
      }
    } catch (e) {
      _sendJson(request.response, {'status': 'error', 'message': '数据格式错误'}, 400);
    }
  }

  /// 发送资源到接收端
  Future<bool> sendResources(String serverUrl, List<Map<String, dynamic>> sources) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$serverUrl/resources'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'sources': sources}));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 检查服务器是否可达
  Future<bool> checkServer(String serverUrl) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$serverUrl/info'));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _sendJson(HttpResponse response, Map<String, dynamic> data, [int statusCode = 200]) {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    response.close();
  }

  void dispose() {
    stopServer();
    _resourceController.close();
  }
}
