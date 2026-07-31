import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'map_models.dart';

class MapsRepository {
  MapsRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  /// 맵별로 노출할 마커 카테고리의 오프라인 폴백값.
  ///
  /// 정본은 서버 `/api/maps/settings`이고 [fetchMapCategorySettings]가 우선 사용한다.
  /// 이 값은 서버 조회가 실패했을 때만 쓰이며, 없으면 마커 API가 준
  /// 모든 레이어가 그대로 노출되어 웹과 화면이 달라진다.
  static const defaultMapCategories = <String, List<String>>{
    'Erangel': [
      'Garage',
      'Esports',
      'EsportsBoat',
      'Glider',
      'SecretRoom',
      'GasPump',
    ],
    'Miramar': [
      'GoldenMirado',
      'EsportsMirado',
      'EsportsPickup',
      'EsportsBoat',
      'Glider',
      'SecretRoom',
    ],
    'Taego': [
      'Garage',
      'Porter',
      'Boat',
      'SecretRoom',
      'Esports',
      'Glider',
      'GasPump',
    ],
    'Deston': ['Garage', 'PoliceCar', 'Boat', 'Glider'],
    'Vikendi': [
      'Garage',
      'Snowmobile',
      'Esports',
      'Boat',
      'SecretRoom',
      'BearCave',
    ],
    'Rondo': ['Garage', 'Esports', 'Glider', 'GasPump', 'SecretRoom'],
  };

  List<BgmsMap> get availableMaps => const [
    BgmsMap(id: 'Erangel', name: '에란겔', tilePath: 'Erangel'),
    BgmsMap(id: 'Miramar', name: '미라마', tilePath: 'Miramar'),
    BgmsMap(id: 'Taego', name: '태이고', tilePath: 'Taego'),
    BgmsMap(id: 'Rondo', name: '론도', tilePath: 'Rondo'),
    BgmsMap(id: 'Vikendi', name: '비켄디', tilePath: 'Vikendi'),
    BgmsMap(id: 'Deston', name: '데스턴', tilePath: 'Deston'),
  ];

  BgmsMap resolveMap(String? mapId) {
    final normalized = _normalizeMapId(mapId);
    return availableMaps.firstWhere(
      (map) => map.id.toLowerCase() == normalized,
      orElse: () => availableMaps.first,
    );
  }

  String _normalizeMapId(String? mapId) {
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

  Future<MapMarkerLayer> fetchMarkers({
    required String mapId,
    required List<String> layers,
  }) async {
    try {
      final json = await _client.fetchMapMarkers(mapId: mapId, layers: layers);
      return MapMarkerLayer.fromJson(json, mapId: mapId);
    } catch (error) {
      final apiError = ApiException.from(error);
      return MapMarkerLayer.unavailable(
        mapId: mapId,
        message: apiError.isMissingEndpoint
            ? '이 맵의 마커 데이터를 준비하고 있습니다.'
            : '지도 마커를 불러오지 못했습니다. ${apiError.message}',
      );
    }
  }

  Future<Map<String, dynamic>> fetchAdminSettings() async {
    try {
      return await _client.fetchAdminSettings();
    } catch (_) {
      return {};
    }
  }

  /// 맵별 마커 카테고리를 가져온다.
  ///
  /// 서버 `/api/maps/settings`가 웹과 동일한 정본을 내려주므로 이를 우선 쓴다.
  /// 실패하면 Supabase 테이블을 시도하고, 그것도 없으면 내장 기본값을 쓴다.
  Future<Map<String, List<String>>> fetchMapCategorySettings() async {
    try {
      final categories = await _client.fetchMapCategories();
      if (categories.isNotEmpty) return categories;
    } catch (_) {
      // 서버 조회 실패는 아래 경로로 넘긴다.
    }

    try {
      final response = await Supabase.instance.client
          .from('map_settings')
          .select('map_id, categories');
      final result = <String, List<String>>{};
      for (final row in response) {
        final mapId = row['map_id'] as String?;
        final cats = row['categories'] as List<dynamic>?;
        if (mapId != null && cats != null) {
          result[mapId] = cats.map((c) => c.toString()).toList();
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  List<String> filterActiveLayers(
    String mapId,
    List<String> availableLayers,
    Map<String, List<String>> settings,
  ) {
    // 서버 설정이 없으면 웹과 동일한 기본 카테고리를 쓴다.
    final effective = settings.isEmpty ? defaultMapCategories : settings;
    final matchedKey = effective.keys.firstWhere(
      (k) => k.toLowerCase() == mapId.toLowerCase(),
      orElse: () => '',
    );
    if (matchedKey.isEmpty) {
      return availableLayers;
    }
    final allowed = effective[matchedKey];
    if (allowed == null) {
      return availableLayers;
    }
    final allowedSet = allowed.map((s) => s.trim().toLowerCase()).toSet();
    return availableLayers
        .where((l) => allowedSet.contains(l.toLowerCase()))
        .toList();
  }
}
