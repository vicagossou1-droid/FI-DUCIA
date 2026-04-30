import '../models/client_model.dart';
import '../models/location_model.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String locationsTableName = 'locations';
  static const String clientsTableName = 'clients';
  static const String clientScansTableName = 'client_scans';
  static const String geofenceAlertsTableName = 'geofence_alerts';
  static const String syncBatchesTableName = 'sync_batches';

  Future<dynamic> get connection async {
    throw UnsupportedError('DatabaseService.connection is Android-only.');
  }

  Future<void> initialize() async {}

  Future<String> getDatabaseFilePath() async {
    throw UnsupportedError('getDatabaseFilePath is Android-only.');
  }

  Future<int> insertLocation(LocationModel location) async {
    _locations.add(location);
    return _locations.length;
  }

  Future<void> ensureClientExists(String clientId) async {
    _clients.putIfAbsent(clientId, () => ClientModel(id: clientId, radius: 50));
  }

  Future<int> insertClientScan({
    required String clientId,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    await ensureClientExists(clientId);
    _clientScans.add(
      <String, Object?>{
        'id': _clientScans.length + 1,
        'clientId': clientId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.millisecondsSinceEpoch,
      },
    );
    return _clientScans.length;
  }

  Future<int> getClientScanCount(String clientId) async {
    return _clientScans.where((scan) => scan['clientId'] == clientId).length;
  }

  Future<List<Map<String, Object?>>> getEarliestClientScans(
    String clientId, {
    int limit = 3,
  }) async {
    final scans = _clientScans
        .where((scan) => scan['clientId'] == clientId)
        .toList()
      ..sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
      );

    return scans.take(limit).toList();
  }

  Future<ClientModel?> getClient(String clientId) async {
    return _clients[clientId];
  }

  Future<void> upsertClient(ClientModel client) async {
    _clients[client.id] = client;
  }

  Future<LocationModel?> getLatestLocation() async {
    if (_locations.isEmpty) {
      return null;
    }

    return _locations.last;
  }

  Future<int> insertGeofenceAlert({
    required String clientId,
    required double latitude,
    required double longitude,
    required DateTime gpsTimestamp,
    double? distanceMeters,
    double? radiusMeters,
  }) async {
    return 0;
  }

  Future<void> updateGeofenceAlertJustification({
    required int alertLocalId,
    required String justification,
  }) async {}

  Future<int> countPendingUploadBatches() async => 0;

  final List<LocationModel> _locations = <LocationModel>[];
  final Map<String, ClientModel> _clients = <String, ClientModel>{};
  final List<Map<String, Object?>> _clientScans = <Map<String, Object?>>[];
}
