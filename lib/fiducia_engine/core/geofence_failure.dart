enum GeofenceFailureCode {
  mockLocation,
  gpsUnavailable,
  gpsLowAccuracy,
  permissionDenied,
  permissionDeniedForever,
  backgroundPermissionRequired,
  unsupportedPlatform,
  unknown,
}

class GeofenceFailure {
  const GeofenceFailure(this.code, {this.message});

  final GeofenceFailureCode code;
  final String? message;
}
