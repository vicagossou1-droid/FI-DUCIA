import 'dart:collection';

import '../core/platform_support.dart';
import '../core/result.dart';
import '../models/location_model.dart';
import 'database_paths.dart';
import 'database_write_isolate.dart';
import 'sync_batch_service.dart';

/// Tampon RAM pour les points passifs : écriture SQLite par lots (isolate) sans bloquer l’UI.
class LocationBatchBuffer {
  LocationBatchBuffer._();

  static final LocationBatchBuffer instance = LocationBatchBuffer._();

  static const int flushThreshold = 5;

  final ListQueue<LocationModel> _pending = ListQueue<LocationModel>();
  bool _flushInFlight = false;

  int get pendingCount => _pending.length;

  /// Ajoute un point ; déclenche un flush si le seuil est atteint.
  Future<void> enqueue(LocationModel location) async {
    _pending.addLast(location);
    if (_pending.length >= flushThreshold) {
      await flush();
    }
  }

  /// Vide tout le tampon (ex. mise en arrière-plan).
  Future<Result<int, String>> flush() async {
    if (!PlatformSupport.isAndroid) {
      return const Success<int, String>(0);
    }
    if (_pending.isEmpty) {
      return const Success<int, String>(0);
    }
    if (_flushInFlight) {
      return const Success<int, String>(0);
    }
    _flushInFlight = true;
    try {
      final List<LocationModel> batch = <LocationModel>[];
      while (_pending.isNotEmpty) {
        batch.add(_pending.removeFirst());
      }
      final String path = await FiduciaDatabasePaths.absolutePath();
      final List<Map<String, Object?>> maps =
          batch.map((LocationModel e) => e.toMap()..remove('id')).toList();
      final Result<int, String> result = await flushLocationRowsInIsolate(
        databasePath: path,
        rows: maps,
      );
      if (result.isSuccess) {
        await SyncBatchService.instance.maybeCreateLocationBatches();
      }
      return result;
    } finally {
      _flushInFlight = false;
    }
  }
}
