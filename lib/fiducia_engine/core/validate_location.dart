import 'either.dart';
import 'geofence_failure.dart';
import '../services/database_service.dart';
import '../services/geofence_service.dart';
import '../models/gps_fix.dart';

Future<Either<GeofenceFailure, bool>> validateLocation(String clientId) async {
  final decision = await GeofenceService.instance.validateLocation(clientId);
  if (decision.status == GeofenceStatus.error) {
    return const Left<GeofenceFailure, bool>(
      GeofenceFailure(
        GeofenceFailureCode.unknown,
        message: 'Geofence decision error',
      ),
    );
  }

  if (decision.status == GeofenceStatus.unsupportedPlatform) {
    return const Left<GeofenceFailure, bool>(
      GeofenceFailure(
        GeofenceFailureCode.unsupportedPlatform,
      ),
    );
  }

  if (decision.status == GeofenceStatus.invalidFix) {
    return Left<GeofenceFailure, bool>(
      _mapGpsIssueToFailure(decision.gpsIssue),
    );
  }

  return Right<GeofenceFailure, bool>(decision.isAllowed);
}

Future<GeofenceDecision> validateLocationDetailed(String clientId) {
  return GeofenceService.instance.validateLocation(clientId);
}

GeofenceFailure _mapGpsIssueToFailure(GpsIssue? issue) {
  switch (issue) {
    case GpsIssue.mockLocation:
      return const GeofenceFailure(GeofenceFailureCode.mockLocation);
    case GpsIssue.servicesDisabled:
      return const GeofenceFailure(GeofenceFailureCode.gpsUnavailable);
    case GpsIssue.lowAccuracy:
      return const GeofenceFailure(GeofenceFailureCode.gpsLowAccuracy);
    case GpsIssue.permissionDenied:
      return const GeofenceFailure(GeofenceFailureCode.permissionDenied);
    case GpsIssue.permissionDeniedForever:
      return const GeofenceFailure(GeofenceFailureCode.permissionDeniedForever);
    case GpsIssue.backgroundPermissionRequired:
      return const GeofenceFailure(
        GeofenceFailureCode.backgroundPermissionRequired,
      );
    case GpsIssue.unsupportedPlatform:
      return const GeofenceFailure(GeofenceFailureCode.unsupportedPlatform);
    case GpsIssue.timeout:
    case GpsIssue.unknown:
    case GpsIssue.none:
    case null:
      return const GeofenceFailure(GeofenceFailureCode.unknown);
  }
}

/// Collecteur hors zone : texte d’audit local (alerte admin côté serveur plus tard).
Future<void> submitOutsideZoneJustification({
  required int alertLocalId,
  required String justification,
}) async {
  final text = justification.trim();
  if (text.isEmpty) {
    return;
  }

  await DatabaseService.instance.initialize();
  await DatabaseService.instance.updateGeofenceAlertJustification(
    alertLocalId: alertLocalId,
    justification: text,
  );
}
