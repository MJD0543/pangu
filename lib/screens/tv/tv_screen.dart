// lib/screens/tv/tv_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/source_model.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../widgets/video_player_widget.dart';

class TvScreen extends StatefulWidget {
  final bool isActive;
  const TvScreen({super.key, this.isActive = true});
  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  bool _showChannelPanel = false;
  String _lastLoadedSourceId = '';
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
  }

  @override
  void didUpdateWidget(TvScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当切换回TV标签时重新加载
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
    }
  }

  void _loadIfNeeded() {
    final srcProv = context.read<SourceProvider>();
    final tvProv = context.read<TvProvider>();
    final src = srcProv.activeTvSource;
    if (src != null && src.id != _lastLoadedSourceId) {
      _lastLoadedSourceId = src.id;
      tvProv.loadFromSource(src);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SourceProvider, TvProvider>(
      builder: (ctx, srcProv, tvProv, _) {
        final src = srcProv.activeTvSource;
        if (src == null) return _buildNoSource(ctx);

        // 源切换由 onSourceChanged 回调中的 _loadIfNeeded 处理
        // 不在 build 中自动触发，避免与 initState/didUpdateWidget 中的 _loadIfNeeded 重复

        if (tvProv.isLoading) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading channels...'),
          ]));
        }
        if (tvProv.error != null) return _buildError(ctx, tvProv, src);
        if (tvProv.channels.isEmpty) return _buildEmpty(ctx);

        _selectedGroup ??= tvProv.groupNames.isNotEmpty ? tvProv.groupNames.first : null;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 只在TV标签激活时渲染视频区域
              if (widget.isActive) _buildVideoArea(ctx, srcProv, tvProv)
              else Container(color: Colors.black, child: Center(
                child: Text(S.switchToTvTab, style: const TextStyle(color: Colors.white54)),
              )),
              // 频道面板覆盖层
              if (_showChannelPanel) _buildChannelPanel(ctx, tvProv, srcProv),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoArea(BuildContext ctx, SourceProvider srcProv, TvProvider tvProv) {
    final current = tvProv.currentChannel;
    if (current == null) {
      return const Center(child: Text('请选择频道', style: TextStyle(color: Colors.white54)));
    }
    return VideoPlayerWidget(
      url: current.url,
      title: current.name,
      isTV: true,
      onShowChannelList: () => setState(() => _showChannelPanel = true),
      onPrevChannel: () => _prevChannel(tvProv),
      onNextChannel: () => _nextChannel(tvProv),
      tvSources: srcProv.tvSources,
      activeTvSource: srcProv.activeTvSource,
      onSourceChanged: (s) {
        srcProv.setActiveTvSource(s);
        _lastLoadedSourceId = '';
        _loadIfNeeded();
      },
    );
  }

  void _prevChannel(TvProvider tvProv) {
    final channels = tvProv.channels;
    final current = tvProv.currentChannel;
    if (channels.isEmpty || current == null) return;
    final idx = channels.indexWhere((ch) => ch.url == current.url);
    if (idx > 0) {
      tvProv.selectChannel(channels[idx - 1]);
    }
  }

  void _nextChannel(TvProvider tvProv) {
    final channels = tvProv.channels;
    final current = tvProv.currentChannel;
    if (channels.isEmpty || current == null) return;
    final idx = channels.indexWhere((ch) => ch.url == current.url);
    if (idx >= 0 && idx < channels.length - 1) {
      tvProv.selectChannel(channels[idx + 1]);
    }
  }

  Widget _buildChannelPanel(BuildContext ctx, TvProvider tvProv, SourceProvider srcProv) {
    final groups = tvProv.groupNames;
    final currentChannels = _selectedGroup != null
      ? (tvProv.groups[_selectedGroup] ?? [])
      : tvProv.channels;

    // Calculate dynamic width based on longest channel name
    final maxNameLen = currentChannels.fold<int>(0, (max, ch) =>
      ch.name.length > max ? ch.name.length : max);
    // Approx 14px per char + leading 40px + padding 32px
    final channelListWidth = (maxNameLen * 14.0 + 72.0).clamp(140.0, 260.0);
    final panelWidth = (groups.isNotEmpty ? 140.0 : 0) + channelListWidth;

    return Positioned(
      left: 0, top: 0, bottom: 0, width: panelWidth,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xEE1A1A1F),
          border: const Border(right: BorderSide(color: Color(0xFF2E2E35))),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(S.formatChannelCount(tvProv.channels.length),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => setState(() => _showChannelPanel = false),
                  ),
                ],
              ),
            ),
            // Two-column layout: groups (left) + channels (right)
            Expanded(
              child: Row(
                children: [
                  // Left: Group list (vertical)
                  if (groups.isNotEmpty)
                    Container(
                      width: 140,
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Color(0xFF2E2E35))),
                      ),
                      child: ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (_, i) {
                          final g = groups[i];
                          final sel = g == _selectedGroup;
                          return InkWell(
                            onTap: () => setState(() => _selectedGroup = g),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFF2E2E35) : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: sel ? AppTheme.primaryColor : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildGroupIcon(g),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(g,
                                      style: TextStyle(
                                        color: sel ? Colors.white : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Right: Channel list (auto width)
                  SizedBox(
                    width: channelListWidth,
                    child: ListView.builder(
                      itemCount: currentChannels.length,
                      itemBuilder: (_, i) {
                        final ch = currentChannels[i];
                        final isCurrent = ch.url == tvProv.currentChannel?.url;
                        return ListTile(
                          dense: true,
                          selected: isCurrent,
                          selectedTileColor: Colors.white10,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: isCurrent
                            ? const Icon(Icons.play_arrow, color: AppTheme.primaryColor, size: 18)
                            : ch.logo != null
                              ? SizedBox(width: 24, height: 24, child: Image.network(ch.logo!, errorBuilder: (_, __, ___) => const Icon(Icons.tv, size: 18, color: Colors.white54)))
                              : const Icon(Icons.tv, size: 18, color: Colors.white54),
                          title: Text(
                            ch.name,
                            style: TextStyle(
                              color: isCurrent ? AppTheme.primaryColor : Colors.white,
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            tvProv.selectChannel(ch);
                            setState(() => _showChannelPanel = false);
                          },
                        );
                      },
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

  Widget _buildGroupIcon(String groupName) {
    final lower = groupName.toLowerCase();
    // Telegram
    if (lower.contains('tg') || lower.contains('telegram')) {
      return const Icon(Icons.telegram, size: 18, color: Color(0xFF0088CC));
    }
    // Fire / 央卫视
    if (lower.contains('央卫视') || lower.contains('三网') || lower.contains('移动')) {
      return const Icon(Icons.local_fire_department, size: 18, color: Colors.orange);
    }
    // Local
    if (lower.contains('地方') || lower.contains('local')) {
      return const Icon(Icons.location_on, size: 18, color: Colors.cyan);
    }
    // HK/Macau/Taiwan
    if (lower.contains('港澳') || lower.contains('港台')) {
      return const Icon(Icons.live_tv, size: 18, color: Color(0xFF9C27B0));
    }
    // Country flags using text initials
    final flags = {
      'my': 'MY', '马来西亚': 'MY',
      'vn': 'VN', '越南': 'VN',
      'in': 'IN', '印度': 'IN',
      'jp': 'JP', '日本': 'JP',
      'kr': 'KR', '韩国': 'KR',
      'us': 'US', '美国': 'US',
      'gb': 'GB', '英国': 'GB',
      'tw': 'TW', '台湾': 'TW',
      'ru': 'RU', '俄罗斯': 'RU',
      'fr': 'FR', '法国': 'FR',
      'de': 'DE', '德国': 'DE',
    };
    for (final entry in flags.entries) {
      if (lower.contains(entry.key)) {
        return Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(entry.value,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
          ),
        );
      }
    }
    // Default
    return const Icon(Icons.folder, size: 18, color: Colors.white54);
  }

  Widget _buildNoSource(BuildContext ctx) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.tv_off, size: 64, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(S.noTvSource),
        const SizedBox(height: 8),
        Text(S.addTvSource),
      ]),
    );
  }

  Widget _buildEmpty(BuildContext ctx) {
    return Center(child: Text(S.channelEmpty));
  }

  Widget _buildError(BuildContext ctx, TvProvider tvProv, VideoSource src) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: AppTheme.accentColor),
        const SizedBox(height: 16),
        Text(tvProv.error ?? S.loadFailed),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => tvProv.loadFromSource(src),
          child: Text(S.retry),
        ),
      ]),
    );
  }
}
