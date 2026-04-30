import 'package:flutter/material.dart';

class FiduciaAppController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('fr');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }

    _themeMode = value;
    notifyListeners();
  }

  void setLocale(Locale value) {
    if (_locale == value) {
      return;
    }

    _locale = value;
    notifyListeners();
  }
}
