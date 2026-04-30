import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/mock_location_exception.dart';
import '../models/client_model.dart';
import '../models/gps_fix.dart';
import 'centroid_compute.dart';
import 'database_service.dart';
import 'location_service.dart';

enum GeofenceStatus {
  learning,
  inside,
  outside,
  invalidFix,
  unsupportedPlatform,
  error,
}

class GeofenceDecision {
  const GeofenceDecision({
    required this.isAllowed,
    required this.status,
    this.gpsIssue,
    this.fix,
    this.scanCount,
    this.distanceMeters,
    this.radiusMeters,
    this.geofenceAlertLocalId,
    this.learningClusterStable,
  });

  final bool isAllowed;
  final GeofenceStatus status;
  final GpsIssue? gpsIssue;
  final GpsFix? fix;
  final int? scanCount;
  final double? distanceMeters;
  final double? radiusMeters;

  /// Local SQLite row id in `geofence_alerts` when [status] is [GeofenceStatus.outside].
  final int? geofenceAlertLocalId;

  /// Après 3 scans : dispersion autour du centroïde ≤ 15 m (carte : vert « validé »).
  final bool? learningClusterStable;
}

class GeofenceService {
  GeofenceService._();

  static final GeofenceService instance = GeofenceService._();

  static const double defaultRadiusMeters = 50;
  static const int learningScanCount = 3;
  static const double _learningStableMaxSpreadMeters = 15;
  static const double _earthRadiusMeters = 6371000;

  Future<GeofenceDecision> validateLocation(String clientId) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return const GeofenceDecision(
        isAllowed: false,
        status: GeofenceStatus.error,
        geofenceAlertLocalId: null,
      );
    }

    await DatabaseService.instance.initialize();

    final PositionFetchResult positionResult;
    try {
      positionResult = await LocationService.instance.getTrustedCurrentPosition(
        requireBackgroundPermission: false,
        context: 'validate:$normalizedClientId',
      );
    } on MockLocationException {
      return const GeofenceDecision(
        isAllowed: false,
        status: GeofenceStatus.invalidFix,
        gpsIssue: GpsIssue.mockLocation,
        geofenceAlertLocalId: null,
      );
    }

    if (!positionResult.isTrusted || positionResult.fix == null) {
      final status = positionResult.issue == GpsIssue.unsupportedPlatform
          ? GeofenceStatus.unsupportedPlatform
          : GeofenceStatus.invalidFix;
      _log(
        'Validation rejected for client=$normalizedClientId '
        'issue=${positionResult.issue.name}',
      );

      return GeofenceDecision(
        isAllowed: false,
        status: status,
        gpsIssue: positionResult.issue,
        fix: positionResult.fix,
        geofenceAlertLocalId: null,
      );
    }

    final fix = positionResult.fix!;

    await DatabaseService.instance.insertClientScan(
      clientId: normalizedClientId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      timestamp: fix.timestamp,
    );

    final scanCount =
        await DatabaseService.instance.getClientScanCount(normalizedClientId);

    if (scanCount <= learningScanCount) {
      if (scanCount == learningScanCount) {
        await _learnClientZone(normalizedClientId);
      }

      bool? learningClusterStable;
      final List<Map<String, Object?>> early =
          await DatabaseService.instance.getEarliestClientScans(
        normalizedClientId,
        limit: scanCount,
      );
      final List<({double lat, double lng})> pts = early
          .map(
            (Map<String, Object?> s) => (
              lat: (s['latitude'] as num).toDouble(),
              lng: (s['longitude'] as num).toDouble(),
            ),
          )
          .toList();
      if (pts.length >= learningScanCount) {
        final ({double lat, double lng})? c = await computeCentroidAsync(pts);
        if (c != null) {
          learningClusterStable =
              maxSpreadMetersApprox(pts, c) <= _learningStableMaxSpreadMeters;
        }
      }

      _log(
        'Learning phase accepted for client=$normalizedClientId '
        '($scanCount/$learningScanCount) stable=$learningClusterStable.',
      );

      return GeofenceDecision(
        isAllowed: true,
        status: GeofenceStatus.learning,
        fix: fix,
        scanCount: scanCount,
        radiusMeters: defaultRadiusMeters,
        geofenceAlertLocalId: null,
        learningClusterStable: learningClusterStable,
      );
    }

    var client = await DatabaseService.instance.getClient(normalizedClientId);
    if (client == null || !client.hasLearnedZone) {
      client = await _learnClientZone(normalizedClientId);
    }

    if (client == null || !client.hasLearnedZone) {
      return GeofenceDecision(
        isAllowed: false,
        status: GeofenceStatus.error,
        fix: fix,
        geofenceAlertLocalId: null,
      );
    }

    final distanceMeters = haversineDistanceMeters(
      lat1: fix.latitude,
      lng1: fix.longitude,
      lat2: client.centerLat!,
      lng2: client.centerLng!,
    );
    final isInside = distanceMeters <= client.radius;

    _log(
      'Geofence decision client=$normalizedClientId '
      'distance=${distanceMeters.toStringAsFixed(2)}m '
      'radius=${client.radius.toStringAsFixed(2)}m '
      'result=${isInside ? 'INSIDE' : 'OUTSIDE'}',
    );

    if (!isInside) {
      final alertId = await DatabaseService.instance.insertGeofenceAlert(
        clientId: normalizedClientId,
        latitude: fix.latitude,
        longitude: fix.longitude,
        gpsTimestamp: fix.timestamp,
        distanceMeters: distanceMeters,
        radiusMeters: client.radius,
      );

      return GeofenceDecision(
        isAllowed: false,
        status: GeofenceStatus.outside,
        fix: fix,
        distanceMeters: distanceMeters,
        radiusMeters: client.radius,
        geofenceAlertLocalId: alertId,
      );
    }

    return GeofenceDecision(
      isAllowed: true,
      status: GeofenceStatus.inside,
      fix: fix,
      distanceMeters: distanceMeters,
      radiusMeters: client.radius,
      geofenceAlertLocalId: null,
    );
  }

  Future<ClientModel?> _learnClientZone(String clientId) async {
    final existingClient = await DatabaseService.instance.getClient(clientId);
    final scans = await DatabaseService.instance.getEarliestClientScans(
      clientId,
      limit: learningScanCount,
    );

    if (scans.length < learningScanCount) {
      return null;
    }

    final List<({double lat, double lng})> pts = scans
        .map(
          (Map<String, Object?> scan) => (
            lat: (scan['latitude'] as num).toDouble(),
            lng: (scan['longitude'] as num).toDouble(),
          ),
        )
        .toList();
    final ({double lat, double lng})? centroid = await computeCentroidAsync(pts);
    if (centroid == null) {
      return null;
    }

    final client = ClientModel(
      id: clientId,
      centerLat: centroid.lat,
      centerLng: centroid.lng,
      radius: existingClient?.radius ?? defaultRadiusMeters,
      storefrontPhotoPath: existingClient?.storefrontPhotoPath,
    );

    await DatabaseService.instance.upsertClient(client);

    _log(
      'Learned client zone client=$clientId '
      'center=(${centroid.lat}, ${centroid.lng}) '
      'radius=${client.radius.toStringAsFixed(0)}m',
    );
    return client;
  }

  double haversineDistanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final deltaLat = _toRadians(lat2 - lat1);
    final deltaLng = _toRadians(lng2 - lng1);

    final a = pow(sin(deltaLat / 2), 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            pow(sin(deltaLng / 2), 2);

    final c = 2 * atan2(sqrt(a.toDouble()), sqrt(1 - a.toDouble()));
    return _earthRadiusMeters * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  static void _log(String message) {
    debugPrint('[FIDUCIA][GEOFENCE] $message');
  }
}
