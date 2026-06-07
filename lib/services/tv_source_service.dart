// lib/services/tv_source_service.dart
import 'package:http/http.dart' as http;
import '../models/source_model.dart';

class TvSourceService {
  static final TvSourceService _i = TvSourceService._();
  factory TvSourceService() => _i;
  TvSourceService._();

  static const Duration _timeout = Duration(seconds: 15);

  // 验证电视源有效性（URL格式）
  Future<bool> validateTvSource(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) return false;
      final content = resp.body;
      // 检查是否是M3U或TXT格式的频道列表
      return _isValidTvContent(content);
    } catch (_) {
      return false;
    }
  }

  bool _isValidTvContent(String content) {
    if (content.trim().isEmpty) return false;
    if (content.startsWith('#EXTM3U')) return true;
    // 检查TXT格式：频道名,URL
    final lines = content.split('\n');
    int validLines = 0;
    for (final line in lines.take(20)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.contains(',') && 
          (trimmed.contains('http://') || trimmed.contains('https://'))) {
        validLines++;
      }
    }
    return validLines > 0;
  }

  // 解析TV源内容（URL or 本地路径内容）
  Future<List<TvChannel>> parseFromUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return [];
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      return parseContent(resp.body);
    } catch (_) {
      return [];
    }
  }

  List<TvChannel> parseContent(String content) {
    if (content.trim().startsWith('#EXTM3U')) {
      return _parseM3U(content);
    } else {
      return _parseTxt(content);
    }
  }

  List<TvChannel> _parseM3U(String content) {
    final channels = <TvChannel>[];
    final lines = content.split('\n');
    String? currentName, currentGroup, currentLogo;
    
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('#EXTINF:')) {
        currentName = null; currentGroup = null; currentLogo = null;
        // 解析 tvg-name, group-title, tvg-logo
        final nameMatch = RegExp(r'tvg-name="([^"]*)"').firstMatch(line);
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        // 最后一个逗号后面是频道名
        final commaIdx = line.lastIndexOf(',');
        if (commaIdx >= 0 && commaIdx < line.length - 1) {
          currentName = line.substring(commaIdx + 1).trim();
        }
        if (nameMatch != null) currentName = nameMatch.group(1);
        currentGroup = groupMatch?.group(1);
        currentLogo = logoMatch?.group(1);
      } else if (line.isNotEmpty && !line.startsWith('#') && currentName != null) {
        channels.add(TvChannel(
          name: currentName,
          url: line,
          group: currentGroup,
          logo: currentLogo,
        ));
        currentName = null;
      }
    }
    return channels;
  }

  List<TvChannel> _parseTxt(String content) {
    final channels = <TvChannel>[];
    String? currentGroup;
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      // 分组标识符，如 "央视,#genre#"
      if (line.endsWith('#genre#')) {
        currentGroup = line.replaceAll(',#genre#', '').trim();
        continue;
      }
      // 频道行: 频道名,URL
      final commaIdx = line.indexOf(',');
      if (commaIdx > 0) {
        final name = line.substring(0, commaIdx).trim();
        final url = line.substring(commaIdx + 1).trim();
        if (url.startsWith('http') || url.startsWith('rtmp') || url.startsWith('rtsp')) {
          channels.add(TvChannel(name: name, url: url, group: currentGroup));
        }
      }
    }
    return channels;
  }
}
