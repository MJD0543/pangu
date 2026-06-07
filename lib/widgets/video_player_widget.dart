// lib/widgets/video_player_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/source_model.dart';
import '../core/app_theme.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final String title;
  final List<Episode>? episodes;
  final int? currentEpisodeIndex;
  final ValueChanged<int>? onEpisodeChanged;
  final bool isTV;
  final VoidCallback? onShowChannelList;
  final VoidCallback? onPrevChannel;
  final VoidCallback? onNextChannel;
  final List<VideoSource>? tvSources;
  final VideoSource? activeTvSource;
  final ValueChanged<VideoSource>? onSourceChanged;
  final int initialProgressSeconds;
  final void Function(int position, int duration)? onProgressChanged;
  final List<TvChannel>? tvChannels;
  final TvChannel? currentTvChannel;
  final ValueChanged<TvChannel>? onTvChannelSelected;

  const VideoPlayerWidget({
    super.key,
    required this.url,
    required this.title,
    this.episodes,
    this.currentEpisodeIndex,
    this.onEpisodeChanged,
    this.isTV = false,
    this.onShowChannelList,
    this.onPrevChannel,
    this.onNextChannel,
    this.tvSources,
    this.activeTvSource,
    this.onSourceChanged,
    this.initialProgressSeconds = 0,
    this.onProgressChanged,
    this.tvChannels,
    this.currentTvChannel,
    this.onTvChannelSelected,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player _player;
  late final VideoController _controller;
  bool _showControls = true;
  bool _showEpisodes = false;
  bool _showVideoInfo = false;
  bool _isFullscreen = false;
  DateTime? _lastTapTime;
  bool _hasSeeked = false;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _play(widget.url);
    _hideControlsAfterDelay();
    _startProgressTimer();
  }

  void _play(String url) {
    _player.open(Media(url));
    if (widget.initialProgressSeconds > 0) {
      _hasSeeked = false;
      _player.stream.playing.listen((playing) {
        if (playing && !_hasSeeked && widget.initialProgressSeconds > 0) {
          _hasSeeked = true;
          _player.seek(Duration(seconds: widget.initialProgressSeconds));
        }
      });
    }
  }

  void _startProgressTimer() {
    if (widget.onProgressChanged == null) return;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return false;
      final pos = _player.state.position.inSeconds;
      final dur = _player.state.duration.inSeconds;
      if (dur > 0) widget.onProgressChanged!(pos, dur);
      return mounted;
    });
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _play(widget.url);
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 300) {
      _lastTapTime = null;
      _enterFullscreen();
    } else {
      _lastTapTime = now;
      _toggleControls();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _hideControlsAfterDelay();
  }

  void _enterFullscreen() {
    if (_isFullscreen) return;
    setState(() => _isFullscreen = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => _FullscreenPlayer(
        player: _player,
        controller: _controller,
        title: widget.title,
        isTV: widget.isTV,
        episodes: widget.episodes,
        currentEpisodeIndex: widget.currentEpisodeIndex,
        onEpisodeChanged: widget.onEpisodeChanged,
        onPrevChannel: widget.onPrevChannel,
        onNextChannel: widget.onNextChannel,
        onExit: _exitFullscreen,
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    )).then((_) {
      if (mounted) {
        setState(() => _isFullscreen = false);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    });
  }

  void _exitFullscreen() {
    if (!_isFullscreen) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (_, c) => Video(
              controller: _controller, fit: BoxFit.contain,
              width: c.maxWidth, height: c.maxHeight,
            ),
          ),
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _buildControlsOverlay(context),
          ),
          if (_showEpisodes && widget.episodes != null) _buildEpisodePanel(context),
          if (_showVideoInfo) _buildVideoInfoPanel(context),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x60000000), Colors.transparent, Colors.transparent, Color(0xA0000000)],
          stops: [0.0, 0.03, 0.97, 1.0],
        ),
      ),
      child: Column(children: [
        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            if (!widget.isTV)
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
            if (!widget.isTV) const SizedBox(width: 4),
            Expanded(child: Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
            if (widget.isTV && widget.tvSources != null && widget.tvSources!.length > 1)
              _buildSourceSwitchButton(),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.info_outline, color: Colors.white, size: 22),
              tooltip: '视频信息', onPressed: () => setState(() => _showVideoInfo = !_showVideoInfo),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
          ]),
        )),
        const Spacer(),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            StreamBuilder(stream: _player.stream.position, builder: (_, posSnap) {
              return StreamBuilder(stream: _player.stream.duration, builder: (_, durSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = durSnap.data ?? Duration.zero;
                final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  SliderTheme(data: SliderTheme.of(ctx).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 3, overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ), child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) => _player.seek(Duration(milliseconds: (v * dur.inMilliseconds).toInt())),
                    activeColor: Colors.white, inactiveColor: Colors.white24,
                  )),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(_fmt(dur), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ]);
              });
            }),
            const SizedBox(height: 2),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (widget.isTV && widget.onPrevChannel != null) _btn(Icons.skip_previous, 26, widget.onPrevChannel!, '上一个频道'),
              if (!widget.isTV && widget.episodes != null) _btn(Icons.skip_previous, 26, _prevEpisode, '上一集'),
              const SizedBox(width: 12),
              StreamBuilder(stream: _player.stream.playing, builder: (_, snap) =>
                _btn((snap.data ?? false) ? Icons.pause : Icons.play_arrow, 36, () => _player.playOrPause())),
              const SizedBox(width: 12),
              if (widget.isTV && widget.onNextChannel != null) _btn(Icons.skip_next, 26, widget.onNextChannel!, '下一个频道'),
              if (!widget.isTV && widget.episodes != null) _btn(Icons.skip_next, 26, _nextEpisode, '下一集'),
              const SizedBox(width: 16),
              _buildVolumeControl(),
              const Spacer(),
              if (widget.isTV && widget.onShowChannelList != null)
                _btn(Icons.menu, 24, widget.onShowChannelList!, '频道列表'),
              if (!widget.isTV) _buildSpeedButton(),
              if (!widget.isTV) const SizedBox(width: 6),
              _btn(Icons.fullscreen, 24, _enterFullscreen, '全屏'),
            ]),
            const SizedBox(height: 4),
          ]),
        )),
      ]),
    );
  }

  Widget _btn(IconData icon, double size, VoidCallback onPressed, [String? t]) {
    return IconButton(icon: Icon(icon, color: Colors.white, size: size),
      onPressed: onPressed, tooltip: t, padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8));
  }

  Widget _buildSpeedButton() {
    return PopupMenuButton<double>(
      initialValue: _speed, tooltip: '倍速',
      color: Theme.of(context).colorScheme.surface,
      onSelected: (r) { _player.setRate(r); setState(() => _speed = r); },
      itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((r) {
        final sel = r == _speed;
        return PopupMenuItem<double>(value: r, child: Text(
          r == 1.0 ? '${r.toStringAsFixed(1)}x  正常' : '${r}x',
          style: TextStyle(fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            color: sel ? AppTheme.primaryColor : Theme.of(context).colorScheme.onSurface)));}).toList(),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(_speed == 1.0 ? '倍速' : '${_speed}x', style: const TextStyle(color: Colors.white, fontSize: 11))),
    );
  }

  Widget _buildSourceSwitchButton() {
    return PopupMenuButton<VideoSource>(
      onSelected: (s) => widget.onSourceChanged?.call(s),
      itemBuilder: (_) => widget.tvSources!.map((s) => PopupMenuItem(
        value: s, child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (s == widget.activeTvSource) const Icon(Icons.check, size: 16, color: AppTheme.primaryColor),
          if (s != widget.activeTvSource) const SizedBox(width: 16),
          const SizedBox(width: 4), Text(s.name),
        ]),
      )).toList(),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.swap_horiz, color: Colors.white, size: 16), const SizedBox(width: 3),
          Text(widget.activeTvSource?.name ?? '源', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ])),
    );
  }

  Widget _buildVolumeControl() {
    return StreamBuilder(stream: _player.stream.volume, builder: (_, snap) {
      final vol = snap.data ?? 100.0;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(vol == 0 ? Icons.volume_off : vol < 50 ? Icons.volume_down : Icons.volume_up, 20,
          () => _player.setVolume(vol > 0 ? 0 : 100)),
        SizedBox(width: 70, child: SliderTheme(data: SliderTheme.of(context).copyWith(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4), trackHeight: 2,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8)),
          child: Slider(value: vol.clamp(0.0, 100.0), min: 0, max: 100,
            onChanged: (v) => _player.setVolume(v),
            activeColor: Colors.white, inactiveColor: Colors.white24))),
      ]);
    });
  }

  Widget _buildEpisodePanel(BuildContext context) {
    final eps = widget.episodes!;
    return Positioned(right: 0, top: 0, bottom: 0, width: 220,
      child: Container(color: const Color(0xDD000000), child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('选集', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              onPressed: () => setState(() => _showEpisodes = false),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
          ]),
        ),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: eps.length,
          itemBuilder: (_, i) {
            final isCur = i == widget.currentEpisodeIndex;
            return ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              selected: isCur, selectedTileColor: Colors.white10,
              title: Text(eps[i].name, style: TextStyle(
                color: isCur ? const Color(0xFF6C63FF) : Colors.white70, fontSize: 12,
                fontWeight: isCur ? FontWeight.w600 : FontWeight.normal)),
              onTap: () { widget.onEpisodeChanged?.call(i); setState(() => _showEpisodes = false); });
          },
        )),
      ])),
    );
  }

  void _prevEpisode() { final i = widget.currentEpisodeIndex ?? 0; if (i > 0) widget.onEpisodeChanged?.call(i - 1); }
  void _nextEpisode() { final i = widget.currentEpisodeIndex ?? 0; final e = widget.episodes; if (e != null && i < e.length - 1) widget.onEpisodeChanged?.call(i + 1); }

  Widget _buildVideoInfoPanel(BuildContext context) {
    return Positioned(right: 0, top: 0, bottom: 0, width: 260,
      child: Container(color: const Color(0xDD111111), child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('视频信息', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              onPressed: () => setState(() => _showVideoInfo = false),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
          ]),
        ),
        const Divider(color: Color(0xFF2E2E35), height: 1),
        Expanded(child: _buildInfoContent()),
      ])),
    );
  }

  Widget _buildInfoContent() {
    // 捕捉当前视频参数（视频信息不随播放变化，无需 StreamBuilder）
    final s = _player.state;
    final vp = s.videoParams;
    final ap = s.audioParams;
    final dur = s.duration;
    final sw = s.width;
    final sh = s.height;

    // 仅 duration 可能初始为 0，用一个 StreamBuilder 监听即可
    return StreamBuilder<Duration>(
      stream: _player.stream.duration,
      builder: (_, durSnap) {
        final currentDur = durSnap.data ?? dur;
        final items = <MapEntry<String, String>>[];
        if (vp.dw != null && vp.dw! > 0) {
          items.add(MapEntry('视频分辨率', '${vp.dw} × ${vp.dh}'));
        } else if (vp.w != null && vp.w! > 0) {
          items.add(MapEntry('视频分辨率', '${vp.w} × ${vp.h}'));
        } else if (sw != null && sw > 0) {
          items.add(MapEntry('视频分辨率', '$sw × $sh'));
        }
        if (vp.aspect != null && vp.aspect! > 0) {
          items.add(MapEntry('显示宽高比', vp.aspect!.toStringAsFixed(2)));
        }
        if (vp.pixelformat != null && vp.pixelformat!.isNotEmpty) {
          items.add(MapEntry('像素格式', vp.pixelformat!));
        }
        if (currentDur.inSeconds > 0) {
          items.add(MapEntry('总时长', _fmt(currentDur)));
        }
        if (s.audioBitrate != null && s.audioBitrate! > 0) {
          items.add(MapEntry('音频码率', '${(s.audioBitrate! / 1000).round()} kbps'));
        }
        if (ap.format != null && ap.format!.isNotEmpty) {
          items.add(MapEntry('音频格式', ap.format!));
        }
        if (ap.sampleRate != null && ap.sampleRate! > 0) {
          items.add(MapEntry('音频采样率', '${ap.sampleRate} Hz'));
        }
        if (ap.hrChannels != null && ap.hrChannels!.isNotEmpty) {
          items.add(MapEntry('音频通道', ap.hrChannels!));
        } else if (ap.channelCount != null && ap.channelCount! > 0) {
          items.add(MapEntry('音频通道', '${ap.channelCount}ch'));
        }
        if (items.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videocam_off, color: Colors.white30, size: 32), SizedBox(height: 12),
              Text('暂无法获取视频信息', style: TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
              SizedBox(height: 6), Text('部分网络视频源不提供详细参数', style: TextStyle(color: Colors.white24, fontSize: 11), textAlign: TextAlign.center),
            ])));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(items[i].key, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 2), Text(items[i].value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              if (i < items.length - 1) const Padding(padding: EdgeInsets.only(top: 8), child: Divider(color: Color(0xFF2E2E35), height: 1)),
            ])));
      },
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours; final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
// ============================================================
// Minimal fullscreen page — basic controls only.
// Source switching and channel browsing are done in normal mode.
// ============================================================
class _FullscreenPlayer extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final String title;
  final bool isTV;
  final List<Episode>? episodes;
  final int? currentEpisodeIndex;
  final ValueChanged<int>? onEpisodeChanged;
  final VoidCallback? onPrevChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback onExit;

  const _FullscreenPlayer({
    required this.player, required this.controller,
    required this.title, required this.isTV,
    this.episodes, this.currentEpisodeIndex,
    this.onEpisodeChanged, this.onPrevChannel, this.onNextChannel,
    required this.onExit,
  });

  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> {
  bool _showControls = true;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _hideControlsAfterDelay();
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 300) {
      _lastTapTime = null;
      widget.onExit();
    } else {
      _lastTapTime = now;
      _toggleControls();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _hideControlsAfterDelay();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.mediaPlayPause): const _TvPlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const _TvPlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _TvVolumeUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _TvVolumeDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _TvSeekBackIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _TvSeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.select): const _TvPlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _TvPlayPauseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TvPlayPauseIntent: CallbackAction<_TvPlayPauseIntent>(
            onInvoke: (_) { widget.player.playOrPause(); return null; }),
          _TvVolumeUpIntent: CallbackAction<_TvVolumeUpIntent>(
            onInvoke: (_) { widget.player.setVolume((widget.player.state.volume + 10).clamp(0, 100)); return null; }),
          _TvVolumeDownIntent: CallbackAction<_TvVolumeDownIntent>(
            onInvoke: (_) { widget.player.setVolume((widget.player.state.volume - 10).clamp(0, 100)); return null; }),
          _TvSeekBackIntent: CallbackAction<_TvSeekBackIntent>(
            onInvoke: (_) { widget.player.seek(widget.player.state.position - const Duration(seconds: 10)); return null; }),
          _TvSeekForwardIntent: CallbackAction<_TvSeekForwardIntent>(
            onInvoke: (_) { widget.player.seek(widget.player.state.position + const Duration(seconds: 10)); return null; }),
        },
        child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _handleTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(builder: (_, c) => Video(
              controller: widget.controller, fit: BoxFit.contain,
              width: c.maxWidth, height: c.maxHeight,
            )),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildOverlay(context),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildOverlay(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x60000000), Colors.transparent, Colors.transparent, Color(0xA0000000)],
        stops: [0.0, 0.03, 0.97, 1.0],
      )),
      child: Column(children: [
        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            Expanded(child: Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
          ]),
        )),
        const Spacer(),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            StreamBuilder(stream: widget.player.stream.position, builder: (_, posSnap) {
              return StreamBuilder(stream: widget.player.stream.duration, builder: (_, durSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = durSnap.data ?? Duration.zero;
                final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  SliderTheme(data: SliderTheme.of(ctx).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 3, overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ), child: Slider(value: progress.clamp(0.0, 1.0),
                    onChanged: (v) => widget.player.seek(Duration(milliseconds: (v * dur.inMilliseconds).toInt())),
                    activeColor: Colors.white, inactiveColor: Colors.white24)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(_fmt(dur), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ]);
              });
            }),
            const SizedBox(height: 2),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (widget.isTV && widget.onPrevChannel != null) _btn(Icons.skip_previous, 26, widget.onPrevChannel!),
              if (!widget.isTV && widget.episodes != null) _btn(Icons.skip_previous, 26, _prevEpisode),
              const SizedBox(width: 12),
              StreamBuilder(stream: widget.player.stream.playing, builder: (_, snap) =>
                _btn((snap.data ?? false) ? Icons.pause : Icons.play_arrow, 36, () => widget.player.playOrPause())),
              const SizedBox(width: 12),
              if (widget.isTV && widget.onNextChannel != null) _btn(Icons.skip_next, 26, widget.onNextChannel!),
              if (!widget.isTV && widget.episodes != null) _btn(Icons.skip_next, 26, _nextEpisode),
              const SizedBox(width: 16),
              _buildVolumeControl(),
              const Spacer(),
              _btn(Icons.fullscreen_exit, 24, widget.onExit, '退出全屏'),
            ]),
            const SizedBox(height: 4),
          ]),
        )),
      ]),
    );
  }

  Widget _btn(IconData icon, double size, VoidCallback onPressed, [String? t]) {
    return IconButton(icon: Icon(icon, color: Colors.white, size: size),
      onPressed: onPressed, tooltip: t, padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8));
  }

  Widget _buildVolumeControl() {
    return StreamBuilder(stream: widget.player.stream.volume, builder: (_, snap) {
      final vol = snap.data ?? 100.0;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(vol == 0 ? Icons.volume_off : vol < 50 ? Icons.volume_down : Icons.volume_up, 20,
          () => widget.player.setVolume(vol > 0 ? 0 : 100)),
        SizedBox(width: 70, child: SliderTheme(data: SliderTheme.of(context).copyWith(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4), trackHeight: 2,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8)),
          child: Slider(value: vol.clamp(0.0, 100.0), min: 0, max: 100,
            onChanged: (v) => widget.player.setVolume(v),
            activeColor: Colors.white, inactiveColor: Colors.white24))),
      ]);
    });
  }

  void _prevEpisode() { final i = widget.currentEpisodeIndex ?? 0; if (i > 0) widget.onEpisodeChanged?.call(i - 1); }
  void _nextEpisode() { final i = widget.currentEpisodeIndex ?? 0; final e = widget.episodes; if (e != null && i < e.length - 1) widget.onEpisodeChanged?.call(i + 1); }

  String _fmt(Duration d) {
    final h = d.inHours; final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── TV remote Intents for the fullscreen player ──
class _TvPlayPauseIntent extends Intent { const _TvPlayPauseIntent(); }
class _TvVolumeUpIntent extends Intent { const _TvVolumeUpIntent(); }
class _TvVolumeDownIntent extends Intent { const _TvVolumeDownIntent(); }
class _TvSeekBackIntent extends Intent { const _TvSeekBackIntent(); }
class _TvSeekForwardIntent extends Intent { const _TvSeekForwardIntent(); }
