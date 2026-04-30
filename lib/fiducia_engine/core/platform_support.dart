import 'package:flutter/foundation.dart';

class PlatformSupport {
  PlatformSupport._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get supportsGpsModule => isAndroid;
}
