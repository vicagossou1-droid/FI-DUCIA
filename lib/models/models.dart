import 'dart:math';

class Client {
  final String id;
  final String nom;
  final String telephone;
  final String zone;
  final bool actif;
  int scanCount; // nb de scans du jour

  Client({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.zone,
    required this.actif,
    this.scanCount = 0,
  });

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'] ?? '',
        nom: m['nom'] ?? '',
        telephone: m['telephone'] ?? '',
        zone: m['zone'] ?? '',
        actif: m['actif'] ?? true,
      );
}

/// Point GPS passif (tracking toutes les 5-10 min)
class GpsTrackPoint {
  final String id;
  final String collectriceId;
  final double latitude;
  final double longitude;
  final double accuracy; // précision en mètres
  final DateTime timestamp; // heure GPS, pas téléphone
  final double? altitude;
  final double? speed;
  bool synced;

  GpsTrackPoint({
    required this.id,
    required this.collectriceId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
    this.speed,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'collectriceId': collectriceId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
        'altitude': altitude,
        'speed': speed,
        'synced': synced ? 1 : 0,
      };

  factory GpsTrackPoint.fromMap(Map<String, dynamic> m) => GpsTrackPoint(
        id: m['id'],
        collectriceId: m['collectriceId'],
        latitude: m['latitude'],
        longitude: m['longitude'],
        accuracy: m['accuracy'],
        timestamp: DateTime.parse(m['timestamp']),
        altitude: m['altitude'],
        speed: m['speed'],
        synced: m['synced'] == 1,
      );
}

/// Zone géographique d'un client (après 3 scans)
class ClientGeofence {
  final String clientId;
  final double centerLat;
  final double centerLng;
  final double radiusMeters; // 50m par défaut
  final DateTime createdAt;
  final int scanCount; // nombre de scans utilisés pour définir la zone

  ClientGeofence({
    required this.clientId,
    required this.centerLat,
    required this.centerLng,
    this.radiusMeters = 50.0,
    required this.createdAt,
    required this.scanCount,
  });

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'centerLat': centerLat,
        'centerLng': centerLng,
        'radiusMeters': radiusMeters,
        'createdAt': createdAt.toIso8601String(),
        'scanCount': scanCount,
      };

  factory ClientGeofence.fromMap(Map<String, dynamic> m) => ClientGeofence(
        clientId: m['clientId'],
        centerLat: m['centerLat'],
        centerLng: m['centerLng'],
        radiusMeters: m['radiusMeters'] ?? 50.0,
        createdAt: DateTime.parse(m['createdAt']),
        scanCount: m['scanCount'] ?? 3,
      );

  /// Calcule la distance entre ce point et le centre de la zone
  double distanceTo(double lat, double lng) {
    const double earthRadius = 6371000; // mètres

    final double dLat = (lat - centerLat) * (pi / 180);
    final double dLng = (lng - centerLng) * (pi / 180);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(centerLat) * cos(lat) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Vérifie si un point GPS est dans la zone
  bool containsPoint(double lat, double lng) {
    return distanceTo(lat, lng) <= radiusMeters;
  }
}

class ScanRecord {
  final String id;
  final String clientId;
  final String collectriceId;
  final double montant;
  final String? photoPath; // chemin local
  final String? photoUrl; // URL Supabase après upload
  final double? latitude;
  final double? longitude;
  final bool gpsValide;
  final DateTime scannedAt;
  bool synced;

  ScanRecord({
    required this.id,
    required this.clientId,
    required this.collectriceId,
    required this.montant,
    this.photoPath,
    this.photoUrl,
    this.latitude,
    this.longitude,
    required this.gpsValide,
    required this.scannedAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'client_id': clientId,
        'collectrice_id': collectriceId,
        'montant': montant,
        'photo_path': photoPath,
        'photo_url': photoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'gps_valide': gpsValide ? 1 : 0,
        'scanned_at': scannedAt.toIso8601String(),
        'synced': synced ? 1 : 0,
      };

  factory ScanRecord.fromMap(Map<String, dynamic> m) => ScanRecord(
        id: m['id'],
        clientId: m['client_id'],
        collectriceId: m['collectrice_id'],
        montant: (m['montant'] as num).toDouble(),
        photoPath: m['photo_path'],
        photoUrl: m['photo_url'],
        latitude: m['latitude'],
        longitude: m['longitude'],
        gpsValide: m['gps_valide'] == 1,
        scannedAt: DateTime.parse(m['scanned_at']),
        synced: m['synced'] == 1,
      );
}

/// Résultat de validation GPS (remplace le bool simple)
class GpsValidationResult {
  final bool isValid;
  final String reason;
  final double distance; // distance du centre de la zone (0 si apprentissage)
  final bool requiresJustification; // true si hors zone mais peut être justifié

  GpsValidationResult({
    required this.isValid,
    required this.reason,
    required this.distance,
    required this.requiresJustification,
  });
}
