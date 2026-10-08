import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static const String _prefKey = 'app_language';
  static LocalizationService? _instance;

  Map<String, dynamic> _translations = {};
  String _currentLanguage = 'ar';

  static LocalizationService get instance {
    _instance ??= LocalizationService._();
    return _instance!;
  }

  LocalizationService._();

  String get currentLanguage => _currentLanguage;
  bool get isArabic => _normalizedLanguage(_currentLanguage) == 'ar';
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  String _normalizedLanguage(String lang) {
    final code = lang.trim().toLowerCase().split('_').first.split('-').first;
    return code == 'ar' ? 'ar' : 'en';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String? savedLang = prefs.getString(_prefKey);
    print('🌍 Saved language from prefs: $savedLang');
    print('🌍 All prefs keys: ${prefs.getKeys()}');

    if (savedLang != null) {
      _currentLanguage = savedLang;
    } else {
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      _currentLanguage = deviceLocale.languageCode == 'ar' ? 'ar' : 'en';
      print(
        '🌍 Device locale: ${deviceLocale.languageCode}, set to: $_currentLanguage',
      );
    }

    print('🌍 Final language: $_currentLanguage');
    await _loadTranslations(_currentLanguage);
  }

  Future<void> _loadTranslations(String lang) async {
    try {
      final String jsonString =
          await rootBundle.loadString('lib/l10n/$lang.json');
      _translations = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading translations: $e');
      _translations = {};
    }
  }

  Future<void> changeLanguage(String lang) async {
    final normalized = _normalizedLanguage(lang);
    if (_currentLanguage == normalized) return;
    _currentLanguage = normalized;
    await _loadTranslations(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, normalized);
    debugPrint(
      '🌍 Language changed to: $_currentLanguage, isArabic: $isArabic, direction: $textDirection',
    );
    notifyListeners();
  }

  /// ترجمة مفتاح بصيغة نقطية، مع استبدال اختياري لمتغيرات داخل النص.
  ///
  /// المتغيرات تُكتب في ملف الترجمة بين أقواس معقوفة:
  /// ```json
  /// { "chat": { "minutes_ago": "منذ {n} دقيقة" } }
  /// ```
  /// ```dart
  /// tr('chat.minutes_ago', {'n': 5})  // منذ 5 دقيقة
  /// ```
  /// وده أفضل من تقسيم الجملة لبادئة ولاحقة، لأن ترتيب الكلمات بيختلف
  /// بين العربي والإنجليزي.
  String tr(String key, [Map<String, dynamic>? params]) {
    final keys = key.split('.');
    dynamic value = _translations;
    for (final k in keys) {
      if (value is Map) {
        value = value[k];
      } else {
        return key;
      }
    }

    var result = value?.toString() ?? key;
    if (params != null) {
      params.forEach((name, replacement) {
        result = result.replaceAll('{$name}', replacement.toString());
      });
    }
    return result;
  }
}

String tr(String key, [Map<String, dynamic>? params]) =>
    LocalizationService.instance.tr(key, params);
