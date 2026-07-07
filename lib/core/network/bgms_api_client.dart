import 'package:dio/dio.dart';

class BgmsApiClient {
  BgmsApiClient({required String baseUrl, Dio? dio})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 10),
            ),
          );

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
      queryParameters: {if (layers.isNotEmpty) 'layers': layers.join(',')},
    );
  }

  Uri buildAdminSettingsUri() {
    return Uri.parse('$_baseUrl/api/admin/settings');
  }

  Uri buildBoardPostsUri({
    int limit = 20,
    String? cursor,
    String category = 'all',
    String? query,
  }) {
    return Uri.parse('$_baseUrl/api/mobile/board/posts').replace(
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (category != 'all') 'category': category,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
  }

  Uri buildBoardPostUri(int postId) {
    return Uri.parse('$_baseUrl/api/mobile/board/posts/$postId');
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
      data: {'matchIds': matchIds, 'nickname': nickname, 'platform': platform},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchMatchDetail({
    required String matchId,
    required String nickname,
    required String platform,
  }) async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      buildMatchUri(matchId: matchId, nickname: nickname, platform: platform),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<String> fetchAiSummary({
    required List<String> matchIds,
    required String nickname,
    required String platform,
    String? accessToken,
  }) async {
    final response = await _dio.postUri<String>(
      buildAiSummaryUri(),
      data: {
        'matchIds': matchIds,
        'nickname': nickname,
        'platform': platform,
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        },
      ),
    );
    return response.data ?? '';
  }

  Future<Map<String, dynamic>> fetchRankings({
    required String tab,
    String mode = 'all',
    String perspective = 'all',
    String matchType = 'all',
  }) async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      buildRankingsUri(
        tab: tab,
        mode: mode,
        perspective: perspective,
        matchType: matchType,
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchMapMarkers({
    required String mapId,
    List<String> layers = const [],
  }) async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      buildMapMarkersUri(mapId: mapId, layers: layers),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchAdminSettings() async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      buildAdminSettingsUri(),
    );
    final data = response.data;
    if (data != null && data['success'] == true) {
      return Map<String, dynamic>.from(data['settings'] ?? {});
    }
    return {};
  }

  Future<Map<String, dynamic>> fetchBoardPosts({
    int limit = 20,
    String? cursor,
    String category = 'all',
    String? query,
  }) async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      buildBoardPostsUri(
        limit: limit,
        cursor: cursor,
        category: category,
        query: query,
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchBoardPost({required int postId}) async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      buildBoardPostUri(postId),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createBoardPost({
    required String title,
    required String content,
    required String category,
    required String accessToken,
  }) async {
    final response = await _dio.postUri<Map<String, dynamic>>(
      buildBoardPostsUri(),
      data: {'title': title, 'content': content, 'category': category},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createBoardComment({
    required int postId,
    required String content,
    required String accessToken,
  }) async {
    final response = await _dio.postUri<Map<String, dynamic>>(
      buildBoardPostUri(
        postId,
      ).replace(path: '${buildBoardPostUri(postId).path}/comments'),
      data: {'content': content},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return response.data ?? <String, dynamic>{};
  }
}
