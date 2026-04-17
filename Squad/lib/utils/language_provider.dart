import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar');  // ← CHANGED: Default to Arabic

  Locale get locale => _locale;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  // Load saved language from SharedPreferences
  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'ar';  // ← CHANGED: Default to 'ar'
    _locale = Locale(languageCode);
    notifyListeners();
  }

  // Change language and save to SharedPreferences
  Future<void> changeLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
  }

  // Toggle between English and Arabic
  Future<void> toggleLanguage() async {
    final newLanguage = _locale.languageCode == 'en' ? 'ar' : 'en';
    await changeLanguage(newLanguage);
  }
}
