// lib/services/movie_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/source_model.dart';
import '../core/utils.dart';

class MovieApiService {
  static final MovieApiService _i = MovieApiService._();
  factory MovieApiService() => _i;
  MovieApiService._();

  static const Duration _timeout = Duration(seconds: 15);

  // 验证苹果CMS源有效性
  Future<bool> validateMovieSource(String url) async {
    try {
      final apiUrl = _buildApiUrl(url, {'ac': 'videolist', 'pg': '1'});
      final resp = await http.get(Uri.parse(apiUrl)).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['code'] == 1 || data['code'] == '1' || data['list'] != null;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // 获取分类列表 - 尝试多种苹果CMS接口格式
  Future<List<MovieCategory>> getCategories(String apiUrl) async {
    try {
      // 先尝试 ac=list 获取分类（苹果CMS标准接口）
      final listUrl = _buildApiUrl(apiUrl, {'ac': 'list'});
      final listResp = await http.get(Uri.parse(listUrl)).timeout(_timeout);
      if (listResp.statusCode == 200) {
        final data = jsonDecode(listResp.body);
        final classes = data['class'] as List?;
        if (classes != null && classes.isNotEmpty) {
          return classes.map((e) => MovieCategory.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    try {
      // 回退到 ac=videolist 第一页中提取分类
      final url = _buildApiUrl(apiUrl, {'ac': 'videolist', 'pg': '1'});
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final classes = data['class'] as List?;
        if (classes != null && classes.isNotEmpty) {
          return classes.map((e) => MovieCategory.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  // 获取影视列表
  Future<Map<String, dynamic>> getMovieList({
    required String apiUrl,
    int? typeId,
    int page = 1,
    String? keyword,
    String? letter,
  }) async {
    try {
      final params = <String, String>{'ac': 'videolist', 'pg': '$page'};
      if (typeId != null && typeId > 0) params['t'] = '$typeId';
      if (keyword != null && keyword.isNotEmpty) {
        params['wd'] = keyword;
        params.remove('t');
      }
      if (letter != null && letter.isNotEmpty) {
        params['letter'] = letter;
        params.remove('t');
      }
      final url = _buildApiUrl(apiUrl, params);
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      if (resp.statusCode != 200) return {'list': <MovieItem>[], 'total': 0, 'pageCount': 1};
      final data = jsonDecode(resp.body);
      final list = (data['list'] as List? ?? []).map((e) => MovieItem.fromJson(e)).toList();
      return {
        'list': list,
        'total': parseInt(data['total'] ?? data['count'] ?? 0),
        'pageCount': parseInt(data['pagecount'] ?? data['page_count'] ?? 1),
        'page': parseInt(data['page'] ?? page),
      };
    } catch (e) {
      return {'list': <MovieItem>[], 'total': 0, 'pageCount': 1};
    }
  }

  // 获取影视详情
  Future<MovieDetail?> getMovieDetail(String apiUrl, int id) async {
    try {
      final url = _buildApiUrl(apiUrl, {'ac': 'videolist', 'ids': '$id'});
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body);
      final list = data['list'] as List?;
      if (list == null || list.isEmpty) return null;
      return MovieDetail.fromJson(list.first);
    } catch (_) {
      return null;
    }
  }

  String _buildApiUrl(String base, Map<String, String> params) {
    final uri = Uri.tryParse(base);
    if (uri == null) return base;
    final merged = {...uri.queryParameters, ...params};
    return uri.replace(queryParameters: merged).toString();
  }
}
