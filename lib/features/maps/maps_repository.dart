import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'map_models.dart';

class MapsRepository {
  MapsRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  List<BgmsMap> get availableMaps => const [
    BgmsMap(
      id: 'Erangel',
      name: '에란겔',
      assetPath: 'assets/maps/Erangel_HeightMap.jpg',
      tilePath: 'Erangel',
    ),
    BgmsMap(
      id: 'Miramar',
      name: '미라마',
      assetPath: 'assets/maps/Miramar_HeightMap.jpg',
      tilePath: 'Miramar',
    ),
    BgmsMap(
      id: 'Taego',
      name: '태이고',
      assetPath: 'assets/maps/Taego_HeightMap.jpg',
      tilePath: 'Taego',
    ),
    BgmsMap(
      id: 'Rondo',
      name: '론도',
      assetPath: 'assets/maps/Rondo_HeightMap.jpg',
      tilePath: 'Rondo',
    ),
    BgmsMap(
      id: 'Vikendi',
      name: '비켄디',
      assetPath: 'assets/maps/Vikendi_HeightMap.jpg',
      tilePath: 'Vikendi',
    ),
    BgmsMap(
      id: 'Deston',
      name: '데스턴',
      assetPath: 'assets/maps/Deston_HeightMap.jpg',
      tilePath: 'Deston',
    ),
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
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      return MapMarkerLayer.unavailable(
        mapId: mapId,
        message: status == 404
            ? '/api/maps/$mapId/markers API가 없습니다. 웹/백엔드에 해당 라우트가 필요합니다.'
            : '지도 마커 API 실패: ${_dioMessage(error)}',
      );
    } catch (error) {
      return MapMarkerLayer.unavailable(
        mapId: mapId,
        message: '지도 마커 파싱 실패: $error',
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

  Future<Map<String, List<String>>> fetchMapSettingsFromSupabase() async {
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
    if (settings.isEmpty) {
      return availableLayers;
    }
    final matchedKey = settings.keys.firstWhere(
      (k) => k.toLowerCase() == mapId.toLowerCase(),
      orElse: () => '',
    );
    if (matchedKey.isEmpty) {
      return availableLayers;
    }
    final allowed = settings[matchedKey];
    if (allowed == null) {
      return availableLayers;
    }
    final allowedSet = allowed.map((s) => s.trim().toLowerCase()).toSet();
    return availableLayers.where((l) => allowedSet.contains(l.toLowerCase())).toList();
  }

  String _dioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return [
      if (error.response?.statusCode != null)
        'HTTP ${error.response!.statusCode}',
      if (error.message != null) error.message!,
    ].join(' · ');
  }
}
