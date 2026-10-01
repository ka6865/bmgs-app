enum MapMarkerSource { api, fallback }

class BgmsMap {
  const BgmsMap({required this.id, required this.name, required this.tilePath});

  final String id;
  final String name;

  /// 서버 타일 피라미드 경로. `/tiles/{tilePath}/{z}/{x}/{y}.jpg`로 조합한다.
  final String tilePath;
}

const bgmsMapCatalog = [
  BgmsMap(id: 'Erangel', name: '에란겔', tilePath: 'Erangel'),
  BgmsMap(id: 'Miramar', name: '미라마', tilePath: 'Miramar'),
  BgmsMap(id: 'Taego', name: '태이고', tilePath: 'Taego'),
  BgmsMap(id: 'Rondo', name: '론도', tilePath: 'Rondo'),
  BgmsMap(id: 'Vikendi', name: '비켄디', tilePath: 'Vikendi'),
  BgmsMap(id: 'Deston', name: '데스턴', tilePath: 'Deston'),
];

String normalizeBgmsMapId(String? mapId) {
  final value = (mapId ?? '').trim().toLowerCase();
  return switch (value) {
    'baltic_main' || 'erangel' || '에란겔' => 'erangel',
    'desert_main' || 'miramar' || '미라마' => 'miramar',
    'tiger_main' || 'taego' || '태이고' => 'taego',
    'neon_main' || 'rondo' || '론도' => 'rondo',
    'dihorotok_main' || 'vikendi' || '비켄디' => 'vikendi',
    'kiki_main' || 'deston' || '데스턴' => 'deston',
    _ => value,
  };
}

/// 표시 이름만 변환한다. 알 수 없는 맵은 원래 이름을 보존한다.
String bgmsMapDisplayName(String? mapName) {
  final normalized = normalizeBgmsMapId(mapName);
  for (final map in bgmsMapCatalog) {
    if (map.id.toLowerCase() == normalized) return map.name;
  }
  final original = mapName?.trim() ?? '';
  return switch (normalized) {
    'savage_main' || 'sanhok' || '사녹' => '사녹',
    'summerland_main' || 'karakin' || '카라킨' => '카라킨',
    'chimera_main' || 'paramo' || '파라모' => '파라모',
    'heaven_main' || 'haven' || '헤이븐' => '헤이븐',
    'range_main' || 'range' || 'training' || '훈련장' => '훈련장',
    'pillarcompound_main' || 'pillarcompound' || '필라 기지 (tdm)' => '필라 기지 (TDM)',
    'italy_tdm_main' || 'italy' || '리틀 이탈리아 (tdm)' => '리틀 이탈리아 (TDM)',
    _ => original.isEmpty ? '맵 정보 없음' : original,
  };
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

  static MapMarker? fromJson(Map<String, dynamic> json) {
    final x = _coord(json['x'] ?? json['left']);
    final y = _coord(json['y'] ?? json['top']);
    // 서버가 잘못된 DB 좌표를 중앙/경계로 보정해도 실제 지점처럼 표시하지 않는다.
    for (final field in const ['rawX', 'rawY']) {
      if (json.containsKey(field)) {
        final value = double.tryParse(json[field]?.toString() ?? '');
        if (value == null || !value.isFinite || value < 0 || value > 8192) {
          return null;
        }
      }
    }
    if (x == null || y == null) return null;
    return MapMarker(
      id: json['id']?.toString() ?? json['label']?.toString() ?? 'marker',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '마커',
      layer: json['layer']?.toString() ?? json['type']?.toString() ?? 'default',
      x: x,
      y: y,
      source: MapMarkerSource.api,
    );
  }

  static double? _coord(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 100) {
      return null;
    }
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
    return message;
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
              .whereType<MapMarker>()
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
