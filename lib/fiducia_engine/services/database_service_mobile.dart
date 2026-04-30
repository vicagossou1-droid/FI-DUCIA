import 'package:sqflite/sqflite.dart';

import '../models/client_model.dart';
import '../models/location_model.dart';
import 'database_paths.dart';
import 'location_batch_buffer.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String locationsTableName = 'locations';
  static const String clientsTableName = 'clients';
  static const String clientScansTableName = 'client_scans';
  static const String geofenceAlertsTableName = 'geofence_alerts';
  static const String syncBatchesTableName = 'sync_batches';

  static const int _databaseVersion = 3;
  static const double _defaultRadiusMeters = 50;

  Database? _database;

  /// Low-level handle for transactional batching (Android only callers).
  Future<dynamic> get connection async => database;

  Future<void> initialize() async {
    await database;
  }

  Future<Database> get database async {
    _database ??= await _openDatabase();
    return _database!;
  }

  Future<String> getDatabaseFilePath() => FiduciaDatabasePaths.absolutePath();

  Future<Database> _openDatabase() async {
    final path = await FiduciaDatabasePaths.absolutePath();

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (Database db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
        await db.execute('PRAGMA synchronous=NORMAL;');
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $locationsTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            pending_export INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE $clientsTableName (
            id TEXT PRIMARY KEY,
            centerLat REAL,
            centerLng REAL,
            radius REAL NOT NULL DEFAULT $_defaultRadiusMeters,
            photo_path TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $clientScansTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            clientId TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            FOREIGN KEY (clientId) REFERENCES $clientsTableName(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE $geofenceAlertsTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            gps_timestamp INTEGER NOT NULL,
            distance_m REAL,
            radius_m REAL,
            justification TEXT,
            created_ms INTEGER NOT NULL,
            pending_export INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE $syncBatchesTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_ms INTEGER NOT NULL,
            item_count INTEGER NOT NULL,
            is_encrypted INTEGER NOT NULL,
            payload BLOB NOT NULL,
            uploaded INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_locations_timestamp '
          'ON $locationsTableName(timestamp DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_client_scans_client_timestamp '
          'ON $clientScansTableName(clientId, timestamp)',
        );
        await db.execute(
          'CREATE INDEX idx_geofence_alerts_client '
          'ON $geofenceAlertsTableName(client_id, created_ms DESC)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $locationsTableName '
            'ADD COLUMN pending_export INTEGER NOT NULL DEFAULT 1',
          );

          await db.execute('''
            CREATE TABLE $geofenceAlertsTableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              client_id TEXT NOT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              gps_timestamp INTEGER NOT NULL,
              distance_m REAL,
              radius_m REAL,
              justification TEXT,
              created_ms INTEGER NOT NULL,
              pending_export INTEGER NOT NULL DEFAULT 1
            )
          ''');

          await db.execute('''
            CREATE TABLE $syncBatchesTableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              created_ms INTEGER NOT NULL,
              item_count INTEGER NOT NULL,
              is_encrypted INTEGER NOT NULL,
              payload BLOB NOT NULL,
              uploaded INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_geofence_alerts_client '
            'ON $geofenceAlertsTableName(client_id, created_ms DESC)',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $clientsTableName ADD COLUMN photo_path TEXT',
          );
        }
      },
    );
  }

  Future<int> insertLocation(LocationModel location) async {
    await LocationBatchBuffer.instance.enqueue(location);
    return 0;
  }

  Future<void> ensureClientExists(String clientId) async {
    final db = await database;
    await db.insert(clientsTableName, <String, Object?>{
      'id': clientId,
      'radius': _defaultRadiusMeters,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> insertClientScan({
    required String clientId,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    final db = await database;
    await ensureClientExists(clientId);

    return db.insert(clientScansTableName, <String, Object?>{
      'clientId': clientId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
    });
  }

  Future<int> getClientScanCount(String clientId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $clientScansTableName WHERE clientId = ?',
      <Object?>[clientId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, Object?>>> getEarliestClientScans(
    String clientId, {
    int limit = 3,
  }) async {
    final db = await database;
    return db.query(
      clientScansTableName,
      where: 'clientId = ?',
      whereArgs: <Object?>[clientId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  Future<ClientModel?> getClient(String clientId) async {
    final db = await database;
    final result = await db.query(
      clientsTableName,
      where: 'id = ?',
      whereArgs: <Object?>[clientId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return ClientModel.fromMap(result.first);
  }

  Future<void> upsertClient(ClientModel client) async {
    final db = await database;
    final rowsUpdated = await db.update(
      clientsTableName,
      client.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[client.id],
    );

    if (rowsUpdated == 0) {
      await db.insert(
        clientsTableName,
        client.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<LocationModel?> getLatestLocation() async {
    final db = await database;
    final result = await db.query(
      locationsTableName,
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return LocationModel.fromMap(result.first);
  }

  Future<int> insertGeofenceAlert({
    required String clientId,
    required double latitude,
    required double longitude,
    required DateTime gpsTimestamp,
    double? distanceMeters,
    double? radiusMeters,
  }) async {
    final db = await database;
    return db.insert(geofenceAlertsTableName, <String, Object?>{
      'client_id': clientId,
      'latitude': latitude,
      'longitude': longitude,
      'gps_timestamp': gpsTimestamp.millisecondsSinceEpoch,
      'distance_m': distanceMeters,
      'radius_m': radiusMeters,
      'justification': null,
      'created_ms': gpsTimestamp.toUtc().millisecondsSinceEpoch,
      'pending_export': 1,
    });
  }

  Future<void> updateGeofenceAlertJustification({
    required int alertLocalId,
    required String justification,
  }) async {
    final db = await database;
    await db.update(
      geofenceAlertsTableName,
      <String, Object?>{'justification': justification},
      where: 'id = ?',
      whereArgs: <Object?>[alertLocalId],
    );
  }

  Future<int> countPendingUploadBatches() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $syncBatchesTableName WHERE uploaded = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
