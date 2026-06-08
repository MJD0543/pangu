// lib/screens/system/tvbox_subscribe_dialog.dart
//
// TVBOX 订阅导入对话框 —— 智能识别 + 两步流程：
//   1. 输入 URL → 点击"解析" → 智能识别格式 → 展示候选源列表 + 自动检测可用性
//   2. 检测完成后 → 点击"开始导入" → 批量 upsert 至资源库
//
// 智能识别能力：
//   - TVBOX JSON (sites / lives) → 影视源 + 电视源
//   - M3U/M3U8 直播源 → 电视源（URL 可直接作为频道源）
//   - TXT 源列表 (name,url 格式) → 根据 URL 特征自动分类
//   - 纯文本 URL 列表 → 逐行解析，智能分类
//   - Codeberg/GitHub Raw 等代码仓源 → 智能转换
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../models/source_model.dart';
import '../../providers/app_provider.dart';
import '../../services/movie_api_service.dart';
import '../../services/tv_source_service.dart';

/// 内容格式枚举
enum _ContentFormat { json, m3u, txt, plain }

/// 解析/检测/导入 状态机
enum _DialogPhase { input, parsing, detecting, ready, importing }

class TvboxSubscribeDialog extends StatefulWidget {
  const TvboxSubscribeDialog({super.key});

  @override
  State<TvboxSubscribeDialog> createState() => _TvboxSubscribeDialogState();
}

class _TvboxSubscribeDialogState extends State<TvboxSubscribeDialog> {
  final _urlCtrl = TextEditingController();
  final _urlFocus = FocusNode();

  _DialogPhase _phase = _DialogPhase.input;
  String _statusText = '';
  String _formatLabel = '';

  @override
  void initState() {
    super.initState();
    _urlFocus.addListener(() => setState(() {}));
  }

  /// 解析出来的候选源列表
  List<_TvboxCandidate> _candidates = [];
  int _added = 0;
  int _updated = 0;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  // 核心能力：智能 URL 格式识别
  // ════════════════════════════════════════════════════════════════

  /// 根据 URL 后缀预判格式类型
  _ContentFormat _guessFormatByUrl(String url) {
    final lower = url.toLowerCase();
    // 去除查询参数后的路径
    final pathOnly = Uri.tryParse(url)?.path.toLowerCase() ?? lower;
    if (pathOnly.endsWith('.json')) return _ContentFormat.json;
    if (pathOnly.endsWith('.m3u8') || pathOnly.endsWith('.m3u')) {
      return _ContentFormat.m3u;
    }
    if (pathOnly.endsWith('.txt')) return _ContentFormat.txt;
    // 无法从后缀判断 → 需下载内容后智能识别
    return _ContentFormat.plain;
  }

  /// 根据内容智能识别格式
  _ContentFormat _detectFormatByContent(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return _ContentFormat.plain;

    // 1) 尝试 JSON（兼容 TVBOX / EchoTV / iptv 等多种方言）
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map<String, dynamic> &&
          (parsed.containsKey('sites') ||
           parsed.containsKey('lives') ||
           parsed.containsKey('api_site') ||
           parsed.containsKey('site_name') ||
           parsed.containsKey('iptv'))) {
        return _ContentFormat.json;
      }
    } catch (_) {
      // not JSON, continue
    }

    // 2) M3U
    if (trimmed.startsWith('#EXTM3U')) return _ContentFormat.m3u;

    // 3) TXT 格式：包含逗号分隔的 name,url 行
    final lines = trimmed.split('\n');
    int txtLines = 0;
    for (final line in lines.take(20)) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      if (l.contains(',') &&
          (l.contains('http://') || l.contains('https://'))) {
        txtLines++;
      }
    }
    if (txtLines >= 2) return _ContentFormat.txt;

    // 4) 纯文本 URL 列表
    return _ContentFormat.plain;
  }

  /// 智能分类：根据 URL 后缀判断源类型
  SourceType _classifyUrl(String url) {
    final lower = url.toLowerCase();
    final pathOnly = Uri.tryParse(url)?.path.toLowerCase() ?? lower;
    // 电视源特征
    if (pathOnly.endsWith('.m3u8') ||
        pathOnly.endsWith('.m3u') ||
        pathOnly.endsWith('.m3u.txt') ||
        pathOnly.contains('.m3u8?') ||
        pathOnly.contains('.m3u?') ||
        lower.contains('iptv') ||
        lower.contains('live') ||
        lower.contains('tv/') ||
        lower.contains('playlist')) {
      return SourceType.tv;
    }
    // 苹果CMS 特征
    if (lower.contains('provide/vod') ||
        lower.contains('api.php') ||
        lower.contains('index.php') ||
        lower.contains('/api/') ||
        lower.contains('vod')) {
      return SourceType.movie;
    }
    return SourceType.movie; // 默认影视源
  }

  // ════════════════════════════════════════════════════════════════
  // 步骤1: 智能解析（格式识别 + 候选提取）
  // ════════════════════════════════════════════════════════════════

  Future<void> _parse() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _phase = _DialogPhase.parsing;
      _statusText = S.tvboxSmartConvert;
      _candidates = [];
      _formatLabel = '';
    });

    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        _setError('获取失败，HTTP ${resp.statusCode}');
        return;
      }

      final body = resp.body;
      final guessedFormat = _guessFormatByUrl(url);
      final actualFormat = _detectFormatByContent(body);

      // 优先使用内容检测结果，URL 后缀仅作 fallback
      final format = (actualFormat != _ContentFormat.plain || guessedFormat == _ContentFormat.plain)
          ? actualFormat
          : guessedFormat;

      setState(() {
        _formatLabel = _formatToString(format);
        _statusText = '已识别：$_formatLabel，正在提取源...';
      });

      final candidates = await _extractCandidates(format, body, url);

      if (!mounted) return;
      if (candidates.isEmpty) {
        _setError(S.tvboxImportNoValidSource);
        return;
      }

      setState(() {
        _phase = _DialogPhase.detecting;
        _candidates = candidates;
        _statusText = '${S.tvboxDetecting} (0/${candidates.length})...';
      });

      // ── 自动开始逐条检测可用性 ──
      await _detectAll(candidates);

    } catch (e) {
      _setError('解析失败: $e');
    }
  }

  /// 根据格式提取候选源
  Future<List<_TvboxCandidate>> _extractCandidates(
      _ContentFormat format, String body, String sourceUrl) async {
    switch (format) {
      case _ContentFormat.json:
        return _parseTvboxJson(body);
      case _ContentFormat.m3u:
        return _parseM3uAsSource(body, sourceUrl);
      case _ContentFormat.txt:
        return _parseTxtSource(body);
      case _ContentFormat.plain:
        return _parsePlainUrlList(body);
    }
  }

  // ── TVBOX JSON 解析（兼容多种方言） ──
  List<_TvboxCandidate> _parseTvboxJson(String body) {
    final candidates = <_TvboxCandidate>[];
    try {
      final raw = jsonDecode(body);
      if (raw is! Map<String, dynamic>) return candidates;

      // ── 辅助：统一遍历 List/Map 的 values ──
      Iterable<dynamic> _values(dynamic src) {
        if (src is List) return src;
        if (src is Map) return src.values;
        return const [];
      }

      // ── 辅助：跳过 disabled ──
      bool _skip(dynamic item) {
        if (item is! Map<String, dynamic>) return true;
        // disabled 字段（EchoTV 风格）
        if (item['disabled'] == true) return true;
        // isActive 字段（TVBOX iptv 风格）
        if (item['isActive'] == false) return true;
        return false;
      }

      // ── sites / api_site → 影视源（List 或 Map） ──
      final sites = raw['sites'] ?? raw['api_site'];
      for (final site in _values(sites)) {
        if (_skip(site)) continue;
        final api = (site['api'] as String?) ?? '';
        final name = (site['name'] as String?) ??
            (site['key'] as String?) ??
            '';
        if (api.isEmpty || api == '0') continue;
        if (!api.startsWith('http')) continue;
        candidates.add(_TvboxCandidate(
          name: name.isNotEmpty ? name : Uri.tryParse(api)?.host ?? api,
          url: api,
          type: SourceType.movie,
        ));
      }

      // ── lives → 电视源（List 或 Map，EchoTV 用 Map） ──
      final lives = raw['lives'];
      for (final live in _values(lives)) {
        if (_skip(live)) continue;
        // 优先 url（.m3u 直播流），其次 api
        final liveUrl = (live['url'] as String?) ?? (live['api'] as String?) ?? '';
        final liveName = (live['name'] as String?) ?? '';
        if (liveUrl.isNotEmpty && liveUrl.startsWith('http')) {
          candidates.add(_TvboxCandidate(
            name: liveName.isNotEmpty
                ? liveName
                : Uri.tryParse(liveUrl)?.host ?? liveUrl,
            url: liveUrl,
            type: SourceType.tv,
          ));
        }
        // 嵌套 channels
        final channels = live['channels'];
        if (channels is List) {
          for (final ch in channels) {
            if (ch is! Map<String, dynamic>) continue;
            final chUrls = ch['urls'];
            if (chUrls is List) {
              for (final u in chUrls) {
                if (u is String && u.startsWith('http')) {
                  candidates.add(_TvboxCandidate(
                    name: (ch['name'] as String?) ?? liveName,
                    url: u,
                    type: SourceType.tv,
                  ));
                }
              }
            }
          }
        }
      }

      // ── iptv → 电视源（List，含 .m3u/.txt 直播流） ──
      final iptv = raw['iptv'];
      if (iptv is List) {
        for (final item in iptv) {
          if (_skip(item)) continue;
          final iptvUrl = (item['url'] as String?) ?? '';
          final iptvName = (item['name'] as String?) ?? '';
          if (iptvUrl.isEmpty || !iptvUrl.startsWith('http')) continue;
          candidates.add(_TvboxCandidate(
            name: iptvName.isNotEmpty
                ? iptvName
                : Uri.tryParse(iptvUrl)?.host ?? iptvUrl,
            url: iptvUrl,
            type: SourceType.tv,
          ));
        }
      }
    } catch (_) {}
    return candidates;
  }

  // ── M3U → 电视源（整文件作为一个源） ──
  List<_TvboxCandidate> _parseM3uAsSource(String body, String sourceUrl) {
    // M3U 源：如果通过 URL 访问，则作为单个电视源
    // 提取 #EXTM3U 中的元数据获取名称
    String name = Uri.tryParse(sourceUrl)?.host ?? sourceUrl;
    final firstLine = body.split('\n').firstWhere(
        (l) => l.trim().startsWith('#EXTINF:'),
        orElse: () => '');
    if (firstLine.isNotEmpty) {
      // 尝试提取名称
      final commaIdx = firstLine.lastIndexOf(',');
      if (commaIdx >= 0 && commaIdx < firstLine.length - 1) {
        final n = firstLine.substring(commaIdx + 1).trim();
        if (n.isNotEmpty) name = n;
      }
    }
    return [
      _TvboxCandidate(name: name, url: sourceUrl, type: SourceType.tv),
    ];
  }

  // ── TXT 源列表 (name,url 格式) ──
  List<_TvboxCandidate> _parseTxtSource(String body) {
    final candidates = <_TvboxCandidate>[];
    final lines = body.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }
      // 格式: name,url 或 name,url,type
      final parts = line.split(',');
      if (parts.length < 2) continue;

      final name = parts[0].trim();
      final url = parts[1].trim();
      if (url.isEmpty || !url.startsWith('http')) continue;

      // 解析类型（如果有第三列）
      final SourceType type;
      if (parts.length >= 3) {
        final typeStr = parts[2].trim();
        type = (typeStr == '1' || typeStr.toLowerCase() == 'tv')
            ? SourceType.tv
            : SourceType.movie;
      } else {
        type = _classifyUrl(url);
      }

      candidates.add(_TvboxCandidate(
        name: name.isNotEmpty ? name : Uri.tryParse(url)?.host ?? url,
        url: url,
        type: type,
      ));
    }
    return candidates;
  }

  // ── 纯文本 URL 列表（每行一个 URL） ──
  List<_TvboxCandidate> _parsePlainUrlList(String body) {
    final candidates = <_TvboxCandidate>[];
    final seen = <String>{};
    final lines = body.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }
      // 检测是否是 URL
      if (!line.startsWith('http://') && !line.startsWith('https://')) {
        continue;
      }
      // 尝试解析为 JSON URL（可能内嵌 JSON）
      if (line.toLowerCase().endsWith('.json')) {
        // 跳过 JSON URL，视作下一级订阅（递归太危险，标记不可用让用户判断）
      }
      if (seen.contains(line)) continue;
      seen.add(line);

      final type = _classifyUrl(line);
      candidates.add(_TvboxCandidate(
        name: Uri.tryParse(line)?.host ?? line,
        url: line,
        type: type,
      ));
    }
    return candidates;
  }

  // ════════════════════════════════════════════════════════════════
  // 步骤2: 逐条检测可用性
  // ════════════════════════════════════════════════════════════════

  Future<void> _detectAll(List<_TvboxCandidate> candidates) async {
    for (int i = 0; i < candidates.length; i++) {
      if (!mounted) return;
      final c = candidates[i];
      setState(() {
        c.isChecking = true;
        _statusText = '${S.tvboxDetecting} (${i + 1}/${candidates.length})...';
      });

      final bool available;
      if (c.type == SourceType.movie) {
        available = await MovieApiService().validateMovieSource(c.url);
      } else {
        available = await TvSourceService().validateTvSource(c.url);
      }

      if (!mounted) return;
      setState(() {
        c.isChecking = false;
        c.isAvailable = available;
      });
    }

    if (!mounted) return;
    final availableCount =
        candidates.where((c) => c.isAvailable == true).length;
    setState(() {
      _phase = _DialogPhase.ready;
      _statusText =
          '${S.tvboxDetectDone}：$availableCount/${candidates.length} ${S.available}';
    });
  }

  // ════════════════════════════════════════════════════════════════
  // 步骤3: 批量导入
  // ════════════════════════════════════════════════════════════════

  Future<void> _startImport() async {
    if (_candidates.isEmpty) return;

    final available =
        _candidates.where((c) => c.isAvailable == true).toList();
    if (available.isEmpty) {
      _setError('没有可用的源，请检查网络或源地址');
      return;
    }

    setState(() {
      _phase = _DialogPhase.importing;
      _added = 0;
      _updated = 0;
      _statusText = '正在批量导入...';
    });

    if (!mounted) return;
    final prov = context.read<SourceProvider>();

    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final sources = <VideoSource>[];
      for (int i = 0; i < available.length; i++) {
        final c = available[i];
        sources.add(VideoSource(
          id: '${nowMs}_$i',
          name: c.name,
          url: c.url,
          type: c.type,
          isAvailable: true,
          lastChecked: DateTime.now(),
        ));
      }
      final result = await prov.upsertSources(sources);

      if (!mounted) return;
      setState(() {
        _phase = _DialogPhase.ready; // 保持 ready 状态展示结果
        _added = result['added'] ?? 0;
        _updated = result['updated'] ?? 0;
        _statusText = '导入完成：新增 $_added 个，覆盖 $_updated 个';
      });
      // 导入成功，延迟后关闭对话框返回
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      _setError('导入失败: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // UI 辅助方法
  // ════════════════════════════════════════════════════════════════

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _phase = _DialogPhase.input;
        _statusText = msg;
      });
    }
  }

  String _formatToString(_ContentFormat f) {
    switch (f) {
      case _ContentFormat.json:
        return S.tvboxFormatJson;
      case _ContentFormat.m3u:
        return S.tvboxFormatM3u;
      case _ContentFormat.txt:
        return S.tvboxFormatTxt;
      case _ContentFormat.plain:
        return S.tvboxFormatPlain;
    }
  }

  /// 候选源图标（根据类型动态切换）
  Widget _buildSourceIcon(_TvboxCandidate c) {
    final isMovie = c.type == SourceType.movie;
    return SizedBox(
      width: 32,
      height: 32,
      child: Image.asset(
        isMovie ? 'assets/icons/ic_apple_cms.png' : 'assets/icons/ic_live.png',
        fit: BoxFit.contain,
      ),
    );
  }

  /// 检测状态指示器
  Widget _buildCheckStatus(_TvboxCandidate c) {
    if (c.isChecking) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppTheme.primaryColor),
      );
    }
    if (c.isAvailable == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          S.available,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.successColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (c.isAvailable == false) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          S.unavailable,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    // 还没开始检测
    return const SizedBox.shrink();
  }

  // ════════════════════════════════════════════════════════════════
  // 主 UI
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCandidates = _candidates.isNotEmpty;
    final isReady = _phase == _DialogPhase.ready;
    final isWorking =
        _phase == _DialogPhase.parsing || _phase == _DialogPhase.detecting;
    final isImporting = _phase == _DialogPhase.importing;
    final canImport = isReady && !isImporting;
    final availableCount =
        _candidates.where((c) => c.isAvailable == true).length;
    final canParse =
        _phase == _DialogPhase.input && _urlCtrl.text.trim().isNotEmpty;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.subscriptions_outlined,
                      color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    S.tvboxSubscribe,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed:
                      isImporting ? null : () => Navigator.pop(context),
                ),
              ]),
            ),

            // ── URL Input + Parse Button ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    focusNode: _urlFocus,
                    enabled: !isWorking && !isImporting,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: S.tvboxSubscribeHint,
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(_urlFocus.hasFocus ? 0.0 : 0.35),
                      ),
                      prefixIcon: const Icon(Icons.link, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkCard : AppTheme.lightBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: canParse ? (_) => _parse() : null,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: canParse ? _parse : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.primaryColor.withOpacity(0.4),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isWorking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text(S.tvboxParseBtn,
                          style: TextStyle(fontSize: 13)),
                ),
              ]),
            ),

            // ── 格式识别标签 ──
            if (_formatLabel.isNotEmpty && hasCandidates)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${_candidates.length} 个',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                  ),
                ]),
              ),

            // ── Status Text ──
            if (_statusText.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(children: [
                  if (isWorking || isImporting)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor)),
                    ),
                  if (isReady)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle,
                          size: 16, color: AppTheme.successColor),
                    ),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isReady
                            ? AppTheme.successColor
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                      ),
                    ),
                  ),
                ]),
              ),

            // ── Candidate List ──
            if (hasCandidates)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = _candidates[i];
                    final isMovie = c.type == SourceType.movie;
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      leading: _buildSourceIcon(c),
                      title: Text(
                        c.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.url,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.45)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isMovie
                                  ? const Color(0xFF4CAF50).withOpacity(0.12)
                                  : const Color(0xFF2196F3).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isMovie ? S.movieSource : S.tvSource,
                              style: TextStyle(
                                fontSize: 9,
                                color: isMovie
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF2196F3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: _buildCheckStatus(c),
                    );
                  },
                ),
              ),

            // ── Bottom Buttons ──
            if (hasCandidates)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isImporting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(isReady ? S.close : S.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: canImport ? _startImport : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppTheme.primaryColor.withOpacity(0.35),
                        disabledForegroundColor: Colors.white54,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isImporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              canImport
                                  ? '${S.tvboxImportStart}（$availableCount）'
                                  : S.tvboxPleaseWait,
                              style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ]),
              ),

            // ── Bottom when no candidates yet ──
            if (!hasCandidates && !isWorking)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  _statusText.isEmpty
                      ? S.tvboxImportNoValidSource
                      : _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 候选源数据类
class _TvboxCandidate {
  final String name;
  final String url;
  final SourceType type;
  bool isChecking = false;
  bool? isAvailable;
  _TvboxCandidate(
      {required this.name, required this.url, required this.type});
}
