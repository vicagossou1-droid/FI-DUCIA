import 'dart:isolate';
import 'dart:math' as math;

/// Calcul pur du centroïde (moyenne lat / lng) — exécuté hors isolate UI.
Future<({double lat, double lng})?> computeCentroidAsync(
  List<({double lat, double lng})> points,
) {
  if (points.isEmpty) {
    return Future<({double lat, double lng})?>.value(null);
  }
  return Isolate.run(() {
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final p in points) {
      sumLat += p.lat;
      sumLng += p.lng;
    }
    final n = points.length;
    return (lat: sumLat / n, lng: sumLng / n);
  });
}

/// Écart max (mètres, approximation plate) entre points et leur centroïde.
double maxSpreadMetersApprox(
  List<({double lat, double lng})> points,
  ({double lat, double lng}) center,
) {
  if (points.isEmpty) {
    return 0;
  }
  double maxM = 0;
  for (final p in points) {
    final d = _planarMeters(p, center);
    if (d > maxM) {
      maxM = d;
    }
  }
  return maxM;
}

double _planarMeters(
  ({double lat, double lng}) p,
  ({double lat, double lng}) c,
) {
  const mPerDegLat = 111320.0;
  final latRad = p.lat * math.pi / 180;
  final mPerDegLng = mPerDegLat * math.cos(latRad).abs().clamp(0.01, 1.0);
  final dx = (p.lng - c.lng) * mPerDegLng;
  final dy = (p.lat - c.lat) * mPerDegLat;
  return math.sqrt(dx * dx + dy * dy);
}
