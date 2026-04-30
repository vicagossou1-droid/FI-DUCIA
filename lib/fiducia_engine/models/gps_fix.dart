enum GpsIssue {
  none,
  unsupportedPlatform,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  backgroundPermissionRequired,
  timeout,
  lowAccuracy,
  mockLocation,
  unknown,
}

class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isMocked;
}

class PositionFetchResult {
  const PositionFetchResult({
    required this.isTrusted,
    required this.shouldRetry,
    required this.issue,
    this.fix,
    this.technicalMessage,
  });

  final bool isTrusted;
  final bool shouldRetry;
  final GpsIssue issue;
  final GpsFix? fix;
  final String? technicalMessage;
}

enum PermissionState {
  unsupported,
  granted,
  foregroundOnly,
  denied,
  deniedForever,
}

class PermissionSnapshot {
  const PermissionSnapshot({
    required this.servicesEnabled,
    required this.permissionState,
    required this.backgroundGranted,
    required this.preciseAccuracy,
  });

  const PermissionSnapshot.unsupported()
      : servicesEnabled = false,
        permissionState = PermissionState.unsupported,
        backgroundGranted = false,
        preciseAccuracy = false;

  final bool servicesEnabled;
  final PermissionState permissionState;
  final bool backgroundGranted;
  final bool preciseAccuracy;

  bool get isReady => servicesEnabled && backgroundGranted;
}
