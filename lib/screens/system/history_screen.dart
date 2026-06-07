// lib/screens/system/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_provider.dart';
import '../../models/source_model.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../movie/movie_player_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(S.browseHistory, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          Consumer<HistoryProvider>(
            builder: (_, hp, __) {
              if (hp.histories.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _confirmClear(context, hp),
                child: Text(S.clear, style: TextStyle(color: AppTheme.accentColor, fontSize: 13)),
              );
            },
          ),
        ],
      ),
      body: Consumer<HistoryProvider>(
        builder: (_, hp, __) {
          if (hp.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (hp.histories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(S.noHistory, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: hp.histories.length,
            itemBuilder: (_, i) => _buildHistoryCard(context, hp.histories[i], cardColor),
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext ctx, WatchHistory h, Color cardColor) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Dismissible(
      key: Key('history_${h.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => ctx.read<HistoryProvider>().deleteHistory(h.id),
      child: GestureDetector(
        onTap: () => _resumePlayback(ctx, h),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                child: h.pic != null && h.pic!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: h.pic!,
                        width: 90,
                        height: 110,
                        fit: BoxFit.cover,
                        memCacheWidth: 180, // 限制内存缓存尺寸
                        placeholder: (_, __) => Container(
                          width: 90, height: 110,
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        ),
                        errorWidget: (_, __, ___) => _buildPlaceholder(ctx, width: 90, height: 110),
                      )
                    : _buildPlaceholder(ctx, width: 90, height: 110),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.movieName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      S.formatSourceLabel(h.sourceName),
                      style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.formatEpisodeLabel(h.episodeName),
                      style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: h.progressPercent.clamp(0.0, 1.0),
                              backgroundColor: isDark ? const Color(0xFF2E2E35) : const Color(0xFFE0E0E8),
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          h.progressText,
                          style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.formatTimeAgo(h.watchedAt),
                      style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.35)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, size: 18, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.25)),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext ctx, {double width = 60, double height = 80}) {
    return Container(
      width: width,
      height: height,
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: const Center(child: Icon(Icons.movie, size: 28, color: AppTheme.primaryColor)),
    );
  }

  void _resumePlayback(BuildContext ctx, WatchHistory h) {
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => MoviePlayerScreen(
        movieId: h.movieId,
        movieName: h.movieName,
        pic: h.pic,
        apiUrl: h.apiUrl,
        initialEpisodeIndex: h.episodeIndex,
        initialProgressSeconds: h.progressSeconds,
      ),
    ));
  }

  void _confirmClear(BuildContext ctx, HistoryProvider hp) {
    showDialog(
      context: ctx,
      builder: (ctx2) => AlertDialog(
        title: Text(S.clearHistory),
        content: Text(S.confirmClearHistory),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx2), child: Text(S.cancel)),
          TextButton(
            onPressed: () {
              hp.clearAll();
              Navigator.pop(ctx2);
            },
            child: Text(S.clear, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
