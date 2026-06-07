// lib/services/database_service.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/source_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;
  static bool _ffiInitialized = false;

  /// 初始化 FFI（Windows/Linux/macOS 桌面端必须调用）
  static void initFfi() {
    if (_ffiInitialized) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialized = true;
  }

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    // 确保 FFI 已初始化
    initFfi();

    String dbPath;
    try {
      // 桌面端使用 path_provider 获取应用数据目录
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final appDir = await getApplicationSupportDirectory();
        dbPath = appDir.path;
      } else {
        dbPath = await getDatabasesPath();
      }
    } catch (e) {
      // 如果 path_provider 失败，使用当前用户目录
      final home = Platform.environment['USERPROFILE'] ?? 
                    Platform.environment['HOME'] ?? 
                    '.';
      dbPath = path.join(home, '.newplayer');
    }

    // 确保 dbPath 目录存在
    final dir = Directory(dbPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    final fullPath = path.join(dbPath, 'newplayer.db');
    print('📦 Database path: $fullPath');
    
    return openDatabase(
      fullPath,
      version: 2,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE sources(
            id TEXT PRIMARY KEY, name TEXT NOT NULL, url TEXT NOT NULL,
            type INTEGER NOT NULL DEFAULT 0, isEnabled INTEGER DEFAULT 1,
            isAvailable INTEGER DEFAULT 1, lastChecked INTEGER,
            sortOrder INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE watch_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            movie_id INTEGER NOT NULL,
            movie_name TEXT NOT NULL,
            pic TEXT,
            api_url TEXT NOT NULL,
            source_name TEXT NOT NULL,
            episode_name TEXT NOT NULL,
            episode_index INTEGER DEFAULT 0,
            progress_seconds INTEGER DEFAULT 0,
            total_seconds INTEGER DEFAULT 0,
            watched_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_history_movie ON watch_history(movie_id)');
        await db.execute('CREATE INDEX idx_history_watched ON watch_history(watched_at DESC)');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('''
            CREATE TABLE watch_history(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              movie_id INTEGER NOT NULL,
              movie_name TEXT NOT NULL,
              pic TEXT,
              api_url TEXT NOT NULL,
              source_name TEXT NOT NULL,
              episode_name TEXT NOT NULL,
              episode_index INTEGER DEFAULT 0,
              progress_seconds INTEGER DEFAULT 0,
              total_seconds INTEGER DEFAULT 0,
              watched_at INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_history_movie ON watch_history(movie_id)');
          await db.execute('CREATE INDEX idx_history_watched ON watch_history(watched_at DESC)');
        }
      },
    );
  }

  Future<List<VideoSource>> getSources(SourceType type) async {
    final db = await database;
    final maps = await db.query('sources',
        where: 'type = ?', whereArgs: [type.index],
        orderBy: 'sortOrder ASC, name ASC');
    return maps.map(VideoSource.fromMap).toList();
  }

  Future<void> insertSource(VideoSource source) async {
    final db = await database;
    await db.insert('sources', source.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSource(VideoSource source) async {
    final db = await database;
    await db.update('sources', source.toMap(), where: 'id = ?', whereArgs: [source.id]);
  }

  Future<void> deleteSource(String id) async {
    final db = await database;
    await db.delete('sources', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSources(List<String> ids) async {
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.delete('sources', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<bool> sourceExists(String url, SourceType type) async {
    final db = await database;
    final res = await db.query('sources',
        where: 'url = ? AND type = ?', whereArgs: [url, type.index]);
    return res.isNotEmpty;
  }

  Future<VideoSource?> getSourceByUrl(String url, SourceType type) async {
    final db = await database;
    final res = await db.query('sources',
        where: 'url = ? AND type = ?', whereArgs: [url, type.index]);
    return res.isNotEmpty ? VideoSource.fromMap(res.first) : null;
  }

  /// 插入或覆盖：URL 相同则更新（保留原 id），否则 INSERT
  Future<void> upsertSource(VideoSource source) async {
    final db = await database;
    final existing = await getSourceByUrl(source.url, source.type);
    if (existing != null) {
      // 保留原 id，更新其余字段
      final updated = VideoSource(
        id: existing.id,
        name: source.name,
        url: source.url,
        type: source.type,
        isEnabled: source.isEnabled,
        isAvailable: source.isAvailable,
        lastChecked: source.lastChecked,
        sortOrder: existing.sortOrder, // 保留原排序
      );
      await db.update('sources', updated.toMap(),
          where: 'id = ?', whereArgs: [existing.id]);
    } else {
      await db.insert('sources', source.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> reorderSources(List<String> ids) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < ids.length; i++) {
      batch.update('sources', {'sortOrder': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await batch.commit(noResult: true);
  }

  // ==================== Watch History ====================
  Future<List<WatchHistory>> getWatchHistory({int limit = 100}) async {
    final db = await database;
    final maps = await db.query(
      'watch_history',
      orderBy: 'watched_at DESC',
      limit: limit,
    );
    return maps.map(WatchHistory.fromMap).toList();
  }

  Future<WatchHistory?> getWatchHistoryByMovie(int movieId) async {
    final db = await database;
    final maps = await db.query(
      'watch_history',
      where: 'movie_id = ?',
      whereArgs: [movieId],
      orderBy: 'watched_at DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? WatchHistory.fromMap(maps.first) : null;
  }

  Future<void> insertOrUpdateWatchHistory(WatchHistory h) async {
    final db = await database;
    // Delete old record for same movie
    await db.delete('watch_history', where: 'movie_id = ?', whereArgs: [h.movieId]);
    await db.insert('watch_history', h.toMap());
  }

  Future<void> deleteWatchHistory(int id) async {
    final db = await database;
    await db.delete('watch_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearWatchHistory() async {
    final db = await database;
    await db.delete('watch_history');
  }
}
