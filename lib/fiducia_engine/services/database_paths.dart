import 'package:sqflite/sqflite.dart';

/// Nom et chemin fichier SQLite (partagé sans cycle d’import).
class FiduciaDatabasePaths {
  FiduciaDatabasePaths._();

  static const String fileName = 'fiducia.db';
  static const String locationsTableName = 'locations';

  static Future<String> absolutePath() async {
    final String dir = await getDatabasesPath();
    return '$dir/$fileName';
  }
}
