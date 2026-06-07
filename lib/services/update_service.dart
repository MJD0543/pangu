// lib/services/update_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 更新信息
class UpdateInfo {
  final String version;       // 远端版本号，如 "1.0.1"
  final String downloadUrl;    // 安装包下载地址
  final String? changelog;   // 更新日志
  final bool mandatory;        // 是否强制更新

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.changelog,
    this.mandatory = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      downloadUrl: json['url'] as String,
      changelog: json['changelog'] as String?,
      mandatory: json['mandatory'] as bool? ?? false,
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
  Future<UpdateInfo?> _checkGitHubReleases(String apiUrl) async {
    final resp = await _client.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String).replaceAll(RegExp(r'^v'), '');
    final body = data['body'] as String? ?? '';

    // 找第一个 exe 附件
    final assets = data['assets'] as List<dynamic>? ?? [];
    String? exeUrl;
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.exe')) {
        exeUrl = asset['browser_download_url'] as String?;
        break;
      }
    }
    if (exeUrl == null) return null;
    return UpdateInfo(
      version: tag,
      downloadUrl: exeUrl,
      changelog: body.isNotEmpty ? body : null,
      mandatory: false,
    );
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
