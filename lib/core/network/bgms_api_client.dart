import 'package:dio/dio.dart';

class BgmsApiClient {
  BgmsApiClient({
    required String baseUrl,
    Dio? dio,
  })  : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _dio = dio ?? Dio();

  final String _baseUrl;
  final Dio _dio;

  Uri buildPlayerUri({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) {
    return Uri.parse('$_baseUrl/api/pubg/player').replace(
      queryParameters: {
        'nickname': nickname,
        'platform': platform,
        if (season != null && season.isNotEmpty) 'season': season,
        if (refresh) 'refresh': 'true',
      },
    );
  }

  Uri buildMatchesSummaryUri() {
    return Uri.parse('$_baseUrl/api/pubg/matches-summary');
  }

  Uri buildMatchUri({
    required String matchId,
    required String nickname,
    required String platform,
  }) {
    return Uri.parse('$_baseUrl/api/pubg/match').replace(
      queryParameters: {
        'matchId': matchId,
        'nickname': nickname,
        'platform': platform,
      },
    );
  }

  Uri buildAiSummaryUri() {
    return Uri.parse('$_baseUrl/api/pubg/ai-summary');
  }

  Uri buildRankingsUri({
    required String tab,
    String mode = 'all',
    String perspective = 'all',
    String matchType = 'all',
  }) {
    return Uri.parse('$_baseUrl/api/rankings').replace(
      queryParameters: {
        'tab': tab,
        'mode': mode,
        'perspective': perspective,
        'matchType': matchType,
      },
    );
  }

  Uri buildMapMarkersUri({
    required String mapId,
    List<String> layers = const [],
  }) {
    return Uri.parse('$_baseUrl/api/maps/$mapId/markers').replace(
      queryParameters: {
        if (layers.isNotEmpty) 'layers': layers.join(','),
      },
    );
  }

  Future<Map<String, dynamic>> fetchPlayer({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      buildPlayerUri(
        nickname: nickname,
        platform: platform,
        season: season,
        refresh: refresh,
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchMatchesSummary({
    required List<String> matchIds,
    required String nickname,
    required String platform,
  }) async {
    final response = await _dio.postUri<Map<String, dynamic>>(
      buildMatchesSummaryUri(),
      data: {
        'matchIds': matchIds,
        'nickname': nickname,
        'platform': platform,
      },
    );
    return response.data ?? <String, dynamic>{};
  }
}
