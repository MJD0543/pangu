// lib/providers/app_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lpinyin/lpinyin.dart';
import '../models/source_model.dart';
import '../services/database_service.dart';
import '../services/movie_api_service.dart';
import '../services/tv_source_service.dart';
// ==================== Theme Provider ====================
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode') ?? 'system';
    _mode = {'light': ThemeMode.light, 'dark': ThemeMode.dark}[stored] ?? ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    final prefs = await SharedPreferences.getInstance();
    final key = {ThemeMode.light: 'light', ThemeMode.dark: 'dark'}[m] ?? 'system';
    await prefs.setString('theme_mode', key);
    notifyListeners();
  }
  }

// ==================== Source Provider ====================
class SourceProvider extends ChangeNotifier {
  final _db = DatabaseService();
  
  List<VideoSource> _movieSources = [];
  List<VideoSource> _tvSources = [];
  VideoSource? _activeMovieSource;
  VideoSource? _activeTvSource;

  List<VideoSource> get movieSources => _movieSources;
  List<VideoSource> get tvSources => _tvSources;
  VideoSource? get activeMovieSource => _activeMovieSource;
  VideoSource? get activeTvSource => _activeTvSource;

  SourceProvider() { loadSources(); }

  Future<void> loadSources() async {
    _movieSources = await _db.getSources(SourceType.movie);
    _tvSources = await _db.getSources(SourceType.tv);
    final prefs = await SharedPreferences.getInstance();
    final movieId = prefs.getString('active_movie_source');
    final tvId = prefs.getString('active_tv_source');
    _activeMovieSource = _movieSources.isNotEmpty 
      ? (_movieSources.where((s) => s.id == movieId).firstOrNull ?? _movieSources.first)
      : null;
    _activeTvSource = _tvSources.isNotEmpty
      ? (_tvSources.where((s) => s.id == tvId).firstOrNull ?? _tvSources.first)
      : null;
    notifyListeners();
  }

  Future<void> setActiveMovieSource(VideoSource s) async {
    _activeMovieSource = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_movie_source', s.id);
    notifyListeners();
  }

  Future<void> setActiveTvSource(VideoSource s) async {
    _activeTvSource = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_tv_source', s.id);
    notifyListeners();
  }

  Future<void> addSource(VideoSource s) async {
    await _db.insertSource(s);
    await loadSources();
  }

  Future<void> updateSource(VideoSource s) async {
    await _db.updateSource(s);
    await loadSources();
  }

  Future<void> deleteSource(String id) async {
    await _db.deleteSource(id);
    await loadSources();
  }

  Future<void> deleteSources(List<String> ids) async {
    await _db.deleteSources(ids);
    await loadSources();
  }

  Future<bool> isUrlExists(String url, SourceType type) async {
    final exists = await _db.sourceExists(url, type);
    return exists;
  }

  Future<String?> getExistingId(String url, SourceType type) async {
    final source = await _db.getSourceByUrl(url, type);
    return source?.id;
  }

  /// 插入或覆盖（URL 已存在则覆盖，否则新增）
  Future<void> upsertSource(VideoSource s) async {
    await _db.upsertSource(s);
    await loadSources();
  }

  /// 批量 upsert，返回 (added, updated) 统计
  Future<Map<String, int>> upsertSources(List<VideoSource> sources) async {
    int added = 0, updated = 0;
    for (final s in sources) {
      final exists = await _db.sourceExists(s.url, s.type);
      await _db.upsertSource(s);
      exists ? updated++ : added++;
    }
    await loadSources();
    return {'added': added, 'updated': updated};
  }

  Future<void> reorderSources(List<String> ids) async {
    await _db.reorderSources(ids);
    await loadSources();
  }
}

// ==================== Movie Provider ====================
class MovieProvider extends ChangeNotifier {
  final _api = MovieApiService();
  MovieApiService get api => _api;
  
  List<MovieCategory> _categories = [];
  List<MovieItem> _movies = [];
  List<MovieItem> _searchResults = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _selectedCategoryId = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchKeyword = '';
  bool _isSearching = false;
  String? _error;

  List<MovieCategory> get categories => _categories;
  List<MovieItem> get movies => _isSearching ? _searchResults : _movies;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get selectedCategoryId => _selectedCategoryId;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _currentPage < _totalPages;
  String get searchKeyword => _searchKeyword;
  bool get isSearching => _isSearching;
  String? get error => _error;

  Future<void> loadForSource(String apiUrl) async {
    _isLoading = true; _error = null; _movies = [];
    _currentPage = 1; _selectedCategoryId = 0;
    notifyListeners();
    try {
      _categories = await _api.getCategories(apiUrl);
      final result = await _api.getMovieList(apiUrl: apiUrl, page: 1);
      _movies = (result['list'] as List).cast<MovieItem>();
      _totalPages = result['pageCount'] as int;
    } catch (e) {
      _error = '加载失败: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCategory(String apiUrl, int typeId) async {
    _selectedCategoryId = typeId;
    _currentPage = 1; _movies = []; _isLoading = true;
    _isSearching = false; _searchKeyword = '';
    notifyListeners();
    try {
      final result = await _api.getMovieList(apiUrl: apiUrl, typeId: typeId, page: 1);
      _movies = (result['list'] as List).cast<MovieItem>();
      _totalPages = result['pageCount'] as int;
    } catch (e) { _error = '加载失败: $e'; }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore(String apiUrl) async {
    if (_isLoadingMore || _currentPage >= _totalPages) return;
    _isLoadingMore = true; notifyListeners();
    try {
      _currentPage++;
      final result = await _api.getMovieList(
        apiUrl: apiUrl,
        typeId: _selectedCategoryId > 0 ? _selectedCategoryId : null,
        page: _currentPage,
        keyword: _isSearching ? _searchKeyword : null,
      );
      final newItems = (result['list'] as List).cast<MovieItem>();
      if (_isSearching) {
        _searchResults.addAll(newItems);
      } else {
        _movies.addAll(newItems);
      }
    } catch (_) { _currentPage--; }
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> search(String apiUrl, String keyword) async {
    if (keyword.trim().isEmpty) {
      clearSearch(apiUrl);
      return;
    }
    _searchKeyword = keyword; _isSearching = true;
    _currentPage = 1; _searchResults = []; _isLoading = true;
    notifyListeners();
    try {
      final result = await _api.getMovieList(apiUrl: apiUrl, keyword: keyword, page: 1);
      _searchResults = (result['list'] as List).cast<MovieItem>();
      _totalPages = result['pageCount'] as int;
    } catch (e) { _error = '搜索失败: $e'; }
    _isLoading = false;
    notifyListeners();
  }

  /// Global search across all movie sources (first-letter or keyword)
  Future<void> searchGlobal(List<VideoSource> sources, String query, {bool isLetter = false}) async {
    if (query.trim().isEmpty) return;
    _searchKeyword = query;
    _isSearching = true;
    _currentPage = 1;
    _searchResults = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    final q = query.trim();
    // Detect pinyin-initials search: all ASCII uppercase letters, 2+ chars
    final isPinyin = RegExp(r'^[A-Z]+$').hasMatch(q) && q.length >= 2;
    // Single letter → use API letter param instead of keyword
    final isSingleLetter = RegExp(r'^[A-Z]$').hasMatch(q);
    final useLetter = isLetter || isPinyin || isSingleLetter;

    try {
      final allResults = <MovieItem>[];
      final seenNames = <String>{};
      await Future.wait(sources.where((s) => s.isEnabled).map((source) async {
        try {
          if (isPinyin) {
            // Pinyin search: fetch multiple pages (up to 5) in parallel
            const maxPages = 5;
            final pageResults = await Future.wait(
              List.generate(maxPages, (i) => _api.getMovieList(
                apiUrl: source.url,
                keyword: null,
                letter: q[0],
                page: i + 1,
              )),
            );
            for (final result in pageResults) {
              final rawList = result['list'];
              if (rawList is! List) continue;
              for (final e in rawList) {
                if (e is! MovieItem) continue;
                final initials = PinyinHelper.getShortPinyin(e.name);
                if (initials.isEmpty) continue;
                if (!initials.toUpperCase().contains(q)) continue;
                if (seenNames.add(e.name)) {
                  e.sourceName = source.name;
                  e.sourceUrl = source.url;
                  allResults.add(e);
                }
              }
            }
          } else {
            final result = await _api.getMovieList(
              apiUrl: source.url,
              keyword: useLetter ? null : q,
              letter: useLetter ? q : null,
              page: 1,
            );
            final rawList = result['list'];
            if (rawList is! List) return;
            for (final e in rawList) {
              if (e is! MovieItem) continue;
              if (seenNames.add(e.name)) {
                e.sourceName = source.name;
                e.sourceUrl = source.url;
                allResults.add(e);
              }
            }
          }
        } catch (ex) {
          debugPrint('搜索源 [${source.name}] 失败: $ex');
        }
      }));
      _searchResults = allResults;
      _totalPages = 1;
    } catch (e) {
      _error = '搜索失败: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  void clearSearch(String apiUrl) {
    _isSearching = false; _searchKeyword = '';
    _searchResults = [];
    notifyListeners();
    loadForSource(apiUrl);
  }

  Future<MovieDetail?> getDetail(String apiUrl, int id) async {
    return _api.getMovieDetail(apiUrl, id);
  }
}

// ==================== History Provider ====================
class HistoryProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<WatchHistory> _histories = [];
  bool _isLoading = false;

  List<WatchHistory> get histories => _histories;
  bool get isLoading => _isLoading;

  HistoryProvider() { load(); }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _histories = await _db.getWatchHistory();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addHistory(WatchHistory h) async {
    await _db.insertOrUpdateWatchHistory(h);
    await load();
  }

  Future<void> deleteHistory(int id) async {
    await _db.deleteWatchHistory(id);
    await load();
  }

  Future<void> clearAll() async {
    await _db.clearWatchHistory();
    await load();
  }
}

// ==================== TV Provider ====================
class TvProvider extends ChangeNotifier {
  final _service = TvSourceService();
  
  List<TvChannel> _channels = [];
  Map<String, List<TvChannel>> _groups = {};
  TvChannel? _currentChannel;
  bool _isLoading = false;
  String? _error;
  List<String> get groupNames => _groups.keys.toList();

  List<TvChannel> get channels => _channels;
  Map<String, List<TvChannel>> get groups => _groups;
  TvChannel? get currentChannel => _currentChannel;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFromSource(VideoSource source) async {
    _isLoading = true; _error = null;
    notifyListeners();
    try {
      final list = await _service.parseFromUrl(source.url);
      _channels = list;
      _buildGroups();
      if (_channels.isNotEmpty && _currentChannel == null) {
        _currentChannel = _channels.first;
      }
    } catch (e) { _error = '加载失败: $e'; }
    _isLoading = false;
    notifyListeners();
  }

  void _buildGroups() {
    _groups = {};
    for (final ch in _channels) {
      final g = ch.group ?? '未分组';
      _groups.putIfAbsent(g, () => []).add(ch);
    }
  }

  void selectChannel(TvChannel ch) {
    _currentChannel = ch;
    notifyListeners();
  }

  void nextChannel() {
    if (_channels.isEmpty) return;
    final idx = _channels.indexOf(_currentChannel ?? _channels.first);
    _currentChannel = _channels[(idx + 1) % _channels.length];
    notifyListeners();
  }

  void prevChannel() {
    if (_channels.isEmpty) return;
    final idx = _channels.indexOf(_currentChannel ?? _channels.first);
    _currentChannel = _channels[(idx - 1 + _channels.length) % _channels.length];
    notifyListeners();
  }
}
