import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WThemeMode { dark, light }

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  WThemeMode _mode = WThemeMode.dark;
  WThemeMode get mode => _mode;
  bool get isLight => _mode == WThemeMode.light;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode') ?? 'dark';
    _mode = modeStr == 'light' ? WThemeMode.light : WThemeMode.dark;
    notifyListeners();
  }

  Future<void> setMode(WThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }
}
