class ClientModel {
  const ClientModel({
    required this.id,
    this.centerLat,
    this.centerLng,
    this.radius = 50,
    this.storefrontPhotoPath,
  });

  final String id;
  final double? centerLat;
  final double? centerLng;
  final double radius;

  /// Chemin local (fichier) vers une photo de devanture pour marqueurs carte.
  final String? storefrontPhotoPath;

  bool get hasLearnedZone => centerLat != null && centerLng != null;

  ClientModel copyWith({
    String? id,
    double? centerLat,
    double? centerLng,
    double? radius,
    String? storefrontPhotoPath,
  }) {
    return ClientModel(
      id: id ?? this.id,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radius: radius ?? this.radius,
      storefrontPhotoPath: storefrontPhotoPath ?? this.storefrontPhotoPath,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'centerLat': centerLat,
      'centerLng': centerLng,
      'radius': radius,
      'photo_path': storefrontPhotoPath,
    };
  }

  factory ClientModel.fromMap(Map<String, Object?> map) {
    return ClientModel(
      id: map['id'] as String,
      centerLat: (map['centerLat'] as num?)?.toDouble(),
      centerLng: (map['centerLng'] as num?)?.toDouble(),
      radius: ((map['radius'] as num?) ?? 50).toDouble(),
      storefrontPhotoPath: map['photo_path'] as String?,
    );
  }
}
