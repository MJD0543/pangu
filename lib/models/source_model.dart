// lib/models/source_model.dart
import '../core/utils.dart';

enum SourceType { movie, tv }

class VideoSource {
  final String id;
  String name;
  String url;
  SourceType type;
  bool isEnabled;
  bool isAvailable;
  DateTime? lastChecked;
  int sortOrder;

  VideoSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.isEnabled = true,
    this.isAvailable = true,
    this.lastChecked,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'url': url,
    'type': type.index,
    'isEnabled': isEnabled ? 1 : 0,
    'isAvailable': isAvailable ? 1 : 0,
    'lastChecked': lastChecked?.millisecondsSinceEpoch,
    'sortOrder': sortOrder,
  };

  factory VideoSource.fromMap(Map<String, dynamic> map) => VideoSource(
    id: map['id'],
    name: map['name'],
    url: map['url'],
    type: SourceType.values[map['type'] ?? 0],
    isEnabled: (map['isEnabled'] ?? 1) == 1,
    isAvailable: (map['isAvailable'] ?? 1) == 1,
    lastChecked: map['lastChecked'] != null ? DateTime.fromMillisecondsSinceEpoch(map['lastChecked']) : null,
    sortOrder: map['sortOrder'] ?? 0,
  );

  VideoSource copyWith({
    String? name, String? url, bool? isEnabled, bool? isAvailable,
    DateTime? lastChecked, int? sortOrder,
  }) => VideoSource(
    id: id, name: name ?? this.name, url: url ?? this.url,
    type: type, isEnabled: isEnabled ?? this.isEnabled,
    isAvailable: isAvailable ?? this.isAvailable,
    lastChecked: lastChecked ?? this.lastChecked, sortOrder: sortOrder ?? this.sortOrder,
  );
}

// 苹果CMS影视条目
class MovieItem {
  final int id;
  final String name;
  final String? pic;
  final String? typeName;
  final String? year;
  final String? area;
  final String? remarks;
  final String? last;
  final double? score;
  String? sourceName; // Transient field for global search results
  String? sourceUrl;  // Transient – api url of the source that found this item

  MovieItem({
    required this.id, required this.name,
    this.pic, this.typeName, this.year,
    this.area, this.remarks, this.last, this.score,
  });

  factory MovieItem.fromJson(Map<String, dynamic> json) => MovieItem(
    id: parseInt(json['vod_id'] ?? json['id'] ?? 0),
    name: json['vod_name']?.toString() ?? json['name']?.toString() ?? '',
    pic: json['vod_pic']?.toString() ?? json['pic']?.toString(),
    typeName: json['type_name']?.toString() ?? json['typeName']?.toString(),
    year: json['vod_year']?.toString() ?? json['year']?.toString(),
    area: json['vod_area']?.toString() ?? json['area']?.toString(),
    remarks: json['vod_remarks']?.toString() ?? json['remarks']?.toString(),
    last: json['vod_time']?.toString(),
    score: parseDouble(json['vod_score'] ?? json['score']),
  );

  // Removed: private _parseInt, _parseDouble — use core/utils.dart instead
}

// 影视详情
class MovieDetail extends MovieItem {
  final String? description;
  final String? director;
  final String? actor;
  final List<PlayGroup> playGroups;

  MovieDetail({
    required super.id, required super.name,
    super.pic, super.typeName, super.year, super.area,
    super.remarks, super.last, super.score,
    this.description, this.director, this.actor,
    this.playGroups = const [],
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    final base = MovieItem.fromJson(json);
    final List<PlayGroup> groups = [];
    
    final playFrom = json['vod_play_from']?.toString() ?? '';
    final playUrl = json['vod_play_url']?.toString() ?? '';
    
    if (playFrom.isNotEmpty && playUrl.isNotEmpty) {
      final froms = playFrom.split('\$\$\$');
      final urls = playUrl.split('\$\$\$');
      for (int i = 0; i < froms.length; i++) {
        final groupUrls = i < urls.length ? urls[i] : '';
        final episodes = <Episode>[];
        for (final part in groupUrls.split('#')) {
          final kv = part.split('\$');
          if (kv.isNotEmpty && kv[0].trim().isNotEmpty) {
            episodes.add(Episode(name: kv[0].trim(), url: kv.length > 1 ? kv[1].trim() : ''));
          }
        }
        if (episodes.isNotEmpty) {
          groups.add(PlayGroup(name: froms[i].trim(), episodes: episodes));
        }
      }
    }

    return MovieDetail(
      id: base.id, name: base.name, pic: base.pic,
      typeName: base.typeName, year: base.year, area: base.area,
      remarks: base.remarks, last: base.last, score: base.score,
      description: json['vod_content']?.toString() ?? json['vod_blurb']?.toString(),
      director: json['vod_director']?.toString(),
      actor: json['vod_actor']?.toString(),
      playGroups: groups,
    );
  }
}

class PlayGroup {
  final String name;
  final List<Episode> episodes;
  PlayGroup({required this.name, required this.episodes});
}

class Episode {
  final String name;
  final String url;
  Episode({required this.name, required this.url});
}

// TV频道
class TvChannel {
  final String name;
  final String url;
  final String? group;
  final String? logo;

  TvChannel({required this.name, required this.url, this.group, this.logo});
}

// 苹果CMS分类
class MovieCategory {
  final int typeId;
  final String typeName;
  MovieCategory({required this.typeId, required this.typeName});
  factory MovieCategory.fromJson(Map<String, dynamic> json) => MovieCategory(
    typeId: parseInt(json['type_id'] ?? json['id'] ?? 0),
    typeName: json['type_name']?.toString() ?? json['name']?.toString() ?? '',
  );
}

// 观看历史记录
class WatchHistory {
  final int id; // 0 = 新记录（由 DB 自动分配），>0 = 已有记录
  final int movieId;
  final String movieName;
  final String? pic;
  final String apiUrl;
  final String sourceName;
  final String episodeName;
  final int episodeIndex;
  final int progressSeconds;
  final int totalSeconds;
  final DateTime watchedAt;

  WatchHistory({
    this.id = 0, // 新建时传 0，让 DB 自动分配
    required this.movieId,
    required this.movieName,
    this.pic,
    required this.apiUrl,
    required this.sourceName,
    required this.episodeName,
    required this.episodeIndex,
    required this.progressSeconds,
    required this.totalSeconds,
    required this.watchedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'movie_id': movieId,
      'movie_name': movieName,
      'pic': pic,
      'api_url': apiUrl,
      'source_name': sourceName,
      'episode_name': episodeName,
      'episode_index': episodeIndex,
      'progress_seconds': progressSeconds,
      'total_seconds': totalSeconds,
      'watched_at': watchedAt.millisecondsSinceEpoch,
    };
    // 仅当 id > 0 时才包含 id（已存在记录更新时用）
    if (id > 0) map['id'] = id;
    return map;
  }

  factory WatchHistory.fromMap(Map<String, dynamic> map) => WatchHistory(
    id: map['id'] ?? 0,
    movieId: map['movie_id'] ?? 0,
    movieName: map['movie_name']?.toString() ?? '',
    pic: map['pic']?.toString(),
    apiUrl: map['api_url']?.toString() ?? '',
    sourceName: map['source_name']?.toString() ?? '',
    episodeName: map['episode_name']?.toString() ?? '',
    episodeIndex: map['episode_index'] ?? 0,
    progressSeconds: map['progress_seconds'] ?? 0,
    totalSeconds: map['total_seconds'] ?? 0,
    watchedAt: map['watched_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['watched_at'])
        : DateTime.now(),
  );

  String get progressText {
    final p = Duration(seconds: progressSeconds);
    final t = Duration(seconds: totalSeconds);
    String fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return '${fmt(p)} / ${fmt(t)}';
  }

  double get progressPercent => totalSeconds > 0 ? progressSeconds / totalSeconds : 0;
}
