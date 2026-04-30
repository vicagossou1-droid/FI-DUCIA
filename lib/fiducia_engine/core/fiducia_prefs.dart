import 'package:shared_preferences/shared_preferences.dart';

/// Persistance légère (préférences utilisateur / premier lancement).
class FiduciaPrefs {
  FiduciaPrefs._();

  static const String _kLocationIntroV1 = 'fiducia.location_intro_v1';

  static Future<bool> wasLocationIntroCompleted() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getBool(_kLocationIntroV1) ?? false;
  }

  static Future<void> setLocationIntroCompleted() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kLocationIntroV1, true);
  }

  static const String _kSuspendPassiveGps = 'fiducia.suspend_passive_gps';

  static Future<bool> isPassiveGpsSuspended() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getBool(_kSuspendPassiveGps) ?? false;
  }

  static Future<void> setPassiveGpsSuspended(bool value) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kSuspendPassiveGps, value);
  }
}
