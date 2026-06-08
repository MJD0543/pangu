// test/providers/source_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

import 'package:newplayer/models/source_model.dart';
import 'package:newplayer/providers/source_provider.dart';
import 'package:newplayer/services/database_service.dart';
import '../helpers/test_helpers.dart';

// ============================================================
// Fake PathProvider for 测试环境（无需真实文件系统）
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
  late SourceProvider provider;
  late DatabaseService db;

  setUpAll(() {
    initTestDb();
    DatabaseService.initFfi();
    // 注入 Fake PathProvider 以使用临时目录
    PathProviderPlatform.instance = _FakePathProvider();
  });

  setUp(() async {
    db = DatabaseService();
    provider = SourceProvider();
    // 等待初始加载完成
    await Future.delayed(const Duration(milliseconds: 100));
  });

  tearDown(() async {
    // 清理测试数据
    final sources = await db.getSources(SourceType.movie);
    for (final s in sources) {
      await db.deleteSource(s.id);
    }
    final tvSources = await db.getSources(SourceType.tv);
    for (final s in tvSources) {
      await db.deleteSource(s.id);
    }
    provider.dispose();
  });

  group('SourceProvider — 基本状态', () {
    test('初始状态为空', () {
      expect(provider.movieSources, isEmpty);
      expect(provider.tvSources, isEmpty);
      expect(provider.activeMovieSource, isNull);
      expect(provider.activeTvSource, isNull);
    });
  });

  group('SourceProvider — 添加源', () {
    test('添加影视源后 movieSources 包含该源', () async {
      final source = VideoSource(
        id: 'test-001',
        name: '测试影视源',
        url: 'https://example.com/api',
        type: SourceType.movie,
      );
      await provider.addSource(source);
      expect(provider.movieSources.length, 1);
      expect(provider.movieSources.first.name, '测试影视源');
    });

    test('添加电视源后 tvSources 包含该源', () async {
      final source = VideoSource(
        id: 'tv-001',
        name: '测试电视源',
        url: 'https://example.com/tv',
        type: SourceType.tv,
      );
      await provider.addSource(source);
      expect(provider.tvSources.length, 1);
      expect(provider.tvSources.first.name, '测试电视源');
    });

    test('添加多个源后数量正确', () async {
      for (var i = 0; i < 3; i++) {
        await provider.addSource(VideoSource(
          id: 'multi-$i',
          name: '源-$i',
          url: 'https://example.com/$i',
          type: SourceType.movie,
        ));
      }
      expect(provider.movieSources.length, 3);
    });
  });

  group('SourceProvider — URL 去重检测', () {
    test('isUrlExists 检测重复 URL', () async {
      await provider.addSource(VideoSource(
        id: 'dup-001',
        name: '源A',
        url: 'https://same-url.com/api',
        type: SourceType.movie,
      ));
      final exists = await provider.isUrlExists(
        'https://same-url.com/api', SourceType.movie);
      expect(exists, isTrue);
    });

    test('不存在的 URL 返回 false', () async {
      final exists = await provider.isUrlExists(
        'https://no-such-url.com/api', SourceType.movie);
      expect(exists, isFalse);
    });
  });

  group('SourceProvider — Upsert', () {
    test('upsert 新增时 added=1', () async {
      final result = await provider.upsertSources([
        VideoSource(
          id: 'upsert-new',
          name: '新源',
          url: 'https://new.com/api',
          type: SourceType.movie,
        ),
      ]);
      expect(result['added'], 1);
      expect(result['updated'], 0);
    });

    test('upsert 覆盖时 updated=1', () async {
      // 先添加
      await provider.addSource(VideoSource(
        id: 'upsert-ov',
        name: '原名称',
        url: 'https://override.com/api',
        type: SourceType.movie,
      ));
      // 再用同一个 URL upsert（名称不同）
      final result = await provider.upsertSources([
        VideoSource(
          id: 'upsert-ov-v2',
          name: '新名称',
          url: 'https://override.com/api',
          type: SourceType.movie,
        ),
      ]);
      expect(result['updated'], 1);
      expect(result['added'], 0);
      // 验证名称已更新
      expect(provider.movieSources.first.name, '新名称');
    });
  });

  group('SourceProvider — 删除源', () {
    test('删除后数量减少', () async {
      await provider.addSource(VideoSource(
        id: 'del-001',
        name: '待删除',
        url: 'https://delete.com/api',
        type: SourceType.movie,
      ));
      expect(provider.movieSources.length, 1);
      await provider.deleteSource('del-001');
      expect(provider.movieSources.length, 0);
    });

    test('批量删除', () async {
      for (var i = 0; i < 3; i++) {
        await provider.addSource(VideoSource(
          id: 'batch-del-$i',
          name: '批量-$i',
          url: 'https://batch.com/$i',
          type: SourceType.movie,
        ));
      }
      expect(provider.movieSources.length, 3);
      await provider.deleteSources(['batch-del-0', 'batch-del-1']);
      expect(provider.movieSources.length, 1);
    });
  });
}
