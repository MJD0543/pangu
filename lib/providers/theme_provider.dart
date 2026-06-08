import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode') ?? 'system';
    _mode = {'light': ThemeMode.light, 'dark': ThemeMode.dark}[stored] ?? ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    final prefs = await SharedPreferences.getInstance();
    final key = {ThemeMode.light: 'light', ThemeMode.dark: 'dark'}[m] ?? 'system';
    await prefs.setString('theme_mode', key);
    notifyListeners();
  }
}
