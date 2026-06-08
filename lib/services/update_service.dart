// lib/services/update_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 更新信息
class UpdateInfo {
  final String version;        // 远端版本号，如 "1.0.1"
  final String downloadUrl;    // 安装包下载地址
  final String? changelog;    // 更新日志
  final bool mandatory;        // 是否强制更新
  final String assetKind;      // "exe" | "apk" | "7z" | "unknown"

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.changelog,
    this.mandatory = false,
    this.assetKind = 'unknown',
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      downloadUrl: json['url'] as String,
      changelog: json['changelog'] as String?,
      mandatory: json['mandatory'] as bool? ?? false,
      assetKind: json['kind'] as String? ?? 'unknown',
    );
  }
}

/// 更新服务：检测更新、下载安装包
class UpdateService {
  final http.Client _client;

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// 检测更新
  /// [updateUrl] 可以是：
  ///   1. GitHub Releases API: https://api.github.com/repos/USER/REPO/releases/latest
  ///   2. 自定义 JSON: {"version":"1.0.1","url":"https://...","changelog":"..."}
  Future<UpdateInfo?> checkForUpdates(String updateUrl) async {
    final uri = Uri.parse(updateUrl);

    // 判断是否是 GitHub Releases API
    if (updateUrl.contains('api.github.com/repos/') && updateUrl.contains('/releases/latest')) {
      return _checkGitHubReleases(updateUrl);
    }

    // 自定义 JSON 格式
    final resp = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return UpdateInfo.fromJson(json);
  }

  /// 解析 GitHub Releases Latest API
  /// 按平台优先选择下载资产: Windows→exe, Android→apk, 兜底→7z
  Future<UpdateInfo?> _checkGitHubReleases(String apiUrl) async {
    final resp = await _client.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String).replaceAll(RegExp(r'^v'), '');
    final body = data['body'] as String? ?? '';

    final assets = data['assets'] as List<dynamic>? ?? [];
    if (assets.isEmpty) return null;

    // 平台感知: 按优先级匹配资产
    final asset = _pickBestAsset(assets);
    if (asset == null) return null;

    return UpdateInfo(
      version: tag,
      downloadUrl: asset['url'] as String,
      changelog: body.isNotEmpty ? body : null,
      mandatory: false,
      assetKind: asset['kind'] as String? ?? 'unknown',
    );
  }

  /// 从 GitHub Release Assets 中按平台选择最佳匹配合
  /// Windows 优先 exe > 7z, Android 优先 apk, 兜底取第一个
  Map<String, dynamic>? _pickBestAsset(List<dynamic> assets) {
    if (assets.isEmpty) return null;

    final isAndroid = Platform.isAndroid;
    final isWindows = Platform.isWindows;

    // 第一优先级: 精确平台匹配
    for (final raw in assets) {
      final a = raw as Map<String, dynamic>;
      final name = (a['name'] as String? ?? '').toLowerCase();
      final url = a['browser_download_url'] as String?;
      if (url == null) continue;

      if (isWindows && name.endsWith('.exe')) {
        return {'url': url, 'kind': 'exe'};
      }
      if (isAndroid && name.endsWith('.apk')) {
        return {'url': url, 'kind': 'apk'};
      }
    }

    // 第二优先级: 通用 7z 便携包 (Windows 备选)
    for (final raw in assets) {
      final a = raw as Map<String, dynamic>;
      final name = (a['name'] as String? ?? '').toLowerCase();
      final url = a['browser_download_url'] as String?;
      if (url == null) continue;

      if (isWindows && name.endsWith('.7z')) {
        return {'url': url, 'kind': '7z'};
      }
    }

    // 兜底: 返回第一个资产
    final first = assets[0] as Map<String, dynamic>;
    final firstName = (first['name'] as String? ?? '').toLowerCase();
    final firstUrl = first['browser_download_url'] as String?;
    if (firstUrl == null) return null;

    String kind = 'unknown';
    if (firstName.endsWith('.exe')) kind = 'exe';
    else if (firstName.endsWith('.apk')) kind = 'apk';
    else if (firstName.endsWith('.7z')) kind = '7z';

    return {'url': firstUrl, 'kind': kind};
  }

  /// 下载安装包，通过 [onProgress] 回调进度 (0.0 ~ 1.0)
  /// 返回下载后的本地文件路径
  Future<String> downloadUpdate(
    String downloadUrl, {
    required void Function(double progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = p.basename(Uri.parse(downloadUrl).path);
    final savePath = p.join(tempDir.path, fileName);

    final request = http.Request('GET', Uri.parse(downloadUrl));
    final response = await _client.send(request).timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('下载失败: HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    var receivedBytes = 0;

    final file = File(savePath);
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      } else {
        onProgress(-1); // 未知进度
      }
    }
    await sink.flush();
    await sink.close();

    return savePath;
  }

  void dispose() {
    _client.close();
  }
}
