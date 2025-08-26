import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const _key = 'theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_key);
    if (v == 'light') mode.value = ThemeMode.light;
    if (v == 'dark') mode.value = ThemeMode.dark;
    if (v == 'system') mode.value = ThemeMode.system;
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    final sp = await SharedPreferences.getInstance();
    final v = m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system';
    await sp.setString(_key, v);
  }
}
