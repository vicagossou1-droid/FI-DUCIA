import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'fu_dicia.db');
    return openDatabase(path, version: 2, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE scans (
          id TEXT PRIMARY KEY,
          client_id TEXT NOT NULL,
          collectrice_id TEXT NOT NULL,
          montant REAL NOT NULL,
          photo_path TEXT,
          photo_url TEXT,
          latitude REAL,
          longitude REAL,
          gps_valide INTEGER DEFAULT 0,
          scanned_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE clients_jour (
          client_id TEXT PRIMARY KEY,
          scan_count INTEGER DEFAULT 0,
          last_scan TEXT
        )
      ''');

      // NOUVELLES TABLES GPS
      await db.execute('''
        CREATE TABLE gps_track_points (
          id TEXT PRIMARY KEY,
          collectrice_id TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          accuracy REAL NOT NULL,
          timestamp TEXT NOT NULL,
          altitude REAL,
          speed REAL,
          synced INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE client_geofences (
          client_id TEXT PRIMARY KEY,
          center_lat REAL NOT NULL,
          center_lng REAL NOT NULL,
          radius_meters REAL DEFAULT 50.0,
          created_at TEXT NOT NULL,
          scan_count INTEGER DEFAULT 3
        )
      ''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      // Migration vers v2 : ajouter tables GPS
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE gps_track_points (
            id TEXT PRIMARY KEY,
            collectrice_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL NOT NULL,
            timestamp TEXT NOT NULL,
            altitude REAL,
            speed REAL,
            synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE client_geofences (
            client_id TEXT PRIMARY KEY,
            center_lat REAL NOT NULL,
            center_lng REAL NOT NULL,
            radius_meters REAL DEFAULT 50.0,
            created_at TEXT NOT NULL,
            scan_count INTEGER DEFAULT 3
          )
        ''');
      }
    });
  }

  // ── SCANS ──
  static Future<void> insertScan(ScanRecord scan) async {
    final database = await db;
    await database.insert('scans', scan.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<ScanRecord>> getUnsynced() async {
    final database = await db;
    final rows = await database.query('scans', where: 'synced = 0');
    return rows.map(ScanRecord.fromMap).toList();
  }

  static Future<void> markSynced(String id) async {
    final database = await db;
    await database.update('scans', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<ScanRecord>> getTodayScans(String collectriceId) async {
    final database = await db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await database.query(
      'scans',
      where: "collectrice_id = ? AND scanned_at LIKE ?",
      whereArgs: [collectriceId, '$today%'],
      orderBy: 'scanned_at DESC',
    );
    return rows.map(ScanRecord.fromMap).toList();
  }

  // ── CLIENTS DU JOUR ──
  static Future<int> getScanCount(String clientId) async {
    final database = await db;
    final rows = await database
        .query('clients_jour', where: 'client_id = ?', whereArgs: [clientId]);
    if (rows.isEmpty) return 0;
    return rows.first['scan_count'] as int;
  }

  static Future<bool> alreadyScannedToday(String clientId) async {
    final count = await getScanCount(clientId);
    return count > 0;
  }

  static Future<void> incrementScanCount(String clientId) async {
    final database = await db;
    final existing = await database
        .query('clients_jour', where: 'client_id = ?', whereArgs: [clientId]);
    if (existing.isEmpty) {
      await database.insert('clients_jour', {
        'client_id': clientId,
        'scan_count': 1,
        'last_scan': DateTime.now().toIso8601String(),
      });
    } else {
      final current = existing.first['scan_count'] as int;
      await database.update(
        'clients_jour',
        {
          'scan_count': current + 1,
          'last_scan': DateTime.now().toIso8601String()
        },
        where: 'client_id = ?',
        whereArgs: [clientId],
      );
    }
  }

  static Future<void> resetJour() async {
    final database = await db;
    await database.delete('clients_jour');
  }

  // ── GPS TRACKING ──
  static Future<void> insertGpsTrackPoint(GpsTrackPoint point) async {
    final database = await db;
    await database.insert('gps_track_points', point.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<GpsTrackPoint>> getUnsyncedTrackPoints(
      String collectriceId,
      {int limit = 50}) async {
    final database = await db;
    final maps = await database.query(
      'gps_track_points',
      where: 'collectrice_id = ? AND synced = 0',
      whereArgs: [collectriceId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map((m) => GpsTrackPoint.fromMap(m)).toList();
  }

  static Future<int> getUnsyncedTrackPointsCount(String collectriceId) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM gps_track_points WHERE collectrice_id = ? AND synced = 0',
      [collectriceId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> markTrackPointSynced(String pointId) async {
    final database = await db;
    await database.update(
      'gps_track_points',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [pointId],
    );
  }

  static Future<List<GpsTrackPoint>> getTrackPointsForDate(
      String collectriceId, DateTime date) async {
    final database = await db;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final maps = await database.query(
      'gps_track_points',
      where: 'collectrice_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        collectriceId,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String()
      ],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => GpsTrackPoint.fromMap(m)).toList();
  }

  // ── GEOFENCING ──
  static Future<void> insertClientGeofence(ClientGeofence geofence) async {
    final database = await db;
    await database.insert('client_geofences', geofence.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateClientGeofence(ClientGeofence geofence) async {
    final database = await db;
    await database.update(
      'client_geofences',
      geofence.toMap(),
      where: 'client_id = ?',
      whereArgs: [geofence.clientId],
    );
  }

  static Future<ClientGeofence?> getClientGeofence(String clientId) async {
    final database = await db;
    final maps = await database.query(
      'client_geofences',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
    if (maps.isEmpty) return null;
    return ClientGeofence.fromMap(maps.first);
  }

  static Future<List<ClientGeofence>> getAllClientGeofences() async {
    final database = await db;
    final maps = await database.query('client_geofences');
    return maps.map((m) => ClientGeofence.fromMap(m)).toList();
  }

  static Future<int> getClientScanCount(String clientId) async {
    final database = await db;
    final maps = await database.query(
      'clients_jour',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
    if (maps.isEmpty) return 0;
    return maps.first['scan_count'] as int? ?? 0;
  }

  // ── STATISTIQUES GPS ──
  static Future<Map<String, dynamic>> getGpsStats(String collectriceId) async {
    // Points trackés aujourd'hui
    final today = DateTime.now();
    final trackPointsToday = await getTrackPointsForDate(collectriceId, today);

    // Points non synchronisés
    final unsyncedCount = await getUnsyncedTrackPointsCount(collectriceId);

    // Zones géographiques définies
    final geofences = await getAllClientGeofences();

    return {
      'track_points_today': trackPointsToday.length,
      'unsynced_points': unsyncedCount,
      'geofences_defined': geofences.length,
      'avg_accuracy': trackPointsToday.isEmpty
          ? 0.0
          : trackPointsToday.map((p) => p.accuracy).reduce((a, b) => a + b) /
              trackPointsToday.length,
    };
  }
}
