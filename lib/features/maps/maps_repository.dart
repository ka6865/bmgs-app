import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'map_models.dart';

class MapsRepository {
  MapsRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  List<BgmsMap> get availableMaps => bgmsMapCatalog;

  BgmsMap resolveMap(String? mapId) {
    final normalized = normalizeBgmsMapId(mapId);
    return availableMaps.firstWhere(
      (map) => map.id.toLowerCase() == normalized,
      orElse: () => availableMaps.first,
    );
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

  /// 웹 DB에 저장된 설정만 사용한다. 서버 설정 API는 내장값을 섞으므로 사용하지 않는다.
  Future<Map<String, List<String>>> fetchMapCategorySettings() async {
    final response = await Supabase.instance.client
        .from('map_settings')
        .select('map_id, categories');
    final result = <String, List<String>>{};
    for (final row in response) {
      final mapId = row['map_id'] as String?;
      final cats = row['categories'] as List<dynamic>?;
      if (mapId != null && cats != null) {
        result[mapId] = cats.whereType<String>().map((c) => c.trim()).toList();
      }
    }
    return result;
  }

  List<String> filterActiveLayers(
    String mapId,
    List<String> availableLayers,
    Map<String, List<String>> settings,
  ) {
    final matchedKey = settings.keys.firstWhere(
      (k) => k.toLowerCase() == mapId.toLowerCase(),
      orElse: () => '',
    );
    if (matchedKey.isEmpty) {
      return const [];
    }
    final allowed = settings[matchedKey];
    if (allowed == null) {
      return const [];
    }
    final allowedSet = allowed.map((s) => s.trim().toLowerCase()).toSet();
    return availableLayers
        .where((l) => allowedSet.contains(l.toLowerCase()))
        .toList();
  }
}
