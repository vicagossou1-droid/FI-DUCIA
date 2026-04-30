import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv._();

  static bool _loaded = false;

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } catch (error) {
      debugPrint('[FIDUCIA][ENV] .env not loaded: $error');
    }
  }

  static bool get isLoaded => _loaded;

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Symmetric key for AES-256 batch sealing (>= 8 chars recommended).
  static String get syncEncryptionKeyRaw =>
      dotenv.env['SYNC_ENCRYPTION_KEY'] ?? '';

  static bool get hasSyncEncryptionKey =>
      syncEncryptionKeyRaw.trim().length >= 8;

  /// 32 bytes for AES-256 (padded / truncated deterministically from env).
  static List<int> get syncEncryptionKeyBytes {
    final raw = utf8.encode(syncEncryptionKeyRaw.trim());
    if (raw.isEmpty) {
      return List<int>.filled(32, 0);
    }
    if (raw.length >= 32) {
      return raw.sublist(0, 32);
    }
    final out = List<int>.filled(32, 0);
    for (var i = 0; i < 32; i++) {
      out[i] = raw[i % raw.length];
    }
    return out;
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get supabaseHost {
    if (supabaseUrl.isEmpty) {
      return '';
    }

    try {
      return Uri.parse(supabaseUrl).host;
    } catch (_) {
      return supabaseUrl;
    }
  }
}
