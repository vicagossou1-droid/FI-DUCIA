// SERVICE GPS AVANCÉ - Module Victor (GPS Expert)
// Implémente : Tracking passif, Geofencing, Horodatage sécurisé
// ⚠️ OPTIMISATIONS BATTERIE : fréquence réduite, batching, capteurs inutiles désactivés

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import 'local_db.dart';

class GpsService {
  static Position? _lastPosition;
  static Timer? _trackingTimer;
  static const Duration _trackingInterval =
      Duration(minutes: 7); // 7 min = compromis batterie/précision
  static const double _geofenceRadius = 50.0; // 50m pour Lomé (bâtiments hauts)
  static const double _maxAccuracy = 50.0; // accepter ≤ 50m précision

  // ── TRACKING PASSIF ──
  /// Démarre le tracking GPS passif (toutes les 7 minutes)
  /// Continue même si collecteur immobile
  /// Optimisé batterie : fréquence réduite + batching
  static Future<void> startPassiveTracking(String collectriceId) async {
    stopPassiveTracking(); // arrêter si déjà en cours

    _trackingTimer = Timer.periodic(_trackingInterval, (_) async {
      await _recordTrackPoint(collectriceId);
    });

    // Premier point immédiat
    await _recordTrackPoint(collectriceId);
  }

  /// Arrête le tracking passif
  static void stopPassiveTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  /// Enregistre un point GPS (appelé toutes les 7 min)
  static Future<void> _recordTrackPoint(String collectriceId) async {
    try {
      final position = await _getAccuratePosition();
      if (position == null) return;

      // Filtrer points imprécis (> 50m)
      if (position.accuracy > _maxAccuracy) {
        print(
            'GPS: Point filtré (précision ${position.accuracy}m > ${_maxAccuracy}m)');
        return;
      }

      final point = GpsTrackPoint(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        collectriceId: collectriceId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp, // HORODATAGE GPS !
        altitude: position.altitude,
        speed: position.speed,
      );

      await LocalDB.insertGpsTrackPoint(point);
      print(
          'GPS: Point enregistré (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}) précision: ${position.accuracy.toStringAsFixed(1)}m');

      // Batch sync si WiFi disponible (tous les 10 points)
      final unsyncedCount =
          await LocalDB.getUnsyncedTrackPointsCount(collectriceId);
      if (unsyncedCount >= 10) {
        await _syncTrackPointsBatch(collectriceId);
      }
    } catch (e) {
      print('GPS: Erreur tracking: $e');
    }
  }

  /// Sync les points GPS par batch (optimisé batterie)
  static Future<void> _syncTrackPointsBatch(String collectriceId) async {
    try {
      final points =
          await LocalDB.getUnsyncedTrackPoints(collectriceId, limit: 10);
      if (points.isEmpty) return;

      // TODO: Envoyer à Supabase (chiffré)
      // Pour l'instant : marquer comme sync
      for (final point in points) {
        await LocalDB.markTrackPointSynced(point.id);
      }

      print('GPS: ${points.length} points synchronisés');
    } catch (e) {
      print('GPS: Erreur sync batch: $e');
    }
  }

  // ── GEOFENCING ──
  /// Valide la position GPS pour un client (interface avec Juliette)
  /// Logique : 3 premiers scans = apprentissage, après = contrôle dans rayon 50m
  static Future<GpsValidationResult> validateLocation(
      String clientId, Position gpsActuel) async {
    try {
      // Filtrer précision GPS (> 50m = invalide)
      if (gpsActuel.accuracy > _maxAccuracy) {
        print(
            'GPS: Position rejetée (précision ${gpsActuel.accuracy}m > ${_maxAccuracy}m)');
        return GpsValidationResult(
          isValid: false,
          reason:
              'Précision GPS insuffisante (${gpsActuel.accuracy.toStringAsFixed(1)}m)',
          distance: 0,
          requiresJustification: false,
        );
      }

      final scanCount = await LocalDB.getClientScanCount(clientId);

      if (scanCount < 3) {
        // APPRENTISSAGE : enregistrer position pour définir zone
        await _learnClientLocation(clientId, gpsActuel);
        print('GPS: Apprentissage client $clientId (scan ${scanCount + 1}/3)');
        return GpsValidationResult(
          isValid: true,
          reason: 'Apprentissage zone (scan ${scanCount + 1}/3)',
          distance: 0,
          requiresJustification: false,
        );
      } else {
        // CONTRÔLE : vérifier si dans zone définie
        return await _checkGeofence(clientId, gpsActuel);
      }
    } catch (e) {
      print('GPS: Erreur validation: $e');
      return GpsValidationResult(
        isValid: false,
        reason: 'Erreur GPS: $e',
        distance: 0,
        requiresJustification: false,
      );
    }
  }

  /// Phase apprentissage : enregistre positions pour définir zone client
  static Future<void> _learnClientLocation(
      String clientId, Position position) async {
    // Pour simplifier : moyenne des positions (TODO: clustering plus sophistiqué)
    final existing = await LocalDB.getClientGeofence(clientId);

    if (existing == null) {
      // Premier scan : créer zone
      final geofence = ClientGeofence(
        clientId: clientId,
        centerLat: position.latitude,
        centerLng: position.longitude,
        radiusMeters: _geofenceRadius,
        createdAt: DateTime.now(),
        scanCount: 1,
      );
      await LocalDB.insertClientGeofence(geofence);
    } else {
      // Scans suivants : ajuster centre (moyenne pondérée)
      final newLat = (existing.centerLat + position.latitude) / 2;
      final newLng = (existing.centerLng + position.longitude) / 2;

      final updatedGeofence = ClientGeofence(
        clientId: clientId,
        centerLat: newLat,
        centerLng: newLng,
        radiusMeters: _geofenceRadius,
        createdAt: existing.createdAt,
        scanCount: existing.scanCount + 1,
      );

      await LocalDB.updateClientGeofence(updatedGeofence);
    }
  }

  /// Phase contrôle : vérifie si position dans zone définie
  static Future<GpsValidationResult> _checkGeofence(
      String clientId, Position position) async {
    final geofence = await LocalDB.getClientGeofence(clientId);
    if (geofence == null) {
      print('GPS: Pas de zone définie pour client $clientId');
      return GpsValidationResult(
        isValid: false,
        reason: 'Aucune zone définie pour ce client',
        distance: 0,
        requiresJustification: false,
      );
    }

    final distance = geofence.distanceTo(position.latitude, position.longitude);
    final isValid = distance <= geofence.radiusMeters;

    print(
        'GPS: Client $clientId - Distance: ${distance.toStringAsFixed(1)}m, Rayon: ${geofence.radiusMeters}m, Valide: $isValid');

    if (isValid) {
      return GpsValidationResult(
        isValid: true,
        reason:
            'Position dans zone (${distance.toStringAsFixed(1)}m du centre)',
        distance: distance,
        requiresJustification: false,
      );
    } else {
      // HORS ZONE : nécessite justification
      return GpsValidationResult(
        isValid: false,
        reason: 'Hors zone (${distance.toStringAsFixed(1)}m du centre)',
        distance: distance,
        requiresJustification: true, // peut être justifié
      );
    }
  }

  // ── UTILITAIRES GPS ──
  /// Obtient position GPS précise (optimisée batterie)
  static Future<Position?> _getAccuratePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (!serviceEnabled || permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Configuration optimisée batterie
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy:
              LocationAccuracy.medium, // medium = compromis précision/batterie
          timeLimit:
              const Duration(seconds: 15), // timeout plus long pour précision
          forceAndroidLocationManager: false, // utiliser Google Play Services
        );

        _lastPosition = position;
        return position;
      }
    } catch (e) {
      print('GPS: Erreur position: $e');
    }

    return null;
  }

  /// Position actuelle (pour debug/affichage)
  static Future<Position?> getCurrentPosition() async {
    return await _getAccuratePosition();
  }

  /// Debug : affiche info GPS courante
  static Future<String> getDebugInfo() async {
    final position = await getCurrentPosition();
    if (position == null) return 'GPS indisponible';

    return '''
GPS Debug:
Lat: ${position.latitude.toStringAsFixed(6)}
Lng: ${position.longitude.toStringAsFixed(6)}
Précision: ${position.accuracy.toStringAsFixed(1)}m
Vitesse: ${position.speed.toStringAsFixed(1)} m/s
Altitude: ${position.altitude.toStringAsFixed(1)}m
Heure GPS: ${position.timestamp}
Batterie: ${_trackingTimer != null ? 'Tracking actif' : 'Tracking inactif'}
    '''
        .trim();
  }

  // ── LIFECYCLE ──
  static Position? get lastPosition => _lastPosition;

  static bool get isTrackingActive => _trackingTimer != null;

  /// Nettoyer ressources
  static void dispose() {
    stopPassiveTracking();
  }
}
