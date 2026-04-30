import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralise la langue metier et la locale Material utilisable par Flutter.
class LocaleManager extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  static const String _defaultLocale = 'fr';

  static const List<Locale> supportedLocales = [
    Locale('fr'),
    Locale('ewe'),
    Locale('kab'),
  ];

  static const List<Locale> materialSupportedLocales = [
    Locale('fr'),
  ];

  late Locale _locale;

  LocaleManager() {
    _locale = const Locale(_defaultLocale);
  }

  Locale get locale => _locale;
  Locale get materialLocale => resolveMaterialLocale(_locale);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey) ?? _defaultLocale;
    await setLocale(Locale(savedLocale));
  }

  Future<void> setLocale(Locale newLocale) async {
    _locale = newLocale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, newLocale.languageCode);
  }

  /// Les widgets Material ont besoin d'une locale supportee.
  /// On garde le francais comme base systeme tant que l'app utilise
  /// ses propres traductions metier hors du pipeline Flutter l10n.
  static Locale resolveMaterialLocale(Locale appLocale) {
    switch (appLocale.languageCode) {
      case 'fr':
        return const Locale('fr');
      default:
        return const Locale('fr');
    }
  }

  static String getLanguageName(String code) {
    switch (code) {
      case 'fr':
        return 'Francais';
      case 'ewe':
        return 'Ewe';
      case 'kab':
        return 'Kabiye';
      default:
        return 'Francais';
    }
  }
}
