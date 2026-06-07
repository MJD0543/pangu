// lib/screens/system/tvbox_subscribe_dialog.dart
//
// TVBOX 订阅导入对话框 —— 两步流程：
//   1. 输入 URL → 解析 JSON → 展示候选源列表（图标+名称+URL+类型）
//   2. 点击"开始导入" → 直接批量 upsert（不再逐条检测可用性）
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

class TvboxSubscribeDialog extends StatefulWidget {
  const TvboxSubscribeDialog({super.key});

  @override
  State<TvboxSubscribeDialog> createState() => _TvboxSubscribeDialogState();
}

class _TvboxSubscribeDialogState extends State<TvboxSubscribeDialog> {
  final _urlCtrl = TextEditingController();
  final _urlFocus = FocusNode();

  bool _isParsing = false;
  bool _isImporting = false;
  String _statusText = '';

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

  // ────────── 步骤1: 解析 TVBOX JSON ──────────
  Future<void> _parse() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isParsing = true;
      _statusText = '正在获取订阅内容...';
      _candidates = [];
    });

    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        _setStatus('获取失败，HTTP ${resp.statusCode}');
        return;
      }

      dynamic raw;
      try {
        raw = jsonDecode(resp.body);
      } catch (_) {
        _setStatus(S.tvboxParseError);
        return;
      }

      if (raw is! Map<String, dynamic>) {
        _setStatus(S.tvboxParseError);
        return;
      }

      final candidates = <_TvboxCandidate>[];

      // sites → 苹果CMS 影视源
      final sites = raw['sites'];
      if (sites is List) {
        for (final site in sites) {
          if (site is! Map<String, dynamic>) continue;
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
      }

      // lives → IPTV/电视源
      final lives = raw['lives'];
      if (lives is List) {
        for (final live in lives) {
          if (live is! Map<String, dynamic>) continue;
          final liveUrl = (live['url'] as String?) ?? '';
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
      }

      if (!mounted) return;
      if (candidates.isEmpty) {
        _setStatus(S.tvboxImportNoValidSource);
        return;
      }

      setState(() {
        _isParsing = false;
        _candidates = candidates;
        _statusText = '共找到 ${candidates.length} 个候选源，开始检测可用性...';
      });

      // 逐条检测可用性
      for (int i = 0; i < candidates.length; i++) {
        if (!mounted) return;
        final c = candidates[i];
        setState(() {
          c.isChecking = true;
          _statusText = '正在检测可用性 (${i + 1}/${candidates.length})...';
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
      final availableCount = candidates.where((c) => c.isAvailable == true).length;
      setState(() {
        _statusText = '检测完成：$availableCount/${candidates.length} 个可用';
      });
    } catch (e) {
      _setStatus('解析失败: $e');
    }
  }

  // ────────── 步骤2: 批量导入 ──────────
  Future<void> _startImport() async {
    if (_candidates.isEmpty) return;

    // 过滤出可用源
    final available = _candidates.where((c) => c.isAvailable == true).toList();
    if (available.isEmpty) {
      _setStatus('没有可用的源，请检查网络或源地址');
      return;
    }

    setState(() {
      _isImporting = true;
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
        _isImporting = false;
        _added = result['added'] ?? 0;
        _updated = result['updated'] ?? 0;
        _statusText = '导入完成：新增 $_added 个，覆盖 $_updated 个';
      });
      // 导入成功，延迟后关闭对话框返回
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      _setStatus('导入失败: $e');
    }
  }

  // ────────── 候选源检测状态图标 ──────────
  Widget _buildCheckStatus(_TvboxCandidate c, bool isMovie) {
    if (c.isChecking) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
      );
    }
    if (c.isAvailable == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          S.available,
          style: const TextStyle(
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
        child: Text(
          S.unavailable,
          style: const TextStyle(
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

  void _setStatus(String msg) {
    if (mounted) {
      setState(() {
        _isParsing = false;
        _isImporting = false;
        _statusText = msg;
      });
    }
  }

  // ────────── UI ──────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCandidates = _candidates.isNotEmpty;
    final finished = !_isParsing && !_isImporting && _statusText.contains('完成');

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
                      _isImporting ? null : () => Navigator.pop(context),
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
                    enabled: !_isParsing && !_isImporting,
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
                    onSubmitted: (_) => _parse(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isParsing || _isImporting ? null : _parse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isParsing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('解析', style: TextStyle(fontSize: 13)),
                ),
              ]),
            ),

            // ── Status Text ──
            if (_statusText.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(children: [
                  if (_isImporting)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor)),
                    ),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: finished
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
                      leading: SizedBox(
                        width: 32,
                        height: 32,
                        child: Image.asset(
                          isMovie
                              ? 'assets/icons/ic_apple_cms.png'
                              : 'assets/icons/ic_live.png',
                          fit: BoxFit.contain,
                        ),
                      ),
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
                      trailing: _buildCheckStatus(c, isMovie),
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
                      onPressed: _isImporting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(finished ? S.close : S.cancel),
                    ),
                  ),
                  if (!finished) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isImporting ? null : _startImport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isImporting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                '开始导入（${_candidates.where((c) => c.isAvailable == true).length}）',
                                style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ]),
              ),

            // ── Bottom when no candidates yet ──
            if (!hasCandidates && !_isParsing)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  S.tvboxImportNoValidSource,
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

class _TvboxCandidate {
  final String name;
  final String url;
  final SourceType type;
  bool isChecking = false;
  bool? isAvailable;
  _TvboxCandidate(
      {required this.name, required this.url, required this.type});
}
