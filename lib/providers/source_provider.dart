import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/source_model.dart';
import '../services/database_service.dart';

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
