import 'gps_fix.dart';

class LocationModel {
  const LocationModel({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  final int? id;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  factory LocationModel.fromGpsFix(GpsFix fix) {
    return LocationModel(
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracy: fix.accuracy,
      timestamp: fix.timestamp,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory LocationModel.fromMap(Map<String, Object?> map) {
    return LocationModel(
      id: map['id'] as int?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
        isUtc: true,
      ),
    );
  }
}
