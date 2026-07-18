import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void _notify() {
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    _themeMode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _notify();
  }

  Future<void> setLight() async {
    _themeMode = ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'light');
    _notify();
  }

  Future<void> setDark() async {
    _themeMode = ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'dark');
    _notify();
  }

  Future<void> setSystem() async {
    _themeMode = ThemeMode.system;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'system');
    _notify();
  }
}
