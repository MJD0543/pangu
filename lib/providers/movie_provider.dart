import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import '../models/source_model.dart';
import '../services/movie_api_service.dart';

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
    _isLoading = true;
    _error = null;
    _movies = [];
    _currentPage = 1;
    _selectedCategoryId = 0;
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
    _currentPage = 1;
    _movies = [];
    _isLoading = true;
    _isSearching = false;
    _searchKeyword = '';
    notifyListeners();
    try {
      final result = await _api.getMovieList(apiUrl: apiUrl, typeId: typeId, page: 1);
      _movies = (result['list'] as List).cast<MovieItem>();
      _totalPages = result['pageCount'] as int;
    } catch (e) {
      _error = '加载失败: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore(String apiUrl) async {
    if (_isLoadingMore || _currentPage >= _totalPages) return;
    _isLoadingMore = true;
    notifyListeners();
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
    } catch (_) {
      _currentPage--;
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> search(String apiUrl, String keyword) async {
    if (keyword.trim().isEmpty) {
      clearSearch(apiUrl);
      return;
    }
    _searchKeyword = keyword;
    _isSearching = true;
    _currentPage = 1;
    _searchResults = [];
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _api.getMovieList(apiUrl: apiUrl, keyword: keyword, page: 1);
      _searchResults = (result['list'] as List).cast<MovieItem>();
      _totalPages = result['pageCount'] as int;
    } catch (e) {
      _error = '搜索失败: $e';
    }
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
                  allResults.add(e.copyWithSource(
                    sourceName: source.name, sourceUrl: source.url));
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
                allResults.add(e.copyWithSource(
                  sourceName: source.name, sourceUrl: source.url));
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
    _isSearching = false;
    _searchKeyword = '';
    _searchResults = [];
    notifyListeners();
    loadForSource(apiUrl);
  }

  Future<MovieDetail?> getDetail(String apiUrl, int id) async {
    return _api.getMovieDetail(apiUrl, id);
  }
}
