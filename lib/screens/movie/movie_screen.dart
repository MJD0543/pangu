// lib/screens/movie/movie_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_provider.dart';
import '../../models/source_model.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../core/animations.dart';
import '../../widgets/tv_focus_widget.dart';
import 'movie_player_screen.dart';
import '../system/history_screen.dart';

class MovieScreen extends StatefulWidget {
  const MovieScreen({super.key});
  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _pinyinController = TextEditingController();
  bool _showSearch = false;
  String _lastLoadedSourceId = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      final srcProv = context.read<SourceProvider>();
      final movProv = context.read<MovieProvider>();
      if (srcProv.activeMovieSource != null && movProv.hasMore && !movProv.isLoadingMore) {
        movProv.loadMore(srcProv.activeMovieSource!.url);
      }
    }
  }

  void _loadIfNeeded() {
    final srcProv = context.read<SourceProvider>();
    final movProv = context.read<MovieProvider>();
    final src = srcProv.activeMovieSource;
    if (src != null && src.id != _lastLoadedSourceId) {
      _lastLoadedSourceId = src.id;
      movProv.loadForSource(src.url);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _pinyinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SourceProvider, MovieProvider>(
      builder: (ctx, srcProv, movProv, _) {
        final src = srcProv.activeMovieSource;
        if (src == null) return _buildNoSource(ctx);

        // 源切换由 _buildSourceSelector 的 onSelected 回调中的 _loadIfNeeded 处理
        // 不在 build 中自动触发加载，避免与 initState 中的 _loadIfNeeded 重复

        return Scaffold(
          backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
          body: NestedScrollView(
            headerSliverBuilder: (ctx, inner) => [
              _buildAppBar(ctx, srcProv, movProv, src),
              if (!_showSearch && movProv.categories.isNotEmpty)
                _buildCategoryBar(ctx, movProv, src),
              if (_showSearch) _buildSearchPanel(ctx, movProv, srcProv),
            ],
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _buildBody(ctx, movProv, src),
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(BuildContext ctx, SourceProvider srcProv, MovieProvider movProv, VideoSource src) {
    return SliverAppBar(
      floating: true, snap: true,
      pinned: false,
      title: _showSearch
        ? Text(S.search, style: const TextStyle(fontSize: 16))
        : Row(
            children: [
              Image.asset('assets/icons/app_icon.png', width: 22, height: 22),
              const SizedBox(width: 8),
              Text(S.movie),
              const SizedBox(width: 8),
              if (srcProv.movieSources.length > 1)
                _buildSourceSelector(ctx, srcProv),
            ],
          ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => const HistoryScreen(),
          )),
        ),
        IconButton(
          icon: Icon(_showSearch ? Icons.close : Icons.search),
          onPressed: () {
            setState(() => _showSearch = !_showSearch);
            if (!_showSearch) {
              _searchController.clear();
              _pinyinController.clear();
              movProv.clearSearch(src.url);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSourceSelector(BuildContext ctx, SourceProvider srcProv) {
    final active = srcProv.activeMovieSource;
    if (active == null) return const SizedBox.shrink();
    return PopupMenuButton<VideoSource>(
      initialValue: active,
      onSelected: (s) {
        srcProv.setActiveMovieSource(s);
        _lastLoadedSourceId = '';
        _loadIfNeeded();
      },
      itemBuilder: (_) => srcProv.movieSources.map((s) => PopupMenuItem(
        value: s,
        child: Row(
          children: [
            if (s.id == active.id)
              const Icon(Icons.check, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 4),
            Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(active.name,
                style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  SliverPersistentHeader _buildCategoryBar(BuildContext ctx, MovieProvider movProv, VideoSource src) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CategoryBarDelegate(
        categories: movProv.categories,
        selectedId: movProv.selectedCategoryId,
        onSelect: (id) => movProv.loadCategory(src.url, id),
      ),
    );
  }

  // ==================== Search Panel ====================
  Widget _buildSearchPanel(BuildContext ctx, MovieProvider movProv, SourceProvider srcProv) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('');

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        color: Theme.of(ctx).scaffoldBackgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search input row with pinyin field + search button + delete button
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: TextField(
                      controller: _pinyinController,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (val) {
                        final clean = val.trim().toUpperCase();
                        if (clean.isNotEmpty) {
                          movProv.searchGlobal(srcProv.movieSources, clean, isLetter: false);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () {
                      final clean = _pinyinController.text.trim().toUpperCase();
                      if (clean.isNotEmpty) {
                        movProv.searchGlobal(srcProv.movieSources, clean, isLetter: false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(S.search, style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 38,
                  width: 38,
                  child: IconButton(
                    onPressed: () {
                      final text = _pinyinController.text;
                      if (text.isNotEmpty) {
                        _pinyinController.text = text.substring(0, text.length - 1);
                        setState(() {});
                      }
                    },
                    icon: Icon(Icons.backspace_outlined, size: 18,
                      color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Character grid (A-Z + 0-9)
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: chars.map((ch) {
                final isActive = _pinyinController.text.contains(ch);
                return GestureDetector(
                  onTap: () {
                    _pinyinController.text += ch;
                    setState(() {});
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryColor
                          : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.primaryColor
                            : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      ch,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext ctx, MovieProvider movProv, VideoSource src) {
    if (_showSearch && movProv.searchKeyword.isEmpty && !movProv.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sort_by_alpha, size: 48, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('输入拼音首字母或点击字符搜索',
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4))),
          ],
        ),
      );
    }
    if (movProv.isLoading) return _buildShimmerGrid(ctx);
    if (movProv.error != null) return _buildError(ctx, movProv, src);
    if (movProv.movies.isEmpty) return _buildEmpty(ctx);

    return TvGridFocusWrapper(
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 0.62,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: movProv.movies.length + (movProv.isLoadingMore ? 6 : 0),
        itemBuilder: (_, i) {
          if (i >= movProv.movies.length) return _buildShimmerCard();
          final m = movProv.movies[i];
          return _buildMovieCard(ctx, m);
        },
      ),
    );
  }

  Widget _buildMovieCard(BuildContext ctx, MovieItem m) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    // 使用 sourceUrl + name hashCode 确保跨源搜索结果也唯一，避免 hero tag 碰撞
    final heroTag = 'poster_${m.id}_${m.sourceUrl ?? ''}_${m.name.hashCode}';
    return TvFocusWrapper(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPlayer(ctx, m),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag,
                      child: m.pic != null && m.pic!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: m.pic!,
                            fit: BoxFit.cover,
                            memCacheWidth: 300, // 限制内存缓存尺寸，节省内存
                            placeholder: (_, __) => Container(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                            errorWidget: (_, __, ___) => _buildPosterPlaceholder(ctx),
                          )
                        : _buildPosterPlaceholder(ctx),
                    ),
                    if (m.remarks != null && m.remarks!.isNotEmpty)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(m.remarks!, style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                    if (m.sourceName != null)
                      Positioned(
                        bottom: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(m.sourceName!, style: const TextStyle(color: Colors.white, fontSize: 9)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (m.typeName != null)
                      Text(m.typeName!,
                        style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder(BuildContext ctx) {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: const Center(child: Icon(Icons.movie, size: 40, color: AppTheme.primaryColor)),
    );
  }

  Widget _buildShimmerGrid(BuildContext ctx) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160, childAspectRatio: 0.62,
        crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCard : AppTheme.lightCard,
      ),
      child: Column(children: [
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: const BreathingBox(width: double.infinity, height: double.infinity),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BreathingBox(width: double.infinity, height: 12, radius: 4),
                const SizedBox(height: 4),
                const BreathingBox(width: 50, height: 10, radius: 4),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildNoSource(BuildContext ctx) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.cloud_off, size: 64, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text(S.noMovieSource, style: Theme.of(ctx).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(S.addMovieSource, style: Theme.of(ctx).textTheme.bodySmall),
      ]),
    );
  }

  Widget _buildEmpty(BuildContext ctx) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, size: 64, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text(S.noResult),
      ]),
    );
  }

  Widget _buildError(BuildContext ctx, MovieProvider movProv, VideoSource src) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: AppTheme.accentColor),
        const SizedBox(height: 16),
        Text(movProv.error ?? S.loadFailed),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => movProv.loadForSource(src.url),
          child: Text(S.retry),
        ),
      ]),
    );
  }

  void _openPlayer(BuildContext ctx, MovieItem m) {
    final srcProv = ctx.read<SourceProvider>();
    final apiUrl = m.sourceUrl ?? srcProv.activeMovieSource?.url;
    if (apiUrl == null) return;
    // heroTag 格式必须与 _buildMovieCard 保持一致
    final heroTag = 'poster_${m.id}_${m.sourceUrl ?? ''}_${m.name.hashCode}';
    Navigator.of(ctx).push(FadeSlidePageRoute(
      page: (_) => MoviePlayerScreen(
        movieId: m.id,
        movieName: m.name,
        pic: m.pic,
        apiUrl: apiUrl,
        heroTag: heroTag,
      ),
    ));
  }
}

// ============================================================
// Category Bar with auto-center, left/right arrows
// ============================================================
class _CategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final List<MovieCategory> categories;
  final int selectedId;
  final ValueChanged<int> onSelect;

  _CategoryBarDelegate({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  bool shouldRebuild(_CategoryBarDelegate old) =>
    old.selectedId != selectedId || old.categories.length != categories.length;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return _CategoryBar(
      categories: categories,
      selectedId: selectedId,
      onSelect: onSelect,
    );
  }
}

class _CategoryBar extends StatefulWidget {
  final List<MovieCategory> categories;
  final int selectedId;
  final ValueChanged<int> onSelect;

  const _CategoryBar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  final _scrollController = ScrollController();
  final _keys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _CategoryBar old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    final key = _keys[widget.selectedId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _selectPreviousCategory() {
    final all = [MovieCategory(typeId: 0, typeName: S.allCategories), ...widget.categories];
    final currentIndex = all.indexWhere((c) => c.typeId == widget.selectedId);
    if (currentIndex > 0) {
      widget.onSelect(all[currentIndex - 1].typeId);
    }
  }

  void _selectNextCategory() {
    final all = [MovieCategory(typeId: 0, typeName: S.allCategories), ...widget.categories];
    final currentIndex = all.indexWhere((c) => c.typeId == widget.selectedId);
    if (currentIndex < all.length - 1) {
      widget.onSelect(all[currentIndex + 1].typeId);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = [MovieCategory(typeId: 0, typeName: S.allCategories), ...widget.categories];

    for (final cat in all) {
      _keys.putIfAbsent(cat.typeId, () => GlobalKey());
    }

    final currentIndex = all.indexWhere((c) => c.typeId == widget.selectedId);
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex < all.length - 1;

    return Container(
      height: 48,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          // Left arrow - select previous category
          InkWell(
            onTap: hasPrev ? _selectPreviousCategory : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.chevron_left,
                size: 18,
                color: hasPrev
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
          ),
          // Category chips
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              itemCount: all.length,
              itemBuilder: (_, i) {
                final cat = all[i];
                final selected = cat.typeId == widget.selectedId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    key: _keys[cat.typeId],
                    onTap: () => widget.onSelect(cat.typeId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryColor
                            : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryColor
                              : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cat.typeName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Right arrow + all categories menu
          Container(
            padding: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: hasNext ? _selectNextCategory : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: hasNext
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    ),
                  ),
                ),
                _buildAllCategoriesMenu(context, all, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCategoriesMenu(BuildContext ctx, List<MovieCategory> all, bool isDark) {
    return PopupMenuButton<int>(
      icon: Icon(Icons.menu, size: 18, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
      tooltip: S.categories,
      onSelected: widget.onSelect,
      itemBuilder: (_) => all.map((cat) {
        final sel = cat.typeId == widget.selectedId;
        return PopupMenuItem<int>(
          value: cat.typeId,
          child: Row(
            children: [
              if (sel)
                const Icon(Icons.check, size: 16, color: AppTheme.primaryColor),
              if (sel) const SizedBox(width: 8),
              Text(
                cat.typeName,
                style: TextStyle(
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  color: sel ? AppTheme.primaryColor : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
