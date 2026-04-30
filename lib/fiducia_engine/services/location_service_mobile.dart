import 'dart:async';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_env.dart';
import '../core/mock_location_exception.dart';
import '../core/platform_support.dart';
import '../models/gps_fix.dart';
import '../models/location_model.dart';
import 'activity_stationary_gate.dart';
import 'database_service.dart';
import 'location_batch_buffer.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Android alarm id (must stay stable across versions).
  static const int passiveAlarmId = 940011001;

  static const String backgroundTaskName = 'fiduciaPassiveLocationTask';

  /// Passive capture cadence (Android WorkManager minimum is 15 min; we use
  /// [AndroidAlarmManager.periodic] to target ~10 minutes).
  static const Duration backgroundTaskFrequency = Duration(minutes: 10);

  static const Duration _locationTimeout = Duration(seconds: 30);

  /// Au-delà de cette précision (m), le point est rejeté (log silencieux).
  static const double accuracyRejectMeters = 65;

  GpsFix? _lastTrustedForMotion;

  Future<void> initializeBackgroundTracking() async {
    if (!PlatformSupport.isAndroid) {
      _log('Background tracking skipped outside Android.');
      return;
    }

    await ActivityStationaryGate.instance.start();

    await AndroidAlarmManager.cancel(passiveAlarmId);

    final scheduled = await AndroidAlarmManager.periodic(
      backgroundTaskFrequency,
      passiveAlarmId,
      fiduciaPassiveLocationAlarmCallback,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    _log(
      'Passive tracking alarm scheduled every '
      '${backgroundTaskFrequency.inMinutes} minutes '
      '(started=$scheduled).',
    );
  }

  Future<bool> executeBackgroundTask(String task) async {
    if (!PlatformSupport.isAndroid) {
      return false;
    }

    if (task != backgroundTaskName) {
      return true;
    }

    if (!await ActivityStationaryGate.instance.canCaptureNow()) {
      return true;
    }

    try {
      final PositionFetchResult result = await getTrustedCurrentPosition(
        requireBackgroundPermission: true,
        requestIfNeeded: false,
        context: 'background_task',
      );

      if (!result.isTrusted || result.fix == null) {
        if (result.issue != GpsIssue.lowAccuracy) {
          _log('Background capture skipped: ${result.issue.name}');
        }
        return !result.shouldRetry;
      }

      await DatabaseService.instance.insertLocation(
        LocationModel.fromGpsFix(result.fix!),
      );
      await LocationBatchBuffer.instance.flush();

      _log(
        'Background GPS saved lat=${result.fix!.latitude}, '
        'lng=${result.fix!.longitude}, '
        'accuracy=${result.fix!.accuracy.toStringAsFixed(1)}m, '
        'gpsTs=${result.fix!.timestamp.toIso8601String()}',
      );
      return true;
    } on MockLocationException catch (e) {
      _log('Background blocked: $e');
      return true;
    }
  }

  Future<bool> capturePassiveLocation() async {
    return executeBackgroundTask(backgroundTaskName);
  }

  Future<PermissionSnapshot> getPermissionSnapshot() async {
    return _resolvePermissionSnapshot(
      requestIfNeeded: false,
      requireBackgroundPermission: true,
    );
  }

  Future<PermissionSnapshot> requestRequiredPermissions() async {
    return _resolvePermissionSnapshot(
      requestIfNeeded: true,
      requireBackgroundPermission: true,
    );
  }

  Future<PositionFetchResult> getTrustedCurrentPosition({
    required bool requireBackgroundPermission,
    required String context,
    bool requestIfNeeded = true,
  }) async {
    if (!PlatformSupport.isAndroid) {
      return const PositionFetchResult(
        isTrusted: false,
        shouldRetry: false,
        issue: GpsIssue.unsupportedPlatform,
      );
    }

    final snapshot = await _resolvePermissionSnapshot(
      requestIfNeeded: requestIfNeeded,
      requireBackgroundPermission: requireBackgroundPermission,
    );

    if (!snapshot.servicesEnabled) {
      return const PositionFetchResult(
        isTrusted: false,
        shouldRetry: false,
        issue: GpsIssue.servicesDisabled,
      );
    }

    switch (snapshot.permissionState) {
      case PermissionState.denied:
        return const PositionFetchResult(
          isTrusted: false,
          shouldRetry: false,
          issue: GpsIssue.permissionDenied,
        );
      case PermissionState.deniedForever:
        return const PositionFetchResult(
          isTrusted: false,
          shouldRetry: false,
          issue: GpsIssue.permissionDeniedForever,
        );
      case PermissionState.foregroundOnly:
        if (requireBackgroundPermission) {
          return const PositionFetchResult(
            isTrusted: false,
            shouldRetry: false,
            issue: GpsIssue.backgroundPermissionRequired,
          );
        }
        break;
      case PermissionState.unsupported:
        return const PositionFetchResult(
          isTrusted: false,
          shouldRetry: false,
          issue: GpsIssue.unsupportedPlatform,
        );
      case PermissionState.granted:
        break;
    }

    if (requireBackgroundPermission && !snapshot.backgroundGranted) {
      return const PositionFetchResult(
        isTrusted: false,
        shouldRetry: false,
        issue: GpsIssue.backgroundPermissionRequired,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _locationTimeout,
        ),
      );

      final fix = GpsFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp.toUtc(),
        isMocked: position.isMocked,
      );

      if (fix.isMocked) {
        throw const MockLocationException();
      }

      if (fix.accuracy > accuracyRejectMeters) {
        return PositionFetchResult(
          isTrusted: false,
          shouldRetry: false,
          issue: GpsIssue.lowAccuracy,
          fix: fix,
        );
      }

      _log(
        'GPS[$context] lat=${fix.latitude}, '
        'lng=${fix.longitude}, '
        'accuracy=${fix.accuracy.toStringAsFixed(1)}m, '
        'gpsTs=${fix.timestamp.toIso8601String()}, '
        'mocked=${fix.isMocked}',
      );

      _noteMovementIfNeeded(fix);

      return PositionFetchResult(
        isTrusted: true,
        shouldRetry: false,
        issue: GpsIssue.none,
        fix: fix,
      );
    } on MockLocationException catch (e) {
      _log('Mock location rejected for $context: $e');
      rethrow;
    } on TimeoutException {
      return const PositionFetchResult(
        isTrusted: false,
        shouldRetry: true,
        issue: GpsIssue.timeout,
      );
    } on LocationServiceDisabledException {
      return const PositionFetchResult(
        isTrusted: false,
        shouldRetry: false,
        issue: GpsIssue.servicesDisabled,
      );
    } catch (error) {
      _log('GPS capture failed: $error');
      return PositionFetchResult(
        isTrusted: false,
        shouldRetry: true,
        issue: GpsIssue.unknown,
        technicalMessage: error.toString(),
      );
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<PermissionSnapshot> _resolvePermissionSnapshot({
    required bool requestIfNeeded,
    required bool requireBackgroundPermission,
  }) async {
    if (!PlatformSupport.isAndroid) {
      return const PermissionSnapshot.unsupported();
    }

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied && requestIfNeeded) {
      permission = await Geolocator.requestPermission();
    }

    if (requireBackgroundPermission &&
        permission != LocationPermission.always &&
        requestIfNeeded) {
      permission = await Geolocator.requestPermission();
    }

    final preciseAccuracy = await _isPreciseAccuracyEnabled(permission);
    final permissionState = _mapPermission(permission);

    return PermissionSnapshot(
      servicesEnabled: servicesEnabled,
      permissionState: permissionState,
      backgroundGranted: permission == LocationPermission.always,
      preciseAccuracy: preciseAccuracy,
    );
  }

  Future<bool> _isPreciseAccuracyEnabled(LocationPermission permission) async {
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    try {
      final accuracyStatus = await Geolocator.getLocationAccuracy();
      return accuracyStatus == LocationAccuracyStatus.precise;
    } catch (_) {
      return false;
    }
  }

  void _noteMovementIfNeeded(GpsFix fix) {
    final GpsFix? last = _lastTrustedForMotion;
    _lastTrustedForMotion = fix;
    if (last == null) {
      return;
    }
    final double d = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      fix.latitude,
      fix.longitude,
    );
    if (d > 12) {
      unawaited(ActivityStationaryGate.instance.notifySignificantGpsMovement());
    }
  }

  PermissionState _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return PermissionState.granted;
      case LocationPermission.whileInUse:
        return PermissionState.foregroundOnly;
      case LocationPermission.denied:
        return PermissionState.denied;
      case LocationPermission.deniedForever:
        return PermissionState.deniedForever;
      case LocationPermission.unableToDetermine:
        return PermissionState.denied;
    }
  }

  static void _log(String message) {
    debugPrint('[FIDUCIA][GPS] $message');
  }
}

/// Isolate / alarm entry-point: must be a top-level function.
@pragma('vm:entry-point')
Future<void> fiduciaPassiveLocationAlarmCallback(int alarmId) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await AppEnv.load();
    await DatabaseService.instance.initialize();
    await LocationService.instance.executeBackgroundTask(
      LocationService.backgroundTaskName,
    );
  } catch (error, stack) {
    debugPrint('[FIDUCIA][ALARM] Passive callback error: $error\n$stack');
  }
}
