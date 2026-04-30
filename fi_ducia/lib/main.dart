import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_controller.dart';
import 'core/app_env.dart';
import 'core/app_theme.dart';
import 'core/platform_support.dart';
import 'collect_home_screen.dart';
import 'debug_location_screen.dart';
import 'l10n/app_localizations.dart';
import 'services/database_service.dart';
import 'services/location_batch_buffer.dart';
import 'services/location_service.dart';

/// Set to `true` only when you need the full diagnostic dashboard:
/// `flutter run --dart-define=DEBUG_DASHBOARD=true`
const bool _kDebugDashboard =
    bool.fromEnvironment('DEBUG_DASHBOARD', defaultValue: false);

final _FiduciaLifecycleBinding _fiduciaLifecycle = _FiduciaLifecycleBinding();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addObserver(_fiduciaLifecycle);
  await AppEnv.load();

  if (PlatformSupport.isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
      await DatabaseService.instance.initialize();
      await LocationService.instance.initializeBackgroundTracking();
    } catch (error) {
      debugPrint('[FIDUCIA][BOOT] Startup initialization failed: $error');
    }
  }

  runApp(
    FiduciaApp(
      controller: FiduciaAppController(),
    ),
  );
}

class FiduciaApp extends StatelessWidget {
  const FiduciaApp({
    super.key,
    required this.controller,
  });

  final FiduciaAppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'FI-DUCIA',
          debugShowCheckedModeBanner: false,
          theme: FiduciaTheme.light(),
          darkTheme: FiduciaTheme.dark(),
          themeMode: controller.themeMode,
          locale: controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (BuildContext context, Widget? child) {
            final Brightness brightness = _brightnessForThemeMode(
              controller.themeMode,
            );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: FiduciaTheme.systemUiOverlayForBrightness(brightness),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _kDebugDashboard
              ? DebugLocationScreen(controller: controller)
              : CollectHomeScreen(controller: controller),
        );
      },
    );
  }
}

Brightness _brightnessForThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }
}

class _FiduciaLifecycleBinding with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(LocationBatchBuffer.instance.flush());
    }
  }
}
