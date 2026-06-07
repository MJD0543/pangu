// lib/screens/system/resource_library_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/app_provider.dart';
import '../../models/source_model.dart';
import '../../services/movie_api_service.dart';
import '../../services/tv_source_service.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../core/crypto_util.dart';
import 'add_source_dialog.dart';

class ResourceLibraryScreen extends StatefulWidget {
  const ResourceLibraryScreen({super.key});
  @override
  State<ResourceLibraryScreen> createState() => _ResourceLibraryScreenState();
}

class _ResourceLibraryScreenState extends State<ResourceLibraryScreen> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  // 缓存合并后的源列表，避免每次 build 都重新创建
  List<VideoSource> _cachedSources = [];
  int _cachedSourcesHash = 0;

  /// 合并所有源，带缓存以优化性能
  List<VideoSource> _allSources(SourceProvider p) {
    final movieHash = p.movieSources.fold<int>(0, (h, s) => h ^ s.id.hashCode);
    final tvHash = p.tvSources.fold<int>(0, (h, s) => h ^ s.id.hashCode);
    final newHash = movieHash ^ tvHash ^ p.movieSources.length ^ p.tvSources.length;
    if (newHash != _cachedSourcesHash) {
      _cachedSources = [...p.movieSources, ...p.tvSources];
      _cachedSourcesHash = newHash;
    }
    return _cachedSources;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : AppTheme.lightBg;

    return Consumer<SourceProvider>(
      builder: (ctx, prov, _) {
        final sources = _allSources(prov);
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: _selectionMode
              ? Text(S.formatSelectedCount(_selectedIds.length),
                  style: const TextStyle(fontSize: 17))
              : Text(S.resourceLibrary,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            centerTitle: true,
            actions: _buildActions(ctx, prov, sources),
          ),
          body: _buildSourceList(ctx, sources, prov),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddChoiceDialog(ctx, prov),
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // ────────── AppBar Actions ──────────
  List<Widget> _buildActions(BuildContext ctx, SourceProvider prov, List<VideoSource> sources) {
    if (_selectionMode) {
      return [
        TextButton(
          onPressed: () => setState(() => _selectedIds.addAll(sources.map((s) => s.id))),
          child: Text(S.selectAll),
        ),
        TextButton(
          onPressed: _clearSelection,
          child: Text(S.cancel),
        ),
        IconButton(
          icon: const Icon(Icons.wifi_tethering),
          tooltip: S.checkSelected,
          onPressed: _selectedIds.isEmpty ? null : () => _checkSelected(ctx, prov),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: S.deleteSelected,
          onPressed: _selectedIds.isEmpty ? null : () => _deleteSelected(ctx, prov),
        ),
      ];
    }
    return [
      // 批量操作
      IconButton(
        icon: const Icon(Icons.checklist),
        tooltip: S.batchAction,
        onPressed: sources.isEmpty ? null : () => setState(() => _selectionMode = true),
      ),
      // 导入（本地 TXT）
      IconButton(
        icon: const Icon(Icons.file_download_outlined),
        tooltip: S.importSource,
        onPressed: () => _importFromFile(ctx, prov),
      ),
      // 导出（选择源后导出）
      IconButton(
        icon: const Icon(Icons.file_upload_outlined),
        tooltip: S.exportSource,
        onPressed: sources.isEmpty ? null : () => _showExportDialog(ctx, prov, sources),
      ),
      // 检测所有（在 PopupMenu 里保留）
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'check_all',
            child: Row(children: [
              const Icon(Icons.wifi_tethering, size: 18),
              const SizedBox(width: 8),
              Text(S.checkAll),
            ]),
          ),
        ],
        onSelected: (v) {
          if (v == 'check_all') _checkAllSources(ctx, prov, sources);
        },
      ),
    ];
  }

  // ────────── Source List ──────────
  Widget _buildSourceList(BuildContext ctx, List<VideoSource> sources, SourceProvider prov) {
    if (sources.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.storage, size: 64,
              color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(S.noSource, style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(S.tapAdd, style: Theme.of(ctx).textTheme.bodySmall),
        ]),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sources.length,
      onReorder: (oldIdx, newIdx) {
        if (newIdx > oldIdx) newIdx--;
        final ids = List<String>.from(sources.map((s) => s.id));
        final item = ids.removeAt(oldIdx);
        ids.insert(newIdx, item);
        prov.reorderSources(ids);
      },
      itemBuilder: (_, i) {
        final s = sources[i];
        return _buildSourceTile(ctx, s, prov, key: ValueKey(s.id));
      },
    );
  }

  Widget _buildSourceTile(BuildContext ctx, VideoSource s, SourceProvider prov,
      {required Key key}) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final isSelected = _selectedIds.contains(s.id);
    final isMovie = s.type == SourceType.movie;

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
          ? AppTheme.primaryColor.withOpacity(0.1)
          : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
            ? AppTheme.primaryColor
            : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: _selectionMode
          ? Checkbox(
              value: isSelected,
              activeColor: AppTheme.primaryColor,
              onChanged: (_) => _toggleSelect(s.id),
            )
          : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isMovie
                  ? const Color(0xFF4CAF50).withOpacity(0.12)
                  : const Color(0xFF2196F3).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Image.asset(
                  isMovie
                    ? 'assets/icons/ic_apple_cms.png'
                    : 'assets/icons/ic_live.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                s.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMovie
                  ? const Color(0xFF4CAF50).withOpacity(0.12)
                  : const Color(0xFF2196F3).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isMovie ? S.movieSource : S.tvSource,
                style: TextStyle(
                  fontSize: 10,
                  color: isMovie
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.url,
              style: Theme.of(ctx).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: s.isAvailable
                    ? AppTheme.successColor.withOpacity(0.12)
                    : AppTheme.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.isAvailable ? S.available : S.unavailable,
                  style: TextStyle(
                    fontSize: 10,
                    color: s.isAvailable ? AppTheme.successColor : AppTheme.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (s.lastChecked != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${S.lastChecked}: ${S.formatTimeAgo(s.lastChecked!)}',
                  style: Theme.of(ctx).textTheme.labelSmall,
                ),
              ],
            ]),
          ],
        ),
        trailing: _selectionMode
          ? const Icon(Icons.drag_handle, color: Colors.grey)
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit, size: 16),
                    const SizedBox(width: 8),
                    Text(S.edit),
                  ]),
                ),
                PopupMenuItem(
                  value: 'check',
                  child: Row(children: [
                    const Icon(Icons.wifi_tethering, size: 16),
                    const SizedBox(width: 8),
                    Text(S.check),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(S.delete, style: const TextStyle(color: Colors.redAccent)),
                  ]),
                ),
              ],
              onSelected: (v) {
                if (v == 'edit') _showEditDialog(ctx, s, prov);
                if (v == 'check') _checkSingleSource(ctx, s, prov);
                if (v == 'delete') _confirmDelete(ctx, [s.id], prov);
              },
            ),
        onTap: _selectionMode ? () => _toggleSelect(s.id) : null,
        onLongPress: () {
          if (!_selectionMode) {
            setState(() {
              _selectionMode = true;
              _selectedIds.add(s.id);
            });
          }
        },
      ),
    );
  }

  // ────────── Selection ──────────
  void _clearSelection() => setState(() {
    _selectionMode = false;
    _selectedIds.clear();
  });

  void _toggleSelect(String id) => setState(() {
    _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
  });

  // ────────── Check ──────────
  Future<void> _checkSingleSource(BuildContext ctx, VideoSource s, SourceProvider prov) async {
    final snackBar = ScaffoldMessenger.of(ctx);
    snackBar.showSnackBar(SnackBar(
      content: Text(S.checking),
      duration: const Duration(seconds: 30),
    ));
    final bool available;
    if (s.type == SourceType.movie) {
      available = await MovieApiService().validateMovieSource(s.url);
    } else {
      available = await TvSourceService().validateTvSource(s.url);
    }
    snackBar.hideCurrentSnackBar();
    if (!ctx.mounted) return;
    await prov.updateSource(s.copyWith(isAvailable: available, lastChecked: DateTime.now()));
    if (!ctx.mounted) return;
    snackBar.showSnackBar(SnackBar(
      content: Text(S.formatCheckResult(s.name, available)),
      backgroundColor: available ? AppTheme.successColor : AppTheme.accentColor,
    ));
  }

  Future<void> _checkSelected(BuildContext ctx, SourceProvider prov) async {
    final sources = _allSources(prov).where((s) => _selectedIds.contains(s.id)).toList();
    for (final s in sources) {
      if (!ctx.mounted) break;
      await _checkSingleSource(ctx, s, prov);
    }
  }

  Future<void> _checkAllSources(BuildContext ctx, SourceProvider prov, List<VideoSource> sources) async {
    setState(() {
      _selectionMode = true;
      _selectedIds.addAll(sources.map((s) => s.id));
    });
    await _checkSelected(ctx, prov);
    _clearSelection();
  }

  // ────────── Delete ──────────
  Future<void> _deleteSelected(BuildContext ctx, SourceProvider prov) async {
    await _confirmDelete(ctx, _selectedIds.toList(), prov);
  }

  Future<void> _confirmDelete(BuildContext ctx, List<String> ids, SourceProvider prov) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(S.confirmDelete),
        content: Text(S.formatDeleteCount(ids.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: Text(S.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: Text(S.delete, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await prov.deleteSources(ids);
      _clearSelection();
    }
  }

  // ────────── Export（弹出选择对话框） ──────────
  Future<void> _showExportDialog(
      BuildContext ctx, SourceProvider prov, List<VideoSource> sources) async {
    // 弹出多选对话框
    final chosen = await showDialog<List<VideoSource>>(
      context: ctx,
      builder: (_) => _ExportSelectDialog(sources: sources),
    );
    if (chosen == null || chosen.isEmpty) return;
    if (!ctx.mounted) return;
    await _doExport(ctx, chosen);
  }

  Future<void> _doExport(BuildContext ctx, List<VideoSource> sources) async {
    try {
      // 格式: name,url,type（0=movie, 1=tv）
      final content = sources.map((s) => '${s.name},${s.url},${s.type == SourceType.movie ? 0 : 1}').join('\n');
      // AES 加密
      final encrypted = CryptoUtil.encrypt(content);
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: S.saveTo,
        fileName: '盘古影视_share_${DateTime.now().millisecondsSinceEpoch}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (savePath == null) return;
      final file = File(savePath);
      await file.writeAsString(encrypted);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(S.formatExportedTo(sources.length, file.path)),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${S.exportFailed}: $e')),
        );
      }
    }
  }

  // ────────── Import（支持加密和明文 TXT） ──────────
  Future<void> _importFromFile(BuildContext ctx, SourceProvider prov) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final raw = file.bytes != null
        ? utf8.decode(file.bytes!)
        : await File(file.path!).readAsString(encoding: utf8);

      if (!ctx.mounted) return;

      // 尝试 AES 解密
      final decrypted = CryptoUtil.decrypt(raw.trim());
      final content = decrypted ?? raw; // 解密成功用解密内容，否则原文明文

      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('正在检测源可用性，请稍候...'),
        duration: Duration(minutes: 5),
      ));

      int added = 0, updated = 0, failed = 0;
      final lines = content.split('\n');
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final parts = line.split(',');
        if (parts.length < 2) continue;
        final name = parts[0].trim();
        final url = parts[1].trim();
        if (url.isEmpty) continue;
        // 解析 type（新格式有 name,url,type，旧格式只有 name,url）
        final SourceType type;
        if (parts.length >= 3) {
          type = parts[2].trim() == '1' ? SourceType.tv : SourceType.movie;
        } else {
          type = _detectSourceType(url);
        }

        final bool available;
        if (type == SourceType.movie) {
          available = await MovieApiService().validateMovieSource(url);
        } else {
          available = await TvSourceService().validateTvSource(url);
        }
        if (!available) { failed++; continue; }

        final exists = await prov.isUrlExists(url, type);
        final id = exists
          ? (await prov.getExistingId(url, type) ?? DateTime.now().millisecondsSinceEpoch.toString())
          : DateTime.now().millisecondsSinceEpoch.toString();

        await prov.upsertSource(VideoSource(
          id: id,
          name: name.isEmpty ? url : name,
          url: url,
          type: type,
          isAvailable: true,
          lastChecked: DateTime.now(),
        ));
        exists ? updated++ : added++;
      }

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(S.formatImportResult(added, updated, failed)),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${S.importFailed}: $e')),
        );
      }
    }
  }

  // 根据 URL 内容特征判断类型
  SourceType _detectSourceType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u') ||
        lower.contains('.m3u8') ||
        lower.contains('iptv') ||
        lower.contains('live')) {
      return SourceType.tv;
    }
    // 苹果CMS 接口特征
    if (lower.contains('provide/vod') ||
        lower.contains('api.php') ||
        lower.contains('index.php')) {
      return SourceType.movie;
    }
    return SourceType.movie; // 默认影视源
  }

  // ────────── Add / Edit Dialog ──────────
  void _showAddChoiceDialog(BuildContext ctx, SourceProvider prov) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    showDialog(
      context: ctx,
      builder: (_) => Center(
        child: SizedBox(
          width: 520,
          child: Dialog(
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.selectSourceType,
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Image.asset('assets/icons/ic_apple_cms.png', width: 32, height: 32),
                    title: Text(S.addMovieSourceOption, textAlign: TextAlign.center),
                    subtitle: const Text('苹果CMS API 接口', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddDialog(ctx, prov, SourceType.movie);
                    },
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: Image.asset('assets/icons/ic_live.png', width: 32, height: 32),
                    title: Text(S.addTvSourceOption, textAlign: TextAlign.center),
                    subtitle: const Text('M3U/TXT 直播源地址', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddDialog(ctx, prov, SourceType.tv);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, SourceProvider prov, SourceType type) {
    showDialog(
      context: ctx,
      builder: (_) => AddSourceDialog(
        type: type,
        onCheckExists: (url) => prov.isUrlExists(url, type),
        onAdd: (s) async => prov.upsertSource(s), // upsert: 已存在则覆盖，否则新增
      ),
    );
  }

  void _showEditDialog(BuildContext ctx, VideoSource s, SourceProvider prov) {
    showDialog(
      context: ctx,
      builder: (_) => AddSourceDialog(
        type: s.type,
        existing: s,
        onAdd: (updated) async => prov.updateSource(updated),
      ),
    );
  }
}

// ────────── 导出选择对话框 ──────────
class _ExportSelectDialog extends StatefulWidget {
  final List<VideoSource> sources;
  const _ExportSelectDialog({required this.sources});

  @override
  State<_ExportSelectDialog> createState() => _ExportSelectDialogState();
}

class _ExportSelectDialogState extends State<_ExportSelectDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // 默认全选
    _selected = Set.from(widget.sources.map((s) => s.id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      S.selectExportSources,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() =>
                        _selected.addAll(widget.sources.map((s) => s.id))),
                    child: Text(S.selectAll),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.sources.length,
                itemBuilder: (ctx, i) {
                  final s = widget.sources[i];
                  final isMovie = s.type == SourceType.movie;
                  return CheckboxListTile(
                    value: _selected.contains(s.id),
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) => setState(() {
                      v == true ? _selected.add(s.id) : _selected.remove(s.id);
                    }),
                    secondary: SizedBox(
                      width: 32,
                      height: 32,
                      child: Image.asset(
                        isMovie
                          ? 'assets/icons/ic_apple_cms.png'
                          : 'assets/icons/ic_live.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    title: Text(s.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      isMovie ? S.movieSource : S.tvSource,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMovie
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2196F3),
                      ),
                    ),
                    dense: true,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(S.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty
                        ? null
                        : () {
                            final chosen = widget.sources
                                .where((s) => _selected.contains(s.id))
                                .toList();
                            Navigator.pop(context, chosen);
                          },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('${S.exportSource}（${_selected.length}）'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
