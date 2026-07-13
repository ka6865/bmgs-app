enum MapMarkerSource { api, fallback }

class BgmsMap {
  const BgmsMap({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.tilePath,
  });

  final String id;
  final String name;
  final String assetPath;
  final String tilePath;
}

class MapMarker {
  const MapMarker({
    required this.id,
    required this.label,
    required this.layer,
    required this.x,
    required this.y,
    required this.source,
  });

  final String id;
  final String label;
  final String layer;
  final double x;
  final double y;
  final MapMarkerSource source;

  static MapMarker fromJson(Map<String, dynamic> json) {
    return MapMarker(
      id: json['id']?.toString() ?? json['label']?.toString() ?? 'marker',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '마커',
      layer: json['layer']?.toString() ?? json['type']?.toString() ?? 'default',
      x: _coord(json['x'] ?? json['left']),
      y: _coord(json['y'] ?? json['top']),
      source: MapMarkerSource.api,
    );
  }

  static double _coord(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0.5;
    final normalized = parsed > 1 && parsed <= 100 ? parsed / 100 : parsed;
    return normalized.clamp(0, 1).toDouble();
  }
}

class MapMarkerLayer {
  const MapMarkerLayer({
    required this.mapId,
    required this.markers,
    required this.source,
    required this.message,
  });

  final String mapId;
  final List<MapMarker> markers;
  final MapMarkerSource source;
  final String message;

  static MapMarkerLayer fromJson(
    Map<String, dynamic> json, {
    required String mapId,
  }) {
    final rawMarkers = json['markers'] ?? json['data'];
    final markers = rawMarkers is List
        ? rawMarkers
              .whereType<Map>()
              .map(
                (item) => MapMarker.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <MapMarker>[];

    if (markers.isEmpty) {
      return unavailable(mapId: mapId, message: '지도 마커 API 응답이 비어 있습니다.');
    }

    return MapMarkerLayer(
      mapId: mapId,
      markers: markers,
      source: MapMarkerSource.api,
      message: '실제 지도 마커 API 응답입니다.',
    );
  }

  static MapMarkerLayer unavailable({
    required String mapId,
    String message = '/api/maps/{mapId}/markers 모바일 계약 준비 중입니다.',
  }) {
    return MapMarkerLayer(
      mapId: mapId,
      source: MapMarkerSource.fallback,
      message: message,
      markers: const [],
    );
  }
}
