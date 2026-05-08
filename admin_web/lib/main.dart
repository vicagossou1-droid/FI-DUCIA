import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_strategy/url_strategy.dart';

import 'layout/main_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://ppooswsfrqdqkjfzqocy.supabase.co',
    anonKey: 'sb_publishable_3RKgITu39ay5qvyku3hU-g_lDGvW-Z1',
  );

  setPathUrlStrategy();
  runApp(
    const ProviderScope(
      child: AdminWebApp(),
    ),
  );
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiducia Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981), // Emerald
          secondary: Color(0xFFF59E0B), // Amber
          surface: Color(0xFF1E293B), // Slate 800
        ),
      ),
      home: const MainLayout(),
    );
  }
}
