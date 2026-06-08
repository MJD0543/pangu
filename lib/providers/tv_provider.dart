import 'package:flutter/material.dart';
import '../models/source_model.dart';
import '../services/tv_source_service.dart';

class TvProvider extends ChangeNotifier {
  final _service = TvSourceService();

  List<TvChannel> _channels = [];
  Map<String, List<TvChannel>> _groups = {};
  TvChannel? _currentChannel;
  bool _isLoading = false;
  String? _error;
  List<String> get groupNames => _groups.keys.toList();

  List<TvChannel> get channels => _channels;
  Map<String, List<TvChannel>> get groups => _groups;
  TvChannel? get currentChannel => _currentChannel;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFromSource(VideoSource source) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _service.parseFromUrl(source.url);
      _channels = list;
      _buildGroups();
      if (_channels.isNotEmpty && _currentChannel == null) {
        _currentChannel = _channels.first;
      }
    } catch (e) {
      _error = '加载失败: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  void _buildGroups() {
    _groups = {};
    for (final ch in _channels) {
      final g = ch.group ?? '未分组';
      _groups.putIfAbsent(g, () => []).add(ch);
    }
  }

  void selectChannel(TvChannel ch) {
    _currentChannel = ch;
    notifyListeners();
  }

  void nextChannel() {
    if (_channels.isEmpty) return;
    final idx = _channels.indexOf(_currentChannel ?? _channels.first);
    _currentChannel = _channels[(idx + 1) % _channels.length];
    notifyListeners();
  }

  void prevChannel() {
    if (_channels.isEmpty) return;
    final idx = _channels.indexOf(_currentChannel ?? _channels.first);
    _currentChannel = _channels[(idx - 1 + _channels.length) % _channels.length];
    notifyListeners();
  }
}
