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

  String get displaySourceLabel => switch (source) {
    MapMarkerSource.api => '마커 연동',
    MapMarkerSource.fallback => '마커 준비 중',
  };

  String get displayMessage {
    if (source == MapMarkerSource.api) {
      return '선택한 맵의 전술 마커를 표시하고 있습니다.';
    }
    if (message.contains('비어')) {
      return '이 맵에는 현재 표시할 마커가 없습니다. 다른 맵이나 레이어를 확인해 주세요.';
    }
    return '마커 데이터를 일시적으로 불러오지 못했습니다. 지도 이미지는 계속 확인할 수 있습니다.';
  }

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
      message: '지도 마커를 불러왔습니다.',
    );
  }

  static MapMarkerLayer unavailable({
    required String mapId,
    String message = '지도 마커를 준비하고 있습니다.',
  }) {
    return MapMarkerLayer(
      mapId: mapId,
      source: MapMarkerSource.fallback,
      message: message,
      markers: const [],
    );
  }
}
