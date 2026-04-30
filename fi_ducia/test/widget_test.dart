import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fi_ducia/core/app_controller.dart';

void main() {
  test('FiduciaAppController defaults to French and system theme', () {
    final controller = FiduciaAppController();

    expect(controller.locale, const Locale('fr'));
    expect(controller.themeMode, ThemeMode.system);
  });
}
