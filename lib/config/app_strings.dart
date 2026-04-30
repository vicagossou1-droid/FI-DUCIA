import 'dart:convert';
import 'package:flutter/services.dart';

/// Classe pour gérer les traductions
class AppStrings {
  static final AppStrings _instance = AppStrings._internal();
  late Map<String, Map<String, String>> _translations;

  factory AppStrings() {
    return _instance;
  }

  AppStrings._internal();

  /// Initialise les traductions depuis les fichiers ARB
  Future<void> init() async {
    _translations = {
      'fr': await _loadLocale('app_fr'),
      'ewe': await _loadLocale('app_ewe'),
      'kab': await _loadLocale('app_kabiye'),
    };
  }

  /// Charge une locale depuis le fichier ARB
  Future<Map<String, String>> _loadLocale(String locale) async {
    try {
      final jsonStr = await rootBundle.loadString('lib/l10n/$locale.arb');
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return jsonMap.cast<String, String>();
    } catch (e) {
      return {};
    }
  }

  /// Obtient une traduction
  String get(String key, [String locale = 'fr']) {
    final localeMap = _translations[locale];
    if (localeMap == null) {
      return key; // Fallback au français si la locale n'existe pas
    }
    return localeMap[key] ?? key;
  }

  /// Alias pour get (syntaxe plus courte)
  String call(String key, [String locale = 'fr']) => get(key, locale);
}

final appStrings = AppStrings();
