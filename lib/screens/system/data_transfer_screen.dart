// lib/screens/system/data_transfer_screen.dart
/// 数据互传页面 - 局域网内数据接收与发送
library data_transfer_screen;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/app_provider.dart';
import '../../models/source_model.dart';
import '../../services/data_transfer_service.dart';
import '../../services/tv_source_service.dart';
import '../../core/app_theme.dart';

class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key});
  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DataTransferService _service = DataTransferService();

  // 接收端状态
  bool _receiving = false;

  // 发送端状态
  final TextEditingController _serverUrlController = TextEditingController();
  String? _connectedServer;
  bool _connecting = false;
  bool _checkingSources = false;
  Map<String, bool> _sourceAvailability = {};
  bool _sending = false;

  StreamSubscription<List<Map<String, dynamic>>>? _resourceSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 监听接收到的资源
    _resourceSub = _service.onResourceReceived.listen((sources) {
      if (mounted) {
        _importReceivedSources(sources);
      }
    });
  }

  @override
  void dispose() {
    _service.stopServer();
    _resourceSub?.cancel();
    _service.dispose();
    _serverUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ────────── 接收端：导入接收到的资源 ──────────
  Future<void> _importReceivedSources(List<Map<String, dynamic>> sources) async {
    final prov = context.read<SourceProvider>();
    int added = 0;
    for (final s in sources) {
      final name = s['name'] as String? ?? '';
      final url = s['url'] as String? ?? '';
      final typeStr = s['type'] as String? ?? 'movie';
      if (name.isEmpty || url.isEmpty) continue;

      final exists = [...prov.movieSources, ...prov.tvSources]
          .any((existing) => existing.url == url);
      if (exists) continue;

      final type = typeStr == 'tv' ? SourceType.tv : SourceType.movie;
      final source = VideoSource(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        url: url,
        type: type,
      );
      await prov.upsertSource(source);
      added++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已接收 $added 个资源')),
      );
    }
  }

  // ────────── 发送端：收集要发送的资源 ──────────
  List<VideoSource> _getAllSources() {
    final prov = context.read<SourceProvider>();
    return [...prov.movieSources, ...prov.tvSources];
  }

  Future<void> _checkSourcesAndShow(List<VideoSource> sources) async {
    setState(() { _checkingSources = true; _sourceAvailability = {}; });

    final results = <String, bool>{};
    for (final s in sources) {
      final url = s.url.trim();
      if (url.startsWith('http://') || url.startsWith('https://')) {
        // 影视源检查
        try {
          final resp = await TvSourceService().validateTvSource(url);
          results[s.id] = resp;
        } catch (_) {
          results[s.id] = false;
        }
      } else {
        results[s.id] = false;
      }
    }

    if (mounted) {
      setState(() { _checkingSources = false; _sourceAvailability = results; });
      unawaited(_showSourcesPreview(sources));
    }
  }

  Future<void> _showSourcesPreview(List<VideoSource> sources) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('资源列表 (${sources.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sources.length,
            itemBuilder: (_, i) {
              final s = sources[i];
              final available = _sourceAvailability[s.id] ?? false;
              return ListTile(
                dense: true,
                leading: Icon(
                  available ? Icons.check_circle : Icons.cancel,
                  color: available ? Colors.green : Colors.redAccent,
                  size: 20,
                ),
                title: Text(s.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  s.url,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认发送'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _doSend(sources);
    }
  }

  Future<void> _doSend(List<VideoSource> sources) async {
    if (_connectedServer == null) return;
    setState(() => _sending = true);

    final data = sources.map((s) => {
      'name': s.name,
      'url': s.url,
      'type': s.type.name,
    }).toList();

    final success = await _service.sendResources(_connectedServer!, data);

    if (mounted) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '发送成功' : '发送失败')),
      );
    }
  }

  // ────────── 接收端：启动/停止服务 ──────────
  Future<void> _toggleReceiving(bool value) async {
    if (value) {
      final ok = await _service.startServer();
      setState(() => _receiving = ok);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法启动服务，请检查网络')),
        );
      }
    } else {
      await _service.stopServer();
      setState(() => _receiving = false);
    }
  }

  // ────────── 发送端：连接服务器 ──────────
  Future<void> _showConnectDialog() async {
    _serverUrlController.text = _connectedServer ?? '';
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('连接服务器'),
        content: TextField(
          controller: _serverUrlController,
          decoration: const InputDecoration(
            labelText: '服务器地址',
            hintText: '例如: http://192.168.3.199:8188',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _serverUrlController.text.trim()),
            child: const Text('连接'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty && mounted) {
      setState(() { _connecting = true; _connectedServer = null; });
      final ok = await _service.checkServer(url);
      if (mounted) {
        setState(() {
          _connecting = false;
          _connectedServer = ok ? url : null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '连接成功' : '连接失败，请检查地址')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : AppTheme.lightBg;

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
        title: const Text('数据互传', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          tabs: const [
            Tab(text: '数据接收'),
            Tab(text: '数据发送'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceiveTab(isDark, bgColor),
          _buildSendTab(isDark, bgColor),
        ],
      ),
    );
  }

  // ────────── 数据接收 Tab ──────────
  Widget _buildReceiveTab(bool isDark, Color bgColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 开关
        Card(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SwitchListTile(
            title: const Text('开启接收服务', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_receiving ? '服务运行中' : '关闭后其他设备无法发送数据'),
            value: _receiving,
            onChanged: _toggleReceiving,
            activeColor: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),

        // 服务地址
        if (_receiving && _service.serverUrl != null) ...[
          Card(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('服务地址', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _service.serverUrl!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 二维码
          Card(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('扫码连接', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: _service.serverUrl!,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ────────── 数据发送 Tab ──────────
  Widget _buildSendTab(bool isDark, Color bgColor) {
    final sources = _getAllSources();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 连接状态
        Card(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _connectedServer != null ? Icons.wifi : Icons.wifi_off,
                  color: _connectedServer != null ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('服务器', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        _connectedServer ?? '未连接',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _connectedServer != null
                              ? AppTheme.primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_connecting)
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _connectedServer != null
                        ? () { setState(() => _connectedServer = null); }
                        : _showConnectDialog,
                    icon: Icon(
                      _connectedServer != null ? Icons.link_off : Icons.link,
                      size: 18,
                    ),
                    label: Text(_connectedServer != null ? '断开' : '连接'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 发送资源库按钮
        Card(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.send, color: AppTheme.primaryColor),
            title: const Text('发送资源库', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('共 ${sources.length} 个资源'),
            trailing: _sending
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            enabled: _connectedServer != null && !_sending && !_checkingSources,
            onTap: _connectedServer != null
                ? () => _checkSourcesAndShow(sources)
                : null,
          ),
        ),

        if (_checkingSources) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}
