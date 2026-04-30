import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/config.dart';
import 'config/locale_manager.dart';
import 'config/app_strings.dart';
import 'services/photo_service.dart';
import 'services/gps_service.dart';
import 'screens/auth/auth_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(AppColors.bg),
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await initializeDateFormatting('fr_FR', null);
  await appStrings.init();

  final localeManager = LocaleManager();
  await localeManager.init();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await PhotoService.init();

  runApp(FuDiciaApp(localeManager: localeManager));
}

class FuDiciaApp extends StatefulWidget {
  final LocaleManager localeManager;

  const FuDiciaApp({super.key, required this.localeManager});

  @override
  State<FuDiciaApp> createState() => _FuDiciaAppState();
}

class _FuDiciaAppState extends State<FuDiciaApp> {
  late LocaleManager _localeManager;

  @override
  void initState() {
    super.initState();
    _localeManager = widget.localeManager;
    _localeManager.addListener(_onLocaleChange);
  }

  void _onLocaleChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _localeManager.removeListener(_onLocaleChange);
    // Nettoyer GPS quand l'app se ferme
    GpsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FI-DUCIA',
      debugShowCheckedModeBanner: false,
      locale: _localeManager.materialLocale,
      supportedLocales: LocaleManager.materialSupportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(AppColors.bg),
        colorScheme: const ColorScheme.dark(
          primary: Color(AppColors.blue),
          secondary: Color(AppColors.green),
          error: Color(AppColors.red),
          surface: Color(AppColors.bg2),
        ),
        useMaterial3: true,
      ),
      home: SplashScreen(localeManager: _localeManager),
    );
  }
}
