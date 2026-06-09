import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Map<String, Map<String, String>> _translations = {};
  Locale _locale = Locale('en');

  Locale get locale => _locale;

  Future<void> init() async {
    await loadSavedLanguage();
  }

  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String langCode = prefs.getString('language') ?? 'en';
      await setLanguage(Locale(langCode));
    } catch (e) {
      print('Error loading language: $e');
      await setLanguage(Locale('en'));
    }
  }

  Future<void> setLanguage(Locale newLocale) async {
    _locale = newLocale;
    _translations.clear();

    // List all JSON files for this language
    List<String> files = [
      'common',
      'auth',
      'service',
      'bookings',
      'profile',
      'language',
      'notifications',
      'posts',
      'chat',
      'disscussion',
      'provider_profile',
      'providers_list_page',
      'home_categories',
      'create_service_button',
      'home_constants',
      'subcategories_page',
      'home_page',
      'categories',
      'nav_bottom',
      'search',
      'my_services',
      'edit_service',
      'auth_service',
      'booking_notification_service'
    ];

    // Load each JSON file
    for (String file in files) {
      try {
        String data = await rootBundle.loadString(
          'assets/translations/${newLocale.languageCode}/$file.json',
        );
        Map<String, dynamic> parsed = json.decode(data);

        // Convert to Map<String, String>
        Map<String, String> stringMap = {};
        parsed.forEach((key, value) {
          stringMap[key] = value.toString();
        });

        _translations[file] = stringMap;
      } catch (e) {
        print('Error loading $file.json for ${newLocale.languageCode}: $e');
      }
    }

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', newLocale.languageCode);

    // ✅ INTELLIGENT FLAG: Mark initial setup as completed if this is the first language selection
    final hasCompletedSetup =
        prefs.getBool('hasCompletedInitialSetup') ?? false;
    if (!hasCompletedSetup) {
      await prefs.setBool('hasCompletedInitialSetup', true);
      print(
          '✅ Initial setup completed - language selection will never show again');
    }

    notifyListeners();
  }

  // ✅ NEW METHOD: Check if user has completed initial language setup
  Future<bool> hasCompletedInitialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasCompletedInitialSetup') ?? false;
  }

  // ✅ NEW METHOD: Reset language setup (useful for testing)
  Future<void> resetLanguageSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hasCompletedInitialSetup');
    await prefs.remove('language');
    print(
        '🔄 Language setup reset - will show language selection on next launch');
  }

  // Get translation with category
  String tr(String key, {required String category}) {
    if (_translations.containsKey(category)) {
      return _translations[category]![key] ?? key;
    }
    return key;
  }

  // Get translation with parameters - FIXED to use {{key}} instead of {key}
  String trParams(String key,
      {required String category, Map<String, String>? params}) {
    String text = tr(key, category: category);
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{{$key}}', value);
      });
    }
    return text;
  }

  // Get current language name
  String get currentLanguageName {
    switch (_locale.languageCode) {
      case 'en':
        return tr('english', category: 'language');
      case 'fr':
        return tr('french', category: 'language');
      case 'ar':
        return tr('arabic', category: 'language');
      default:
        return 'English';
    }
  }

  // Check if current language is RTL
  bool get isRtl {
    return _locale.languageCode == 'ar';
  }
}
