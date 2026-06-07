// lib/screens/movie/movie_player_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_provider.dart';
import '../../models/source_model.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../widgets/video_player_widget.dart';

/// 缓存桌面端判断，避免每次 build 重复计算
final bool _isDesktop = (() {
  try {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  } catch (_) {
    return false;
  }
})();

class MoviePlayerScreen extends StatefulWidget {
  final int movieId;
  final String movieName;
  final String? pic;
  final String apiUrl;
  final int initialEpisodeIndex;
  final int initialProgressSeconds;
  final String? heroTag;

  const MoviePlayerScreen({
    super.key,
    required this.movieId,
    required this.movieName,
    this.pic,
    required this.apiUrl,
    this.initialEpisodeIndex = 0,
    this.initialProgressSeconds = 0,
    this.heroTag,
  });

  @override
  State<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<MoviePlayerScreen> {
  MovieDetail? _detail;
  bool _loading = true;
  String? _error;
  int _selectedGroupIndex = 0;
  int _selectedEpisodeIndex = 0;
  bool _showDetailPanel = true;
  int _lastReportedProgress = 0;
  int _lastReportedDuration = 0;
  HistoryProvider? _historyProvider;
  SourceProvider? _sourceProvider;

  @override
  void initState() {
    super.initState();
    _selectedEpisodeIndex = widget.initialEpisodeIndex;
    _loadDetail();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _historyProvider ??= context.read<HistoryProvider>();
    _sourceProvider ??= context.read<SourceProvider>();
  }

  @override
  void dispose() {
    _saveHistory();
    super.dispose();
  }

  void _saveHistory() {
    if (_lastReportedDuration <= 0 || _historyProvider == null) return;
    final src = _sourceProvider?.activeMovieSource;
    final eps = _currentGroupEpisodes;
    final epName = eps.isNotEmpty && _selectedEpisodeIndex < eps.length
        ? eps[_selectedEpisodeIndex].name
        : S.unknownEpisode;
    _historyProvider!.addHistory(WatchHistory(
      // id: 0 让 SQLite AUTOINCREMENT 自动分配，避免时间戳 ID 冲突
      movieId: widget.movieId,
      movieName: widget.movieName,
      pic: widget.pic,
      apiUrl: widget.apiUrl,
      sourceName: src?.name ?? '未知源',
      episodeName: epName,
      episodeIndex: _selectedEpisodeIndex,
      progressSeconds: _lastReportedProgress,
      totalSeconds: _lastReportedDuration,
      watchedAt: DateTime.now(),
    ));
  }

  Future<void> _loadDetail() async {
    try {
      final api = context.read<MovieProvider>();
      final detail = await api.getDetail(widget.apiUrl, widget.movieId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  List<Episode> get _currentGroupEpisodes {
    if (_detail == null || _detail!.playGroups.isEmpty) return [];
    if (_selectedGroupIndex >= _detail!.playGroups.length) return [];
    return _detail!.playGroups[_selectedGroupIndex].episodes;
  }

  String? get _currentPlayUrl {
    final eps = _currentGroupEpisodes;
    if (eps.isEmpty) return null;
    if (_selectedEpisodeIndex >= eps.length) return null;
    return eps[_selectedEpisodeIndex].url;
  }

  String get _currentEpisodeName {
    final eps = _currentGroupEpisodes;
    if (eps.isEmpty) return '';
    if (_selectedEpisodeIndex >= eps.length) return '';
    return eps[_selectedEpisodeIndex].name;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.accentColor),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDetail,
                child: Text(S.retry),
              ),
            ],
          ),
        ),
      );
    }

    final url = _currentPlayUrl;
    final isWide = MediaQuery.of(context).size.width > 900;

    Widget content = Stack(
      children: [
        // Main content row
        Row(
          children: [
            // Left: Video player area (fill full available space)
            Expanded(
              child: url != null && url.isNotEmpty
                ? VideoPlayerWidget(
                    url: url,
                    title: '${widget.movieName} - $_currentEpisodeName',
                    episodes: _currentGroupEpisodes,
                    currentEpisodeIndex: _selectedEpisodeIndex,
                    onEpisodeChanged: (i) {
                      _saveHistory();
                      setState(() => _selectedEpisodeIndex = i);
                    },
                    initialProgressSeconds: _selectedEpisodeIndex == widget.initialEpisodeIndex
                        ? widget.initialProgressSeconds
                        : 0,
                    onProgressChanged: (pos, dur) {
                      _lastReportedProgress = pos;
                      _lastReportedDuration = dur;
                    },
                  )
                : Center(
                    child: Text(S.noPlayUrl, style: const TextStyle(color: Colors.white54)),
                  ),
            ),
            // Right: Detail panel with slide-in animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: (_showDetailPanel && isWide) ? 320 : 0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFF2E2E35))),
                color: Color(0xFF111111),
              ),
              child: (_showDetailPanel && isWide)
                  ? _buildDetailPanel(context)
                  : null,
            ),
          ],
        ),
        // Toggle detail panel button (centered vertically on the divider)
        if (isWide)
          Positioned(
            right: _showDetailPanel ? 320 : 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildDetailToggleButton(),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isDesktop
        ? content // Desktop: no SafeArea — avoids title-bar padding clipping video
        : SafeArea(child: content),
      // Bottom sheet for detail on narrow screens
      floatingActionButton: !isWide
        ? FloatingActionButton.small(
            onPressed: () => _showMobileDetailSheet(context),
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.list, color: Colors.white, size: 20),
          )
        : null,
    );
  }

  Widget _buildDetailPanel(BuildContext context) {
    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Poster + basic info header
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster thumbnail — hero animation target
              if (detail.pic != null && detail.pic!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Hero(
                    tag: widget.heroTag ?? 'poster_${widget.movieId}',
                    child: CachedNetworkImage(
                      imageUrl: detail.pic!,
                      width: 80, height: 110,
                      fit: BoxFit.cover,
                      memCacheWidth: 160, // 限制内存缓存尺寸
                      placeholder: (_, __) => Container(
                        width: 80, height: 110,
                        color: AppTheme.darkCard,
                        child: const Icon(Icons.movie, color: Colors.white24),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 80, height: 110,
                        color: AppTheme.darkCard,
                        child: const Icon(Icons.movie, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (detail.typeName != null)
                          _metaTag(detail.typeName!),
                        if (detail.year != null)
                          _metaTag(detail.year!),
                        if (detail.score != null && detail.score! > 0)
                          _metaTag('${detail.score!.toStringAsFixed(1)}分', color: const Color(0xFFFFB800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (detail.director != null && detail.director!.isNotEmpty)
                      Text(
                        S.formatDirector(detail.director!),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (detail.actor != null && detail.actor!.isNotEmpty)
                      Text(
                        S.formatActor(detail.actor!),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF2E2E35), height: 1),
        // Synopsis
        if (detail.description != null && detail.description!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.synopsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  detail.description!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        if (detail.description != null && detail.description!.isNotEmpty)
          const Divider(color: Color(0xFF2E2E35), height: 1),
        // Episode selector
        Expanded(
          child: _buildEpisodeSelector(context),
        ),
      ],
    );
  }

  Widget _metaTag(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color ?? AppTheme.primaryColor, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildDetailToggleButton() {
    return InkWell(
      onTap: () => setState(() => _showDetailPanel = !_showDetailPanel),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 20,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2E2E35),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          _showDetailPanel ? Icons.chevron_right : Icons.chevron_left,
          size: 16,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildEpisodeSelector(BuildContext context) {
    final groups = _detail?.playGroups ?? [];
    if (groups.isEmpty) {
      return Center(
        child: Text(S.noEpisodes, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }

    return Column(
      children: [
        // Group tabs
        if (groups.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: groups.asMap().entries.map((e) {
                  final sel = e.key == _selectedGroupIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedGroupIndex = e.key;
                        _selectedEpisodeIndex = 0;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primaryColor : Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          e.value.name,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        // Episode count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.formatEpisodeCount(_currentGroupEpisodes.length),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        // Episode grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 70,
              mainAxisExtent: 34,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: _currentGroupEpisodes.length,
            itemBuilder: (_, i) {
              final isSel = i == _selectedEpisodeIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedEpisodeIndex = i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primaryColor : const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSel ? AppTheme.primaryColor : const Color(0xFF2E2E35),
                    ),
                  ),
                  child: Text(
                    _currentGroupEpisodes[i].name,
                    style: TextStyle(
                      color: isSel ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMobileDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: _buildDetailPanel(ctx),
            ),
          );
        },
      ),
    );
  }
}
