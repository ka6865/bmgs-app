import 'package:dio/dio.dart';

import 'api_exception.dart';

/// 인증이 필요한 API 호출에 붙일 Bearer 토큰을 제공한다.
///
/// Supabase 세션이 없으면 null을 반환해야 한다.
typedef AuthTokenProvider = Future<String?> Function();

/// BGMS 서버 API 클라이언트.
///
/// 모든 실패는 [ApiException]으로 정규화해서 던진다. 화면은 dio 타입을 알 필요가 없다.
class BgmsApiClient {
  BgmsApiClient({required String baseUrl, Dio? dio, this.authTokenProvider})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: {..._dio.options.headers, 'Accept': 'application/json'},
    );
  }

  static const connectTimeout = Duration(seconds: 10);
  static const sendTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 25);

  /// AI 요약은 서버에서 생성 시간이 길어 별도 타임아웃을 쓴다.
  static const aiReceiveTimeout = Duration(seconds: 90);

  final String _baseUrl;
  final Dio _dio;
  final AuthTokenProvider? authTokenProvider;

  String get baseUrl => _baseUrl;

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

  Uri buildSuggestUri(String query) {
    return Uri.parse(
      '$_baseUrl/api/pubg/suggest',
    ).replace(queryParameters: {'q': query});
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

  Uri buildMapSettingsUri() {
    return Uri.parse('$_baseUrl/api/maps/settings');
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

  Uri buildDeleteAccountUri() {
    return Uri.parse('$_baseUrl/api/auth/delete-account');
  }

  Future<Map<String, dynamic>> fetchPlayer({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) {
    return _getJson(
      buildPlayerUri(
        nickname: nickname,
        platform: platform,
        season: season,
        refresh: refresh,
      ),
    );
  }

  Future<Map<String, dynamic>> fetchMatchesSummary({
    required List<String> matchIds,
    required String nickname,
    required String platform,
  }) {
    return _postJson(
      buildMatchesSummaryUri(),
      body: {'matchIds': matchIds, 'nickname': nickname, 'platform': platform},
    );
  }

  Future<Map<String, dynamic>> fetchMatchDetail({
    required String matchId,
    required String nickname,
    required String platform,
  }) {
    return _getJson(
      buildMatchUri(matchId: matchId, nickname: nickname, platform: platform),
    );
  }

  /// 닉네임 자동완성. 실패해도 화면을 막지 않도록 빈 목록을 허용한다.
  Future<List<PlayerSuggestion>> fetchSuggestions(String query) async {
    final json = await _getJson(buildSuggestUri(query));
    return PlayerSuggestion.parseList(json['suggestions']);
  }

  Future<String> fetchAiSummary({
    required List<String> matchIds,
    required String nickname,
    required String platform,
    String? accessToken,
  }) async {
    final headers = await _authHeaders(explicitToken: accessToken);
    if (headers == null) {
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'AI 코칭은 로그인 후 이용할 수 있습니다.',
      );
    }

    try {
      final response = await _dio.postUri<String>(
        buildAiSummaryUri(),
        data: {
          'matchIds': matchIds,
          'nickname': nickname,
          'platform': platform,
        },
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
          receiveTimeout: aiReceiveTimeout,
        ),
      );
      return response.data ?? '';
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<Map<String, dynamic>> fetchRankings({
    required String tab,
    String mode = 'all',
    String perspective = 'all',
    String matchType = 'all',
  }) {
    return _getJson(
      buildRankingsUri(
        tab: tab,
        mode: mode,
        perspective: perspective,
        matchType: matchType,
      ),
    );
  }

  Future<Map<String, dynamic>> fetchMapMarkers({
    required String mapId,
    List<String> layers = const [],
  }) {
    return _getJson(buildMapMarkersUri(mapId: mapId, layers: layers));
  }

  Future<Map<String, dynamic>> fetchAdminSettings() async {
    final data = await _getJson(buildAdminSettingsUri());
    if (data['success'] == true) {
      return Map<String, dynamic>.from(data['settings'] as Map? ?? {});
    }
    return {};
  }

  /// 맵별 마커 카테고리 설정. 서버가 웹과 동일한 정본을 내려준다.
  Future<Map<String, List<String>>> fetchMapCategories() async {
    final data = await _getJson(buildMapSettingsUri());
    final raw = data['mapCategories'];
    if (raw is! Map) return const {};

    final result = <String, List<String>>{};
    raw.forEach((key, value) {
      if (value is! List) return;
      final layers = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (layers.isNotEmpty) result[key.toString()] = layers;
    });
    return result;
  }

  Future<Map<String, dynamic>> fetchBoardPosts({
    int limit = 20,
    String? cursor,
    String category = 'all',
    String? query,
  }) {
    return _getJson(
      buildBoardPostsUri(
        limit: limit,
        cursor: cursor,
        category: category,
        query: query,
      ),
    );
  }

  Future<Map<String, dynamic>> fetchBoardPost({required int postId}) {
    return _getJson(buildBoardPostUri(postId));
  }

  Future<Map<String, dynamic>> createBoardPost({
    required String title,
    required String content,
    required String category,
    required String accessToken,
  }) {
    return _postJson(
      buildBoardPostsUri(),
      body: {'title': title, 'content': content, 'category': category},
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> createBoardComment({
    required int postId,
    required String content,
    required String accessToken,
  }) {
    final postUri = buildBoardPostUri(postId);
    return _postJson(
      postUri.replace(path: '${postUri.path}/comments'),
      body: {'content': content},
      accessToken: accessToken,
    );
  }

  /// 로그인 사용자의 계정과 서버 데이터를 삭제한다.
  ///
  /// 서버는 웹 쿠키 세션과 모바일 Bearer 토큰을 모두 허용한다.
  Future<Map<String, dynamic>> deleteAccount({required String accessToken}) {
    return _postJson(buildDeleteAccountUri(), accessToken: accessToken);
  }

  // ---------------------------------------------------------------------------
  // 내부 헬퍼
  // ---------------------------------------------------------------------------

  /// 명시 토큰을 우선 사용하고, 없으면 [authTokenProvider]에서 가져온다.
  Future<Map<String, String>?> _authHeaders({String? explicitToken}) async {
    if (explicitToken != null && explicitToken.isNotEmpty) {
      return {'Authorization': 'Bearer $explicitToken'};
    }
    final provider = authTokenProvider;
    if (provider == null) return null;
    final token = await provider();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      final response = await _dio.getUri<dynamic>(uri);
      return _asJsonMap(response.data);
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    Object? body,
    String? accessToken,
  }) async {
    try {
      final response = await _dio.postUri<dynamic>(
        uri,
        data: body,
        options: accessToken == null
            ? null
            : Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _asJsonMap(response.data);
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Map<String, dynamic> _asJsonMap(Object? data) {
    if (data == null) return <String, dynamic>{};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      kind: ApiErrorKind.parse,
      message: '서버 응답이 예상한 JSON 객체가 아닙니다.',
    );
  }
}
