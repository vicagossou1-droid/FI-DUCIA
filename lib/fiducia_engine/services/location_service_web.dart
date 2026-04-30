import '../models/gps_fix.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  static const Duration backgroundTaskFrequency = Duration(minutes: 10);

  Future<void> initializeBackgroundTracking() async {}

  Future<bool> executeBackgroundTask(String task) async => false;

  Future<bool> capturePassiveLocation() async => false;

  Future<PermissionSnapshot> getPermissionSnapshot() async {
    return const PermissionSnapshot.unsupported();
  }

  Future<PermissionSnapshot> requestRequiredPermissions() async {
    return const PermissionSnapshot.unsupported();
  }

  Future<PositionFetchResult> getTrustedCurrentPosition({
    required bool requireBackgroundPermission,
    required String context,
    bool requestIfNeeded = true,
  }) async {
    return const PositionFetchResult(
      isTrusted: false,
      shouldRetry: false,
      issue: GpsIssue.unsupportedPlatform,
    );
  }

  Future<bool> openAppSettings() async => false;

  Future<bool> openLocationSettings() async => false;
}
