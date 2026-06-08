// test/providers/history_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

import 'package:newplayer/models/source_model.dart';
import 'package:newplayer/providers/history_provider.dart';
import 'package:newplayer/services/database_service.dart';
import '../helpers/test_helpers.dart';

// ============================================================
// Fake PathProvider
// ============================================================
class _FakePathProvider extends Fake
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;

  @override
  Future<String?> getTemporaryPath() async =>
      Directory.systemTemp.path;
}

void main() {
  late HistoryProvider provider;

  setUpAll(() {
    initTestDb();
    DatabaseService.initFfi();
    PathProviderPlatform.instance = _FakePathProvider();
  });

  setUp(() async {
    provider = HistoryProvider();
    await Future.delayed(const Duration(milliseconds: 100));
  });

  tearDown(() async {
    await provider.clearAll();
    provider.dispose();
  });

  group('HistoryProvider — 基本状态', () {
    test('初始为空', () {
      expect(provider.histories, isEmpty);
      expect(provider.isLoading, isFalse);
    });
  });

  group('HistoryProvider — 添加记录', () {
    test('添加一条观看记录', () async {
      final record = WatchHistory(
        movieId: 1001,
        movieName: '测试影片',
        apiUrl: 'https://api.example.com',
        sourceName: '测试源',
        episodeName: '第1集',
        episodeIndex: 0,
        progressSeconds: 120,
        totalSeconds: 3600,
        watchedAt: DateTime.now(),
      );
      await provider.addHistory(record);
      expect(provider.histories.length, 1);
      expect(provider.histories.first.movieName, '测试影片');
    });

    test('重复添加同一影片应更新而非新增', () async {
      await provider.addHistory(WatchHistory(
        movieId: 2001,
        movieName: '重复影片',
        apiUrl: 'https://api.example.com',
        sourceName: '测试源',
        episodeName: '第1集',
        episodeIndex: 0,
        progressSeconds: 60,
        totalSeconds: 3600,
        watchedAt: DateTime.now(),
      ));
      expect(provider.histories.length, 1);

      // 再次添加同一影片
      await provider.addHistory(WatchHistory(
        movieId: 2001,
        movieName: '重复影片',
        apiUrl: 'https://api.example.com',
        sourceName: '测试源',
        episodeName: '第2集',
        episodeIndex: 1,
        progressSeconds: 120,
        totalSeconds: 3600,
        watchedAt: DateTime.now(),
      ));
      expect(provider.histories.length, 1,
          reason: '同一影片应更新而不是新增');
      expect(provider.histories.first.episodeName, '第2集',
          reason: '更新后集数应变更');
    });

    test('添加多条不同记录', () async {
      for (var i = 0; i < 3; i++) {
        await provider.addHistory(WatchHistory(
          movieId: 3000 + i,
          movieName: '影片-$i',
          apiUrl: 'https://api.example.com',
          sourceName: '测试源',
          episodeName: '第1集',
          episodeIndex: 0,
          progressSeconds: i * 60,
          totalSeconds: 3600,
          watchedAt: DateTime.now(),
        ));
      }
      expect(provider.histories.length, 3);
    });
  });

  group('HistoryProvider — 删除记录', () {
    test('删除单条记录', () async {
      await provider.addHistory(WatchHistory(
        movieId: 4001,
        movieName: '待删除影片',
        apiUrl: 'https://api.example.com',
        sourceName: '测试源',
        episodeName: '第1集',
        episodeIndex: 0,
        progressSeconds: 0,
        totalSeconds: 3600,
        watchedAt: DateTime.now(),
      ));
      expect(provider.histories.length, 1);
      final id = provider.histories.first.id;
      await provider.deleteHistory(id);
      expect(provider.histories.length, 0);
    });

    test('清空所有记录', () async {
      for (var i = 0; i < 5; i++) {
        await provider.addHistory(WatchHistory(
          movieId: 5000 + i,
          movieName: '批量-$i',
          apiUrl: 'https://api.example.com',
          sourceName: '测试源',
          episodeName: '第1集',
          episodeIndex: 0,
          progressSeconds: 0,
          totalSeconds: 3600,
          watchedAt: DateTime.now(),
        ));
      }
      expect(provider.histories.length, 5);
      await provider.clearAll();
      expect(provider.histories.length, 0);
    });
  });

  group('WatchHistory — 工具方法', () {
    test('progressText 格式正确', () {
      final h = WatchHistory(
        movieId: 1, movieName: '测试',
        apiUrl: '', sourceName: '', episodeName: '',
        episodeIndex: 0,
        progressSeconds: 125, // 2:05
        totalSeconds: 3600,   // 60:00
        watchedAt: DateTime.now(),
      );
      expect(h.progressText, '2:05 / 60:00');
    });

    test('progressPercent 计算正确', () {
      final h = WatchHistory(
        movieId: 1, movieName: '测试',
        apiUrl: '', sourceName: '', episodeName: '',
        episodeIndex: 0,
        progressSeconds: 1800,
        totalSeconds: 3600,
        watchedAt: DateTime.now(),
      );
      expect(h.progressPercent, 0.5);
    });

    test('totalSeconds 为 0 时 progressPercent 返回 0', () {
      final h = WatchHistory(
        movieId: 1, movieName: '测试',
        apiUrl: '', sourceName: '', episodeName: '',
        episodeIndex: 0,
        progressSeconds: 100,
        totalSeconds: 0,
        watchedAt: DateTime.now(),
      );
      expect(h.progressPercent, 0);
    });

    test('toMap 不包含 id=0', () {
      final h = WatchHistory(
        movieId: 1, movieName: '测试',
        apiUrl: '', sourceName: '', episodeName: '',
        episodeIndex: 0,
        progressSeconds: 0, totalSeconds: 3600,
        watchedAt: DateTime.now(),
      );
      final map = h.toMap();
      expect(map.containsKey('id'), isFalse);
    });

    test('toMap 包含 id>0', () {
      final h = WatchHistory(
        id: 42,
        movieId: 1, movieName: '测试',
        apiUrl: '', sourceName: '', episodeName: '',
        episodeIndex: 0,
        progressSeconds: 0, totalSeconds: 3600,
        watchedAt: DateTime.now(),
      );
      final map = h.toMap();
      expect(map['id'], 42);
    });
  });
}
