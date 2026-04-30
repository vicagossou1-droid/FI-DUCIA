import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';

import '../core/fiducia_prefs.dart';
import '../core/platform_support.dart';

/// Battery-aware gate based on official Google Activity Recognition states.
class ActivityStationaryGate {
  ActivityStationaryGate._();

  static final ActivityStationaryGate instance = ActivityStationaryGate._();

  StreamSubscription<Activity>? _sub;
  bool _suspended = false;
  bool _permissionReady = false;

  Future<void> start() async {
    if (!PlatformSupport.isAndroid) {
      return;
    }
    _suspended = await FiduciaPrefs.isPassiveGpsSuspended();
    _permissionReady = await _ensurePermission();
    await _sub?.cancel();
    if (!_permissionReady) {
      _log('Activity recognition permission unavailable.');
      return;
    }

    _sub = FlutterActivityRecognition.instance.activityStream.listen(
      _onActivity,
      onError: (Object e, StackTrace st) {
        _log('Activity stream error: $e');
      },
    );
  }

  Future<bool> canCaptureNow() async {
    if (!PlatformSupport.isAndroid) {
      return false;
    }
    if (!_permissionReady) {
      _permissionReady = await _ensurePermission();
    }
    final bool persisted = await FiduciaPrefs.isPassiveGpsSuspended();
    _suspended = persisted;
    return !_suspended;
  }

  Future<void> notifySignificantGpsMovement() async {
    if (_suspended) {
      _suspended = false;
      await FiduciaPrefs.setPassiveGpsSuspended(false);
      _log('Passive GPS resumed by significant GPS movement.');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _onActivity(Activity activity) {
    final ActivityType type = activity.type;
    final bool nextSuspended = type == ActivityType.STILL;
    if (nextSuspended != _suspended) {
      _suspended = nextSuspended;
      unawaited(FiduciaPrefs.setPassiveGpsSuspended(_suspended));
      _log('Activity=$type => passive GPS ${_suspended ? 'SUSPENDED' : 'RESUMED'}');
    }
  }

  Future<bool> _ensurePermission() async {
    final ActivityPermission permission =
        await FlutterActivityRecognition.instance.checkPermission();
    if (permission == ActivityPermission.GRANTED) {
      return true;
    }
    final ActivityPermission requested =
        await FlutterActivityRecognition.instance.requestPermission();
    return requested == ActivityPermission.GRANTED;
  }

  void _log(String message) {
    debugPrint('[FIDUCIA][ACTIVITY] $message');
  }
}
