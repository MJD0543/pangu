// lib/providers/update_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/update_service.dart';

enum UpdateStatus { idle, checking, available, downloading, downloaded, error }

class UpdateProvider extends ChangeNotifier {
  final UpdateService _service = UpdateService();

  UpdateStatus _status = UpdateStatus.idle;
  String _latestVersion = '';
  String _changelog = '';
  double _downloadProgress = 0.0;
  String _errorMessage = '';
  String _installerPath = '';
  bool _mandatory = false;

  // 更新检测地址（可配置）
  static const _kUpdateUrlKey = 'update_url';
  // 默认指向 GitHub Releases API，用户需替换为自己的仓库地址
  static const _kDefaultUpdateUrl =
      'https://api.github.com/repos/MJD0543/pangu/releases/latest';

  String? _updateUrl;

  String? get updateUrl => _updateUrl;
  bool get isDownloading => _status == UpdateStatus.downloading;
  UpdateStatus get status => _status;
  String get latestVersion => _latestVersion;
  String get changelog => _changelog;
  double get downloadProgress => _downloadProgress;
  String get errorMessage => _errorMessage;
  String get installerPath => _installerPath;
  bool get mandatory => _mandatory;

  UpdateProvider() {
    _loadUpdateUrl();
  }

  Future<void> _loadUpdateUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _updateUrl = prefs.getString(_kUpdateUrlKey);
    notifyListeners();
  }

  Future<void> setUpdateUrl(String url) async {
    _updateUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_updateUrl!.isEmpty) {
      await prefs.remove(_kUpdateUrlKey);
      _updateUrl = null;
    } else {
      await prefs.setString(_kUpdateUrlKey, _updateUrl!);
    }
    notifyListeners();
  }

  /// 检测更新（[silent]=true 时不报错，用于启动时静默检测）
  Future<void> checkForUpdates({bool silent = false}) async {
    final url = _updateUrl?.isNotEmpty == true
        ? _updateUrl!
        : _kDefaultUpdateUrl;

    _status = UpdateStatus.checking;
    if (!silent) notifyListeners();

    try {
      final info = await _service.checkForUpdates(url);
      if (info == null) {
        _status = UpdateStatus.idle;
        if (!silent) notifyListeners();
        return;
      }

      final pkg = await PackageInfo.fromPlatform();
      if (_isNewer(info.version, pkg.version)) {
        _latestVersion = info.version;
        _changelog = info.changelog ?? '';
        _mandatory = info.mandatory;
        _status = UpdateStatus.available;
      } else {
        _status = UpdateStatus.idle;
      }
    } catch (e) {
      if (!silent) {
        _status = UpdateStatus.error;
        _errorMessage = '检测更新失败: $e';
      } else {
        _status = UpdateStatus.idle;
      }
    }
    notifyListeners();
  }

  /// 下载更新包
  Future<void> downloadUpdate() async {
    final url = _updateUrl?.isNotEmpty == true
        ? _updateUrl!
        : _kDefaultUpdateUrl;
    if (url.isEmpty) return;

    _status = UpdateStatus.downloading;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final info = await _service.checkForUpdates(url);
      if (info == null) throw Exception('获取下载地址失败');

      _installerPath = await _service.downloadUpdate(
        info.downloadUrl,
        onProgress: (p) {
          _downloadProgress = p;
          notifyListeners();
        },
      );
      _status = UpdateStatus.downloaded;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = '下载失败: $e';
    }
    notifyListeners();
  }

  /// 安装更新：先写出一个启动安装包的批处理脚本，然后退出当前应用
  Future<void> installUpdate() async {
    if (_installerPath.isEmpty) return;
    try {
      final script = await _createUpdateScript(_installerPath);
      await Process.start(script, [], mode: ProcessStartMode.detached);
    } catch (_) {}
    exit(0);
  }

  /// 生成一个批处理脚本：等待 2 秒后运行安装包（此时主程序已退出）
  Future<String> _createUpdateScript(String exePath) async {
    final tempDir = await Directory.systemTemp.createTemp('pangu_update_');
    final scriptFile = File('${tempDir.path}\\run_installer.bat');
    final content = '''
@echo off
timeout /t 2 /nobreak >nul
"$exePath"
del "%~f0"
''';
    await scriptFile.writeAsString(content);
    return scriptFile.path;
  }

  /// 比较远端版本 [remote] 是否比 [local] 新
  bool _isNewer(String remote, String local) {
    final r = remote.split('.').map(int.tryParse).whereType<int>().toList();
    final l = local.split('.').map(int.tryParse).whereType<int>().toList();
    for (var i = 0; i < r.length; i++) {
      final rv = r[i];
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  void reset() {
    _status = UpdateStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
