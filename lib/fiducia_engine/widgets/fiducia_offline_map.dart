import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:mbtiles/mbtiles.dart'; 

import '../models/gps_fix.dart';
import '../services/geofence_service.dart' show GeofenceDecision;

// 1. Classe métier (Restauration)
class LearningMapPoint {
  final LatLng position;
  final int scanIndex;
  LearningMapPoint({required this.position, required this.scanIndex});
}

// 2. THEME INJECTÉ (Remplace ProvidedThemes de la v7)
final Map<String, dynamic> _mapStyle = {
  "version": 8,
  "name": "Basic",
  "sources": {
    "openmaptiles": {
      "type": "vector"
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#f8f4f0" // Fond beige clair
      }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "water",
      "paint": {
        "fill-color": "#a0c8f0" // Eau bleue
      }
    },
    {
      "id": "building",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "building",
      "paint": {
        "fill-color": "#d6d6d6" // Bâtiments gris
      }
    },
    {
      "id": "road_minor",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "paint": {
        "line-color": "#ffffff", // Petites routes blanches
        "line-width": 1.5
      }
    },
    {
      "id": "road_major",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "filter": ["in", "class", "primary", "secondary", "trunk", "motorway"],
      "paint": {
        "line-color": "#ffdf8c", // Grandes routes jaunes
        "line-width": 3
      }
    }
  ]
};

class FiduciaOfflineMap extends StatefulWidget {
  const FiduciaOfflineMap({
    super.key,
    required this.height,
    this.center,
    this.zoom = 13.0,
    this.currentFix,
    this.learningMarkers = const <LearningMapPoint>[],
    this.clientCenter,
    this.clientRadiusMeters = 50,
    this.decision,
    this.storefrontPhotoPath,
  });

  final double height;
  final LatLng? center;
  final double zoom;
  final GpsFix? currentFix;
  final List<LearningMapPoint> learningMarkers;
  final LatLng? clientCenter;
  final double clientRadiusMeters;
  final GeofenceDecision? decision;
  final String? storefrontPhotoPath;

  @override
  State<FiduciaOfflineMap> createState() => _FiduciaOfflineMapState();
}

class _FiduciaOfflineMapState extends State<FiduciaOfflineMap> {
  late LatLng _center;
  late final VectorTileProvider _vectorTileProvider;
  bool _providerReady = false;

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  Future<void> _initProvider() async {
    final Directory dir = await getApplicationSupportDirectory();
    final String mbtilesPath = '${dir.path}/lome_offline.mbtiles';
    final File file = File(mbtilesPath);

    if (!await file.exists()) {
      final ByteData bytes = await rootBundle.load('assets/maps/lome_offline.mbtiles');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    final mbTiles = MbTiles(mbtilesPath: mbtilesPath);
    _vectorTileProvider = MbTilesVectorTileProvider(mbtiles: mbTiles);

    if (mounted) {
      setState(() => _providerReady = true);
    }
  }

  LatLng get _effectiveCenter {
    if (widget.center != null) return widget.center!;
    if (widget.currentFix != null) {
      return LatLng(widget.currentFix!.latitude, widget.currentFix!.longitude);
    }
    return const LatLng(6.137, 1.212); // Lomé par défaut
  }

  @override
  Widget build(BuildContext context) {
    _center = _effectiveCenter;
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _providerReady
            ? FlutterMap(
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: widget.zoom,
                  maxZoom: 14.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  // 3. Fond de carte Vectoriel
                  VectorTileLayer(
                    theme: ThemeReader().read(_mapStyle),
                    tileProviders: TileProviders({
                      // APPEL DIRECT AU PROVIDER (l'API v8 gère les erreurs en interne)
                      'openmaptiles': _vectorTileProvider, 
                    }),
                  ),
                  // 4. Couche métier avec tes pastilles et la photo
                  MarkerLayer(
                    markers: <Marker>[
                      ..._learningMarkers(),
                      if (widget.currentFix != null)
                        Marker(
                          width: 40,
                          height: 40,
                          point: LatLng(
                            widget.currentFix!.latitude,
                            widget.currentFix!.longitude,
                          ),
                          child: const Icon(Icons.navigation, color: Colors.blue, size: 36),
                        ),
                      if (widget.storefrontPhotoPath != null)
                        Marker(
                          width: 56,
                          height: 56,
                          point: widget.clientCenter ?? _center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(widget.storefrontPhotoPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                                  const Icon(Icons.store_mall_directory_outlined),
                            ),
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    showFlutterMapAttribution: false,
                    attributions: const [
                      TextSourceAttribution(
                        'Carte hors-ligne',
                        prependCopyright: false,
                      ),
                    ],
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  List<Marker> _learningMarkers() {
    final List<Marker> out = <Marker>[];
    for (final LearningMapPoint p in widget.learningMarkers) {
      final bool green = widget.decision?.learningClusterStable == true;
      final Color color = green ? Colors.green : Colors.orange;
      out.add(
        Marker(
          width: 36,
          height: 36,
          point: p.position,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                '${p.scanIndex}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }
}