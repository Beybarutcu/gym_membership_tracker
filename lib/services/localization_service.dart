import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  static Map<String, String> _translations = {};
  static bool _initialized = false;
  static Locale _currentLocale = const Locale('tr', 'TR');

  factory LocalizationService() => _instance;

  LocalizationService._internal();

  static Future<void> init() async {
    if (_initialized) return;
    
    try {
      // Load translations from asset
      final jsonString = await rootBundle.loadString('assets/l10n-file.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      
      // Convert all values to strings
      _translations = jsonMap.map((key, value) => MapEntry(key, value.toString()));
      _initialized = true;
      print("LocalizationService: Successfully loaded ${_translations.length} translations");
    } catch (e) {
      print("LocalizationService: Error loading translations: $e");
      // Initialize with empty map to prevent errors
      _translations = {};
    }
  }
  
  static bool get isInitialized => _initialized;
  static Locale get currentLocale => _currentLocale;

  // Get a localized string
  static String get(String key) {
    if (!_initialized) {
      print("LocalizationService: Warning - trying to access translations before initialization");
      return key;
    }
    
    if (_translations.containsKey(key)) {
      return _translations[key] ?? key;
    }
    
    // For debugging - log missing keys
    print("LocalizationService: Missing translation key: '$key'");
    return key;
  }
  
  // Debug method to print all loaded keys
  static void logAllKeys() {
    print("LocalizationService: All loaded keys (${_translations.length}):");
    _translations.forEach((key, value) {
      print(" - $key: $value");
    });
  }
}

// Extension on String for easy localization
extension LocalizationExtension on String {
  String get tr {
    return LocalizationService.get(this);
  }
}