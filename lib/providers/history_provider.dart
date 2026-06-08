import 'package:flutter/material.dart';
import '../models/source_model.dart';
import '../services/database_service.dart';

class HistoryProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<WatchHistory> _histories = [];
  bool _isLoading = false;

  List<WatchHistory> get histories => _histories;
  bool get isLoading => _isLoading;

  HistoryProvider() { load(); }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _histories = await _db.getWatchHistory();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addHistory(WatchHistory h) async {
    await _db.insertOrUpdateWatchHistory(h);
    await load();
  }

  Future<void> deleteHistory(int id) async {
    await _db.deleteWatchHistory(id);
    await load();
  }

  Future<void> clearAll() async {
    await _db.clearWatchHistory();
    await load();
  }
}
