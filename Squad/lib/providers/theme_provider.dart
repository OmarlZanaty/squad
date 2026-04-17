import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad/utils/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  // Default to dark mode
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider() {
    _loadThemePreference();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Load saved theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? true; // Default to true (dark mode)
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }

  // Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;

    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    } catch (e) {
      print('Error saving theme preference: $e');
    }

    notifyListeners();
  }

  // Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
    } catch (e) {
      print('Error saving theme preference: $e');
    }

    notifyListeners();
  }

  // Set dark mode explicitly
  Future<void> setDarkMode(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDark);
    } catch (e) {
      print('Error saving theme preference: $e');
    }

    notifyListeners();
  }

  // Light Theme - uses AppColors
  static ThemeData get lightTheme => AppColors.lightTheme;

  // Dark Theme - uses AppColors
  static ThemeData get darkTheme => AppColors.darkTheme;
}
