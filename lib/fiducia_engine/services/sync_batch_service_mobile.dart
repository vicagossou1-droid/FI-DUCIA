import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:sqflite/sqflite.dart';

import '../core/app_env.dart';
import '../core/platform_support.dart';
import 'database_service.dart';

/// Android: seal up to [batchSize] passive GPS rows into `sync_batches`.
class SyncBatchService {
  SyncBatchService._();

  static final SyncBatchService instance = SyncBatchService._();

  static const int batchSize = 10;

  Future<void> maybeCreateLocationBatches() async {
    if (!PlatformSupport.isAndroid) {
      return;
    }

    while (await _trySealOneLocationBatch()) {
      // Keep sealing while there are enough pending rows.
    }
  }

  Future<bool> _trySealOneLocationBatch() async {
    final db = await DatabaseService.instance.connection as Database;

    var sealed = false;
    await db.transaction((txn) async {
      final rows = await txn.query(
        DatabaseService.locationsTableName,
        columns: <String>['id', 'latitude', 'longitude', 'accuracy', 'timestamp'],
        where: 'pending_export = ?',
        whereArgs: <Object?>[1],
        orderBy: 'id ASC',
        limit: batchSize,
      );

      if (rows.length < batchSize) {
        return;
      }

      final payloadMaps = rows
          .map(
            (row) => <String, Object?>{
              'id': row['id'],
              'latitude': row['latitude'],
              'longitude': row['longitude'],
              'accuracy': row['accuracy'],
              'gps_timestamp_ms': row['timestamp'],
            },
          )
          .toList();

      final json = jsonEncode(payloadMaps);
      final plainBytes = Uint8List.fromList(utf8.encode(json));

      final bool isEncrypted = AppEnv.hasSyncEncryptionKey;
      final Uint8List storedBytes =
          isEncrypted ? _encryptAesCbc(plainBytes) : plainBytes;

      int createdFromGps = 0;
      for (final Map<String, Object?> row in rows) {
        final int ts = row['timestamp'] as int;
        if (ts > createdFromGps) {
          createdFromGps = ts;
        }
      }

      await txn.insert(
        DatabaseService.syncBatchesTableName,
        <String, Object?>{
          'created_ms': createdFromGps,
          'item_count': rows.length,
          'is_encrypted': isEncrypted ? 1 : 0,
          'payload': storedBytes,
          'uploaded': 0,
        },
      );

      final ids = rows.map((row) => row['id'] as int).toList();
      final placeholders = List<String>.filled(ids.length, '?').join(',');
      await txn.rawUpdate(
        'UPDATE ${DatabaseService.locationsTableName} '
        'SET pending_export = 0 WHERE id IN ($placeholders)',
        ids,
      );

      sealed = true;
    });

    return sealed;
  }

  Uint8List _encryptAesCbc(Uint8List plain) {
    final key = enc.Key(Uint8List.fromList(AppEnv.syncEncryptionKeyBytes));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plain, iv: iv);
    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(iv.bytes.length, encrypted.bytes);
    return combined;
  }
}
