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
    bool autoRefresh = false,
  }) {
    return Uri.parse('$_baseUrl/api/pubg/player').replace(
      queryParameters: {
        'nickname': nickname,
        'platform': platform,
        if (season != null && season.isNotEmpty) 'season': season,
        if (refresh) 'refresh': 'true' else if (autoRefresh) 'refresh': 'auto',
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

  Uri buildBoardPostUri(int postId, {bool refresh = false}) {
    final uri = Uri.parse('$_baseUrl/api/mobile/board/posts/$postId');
    return refresh ? uri.replace(queryParameters: {'refresh': '1'}) : uri;
  }

  Uri buildDeleteAccountUri() {
    return Uri.parse('$_baseUrl/api/auth/delete-account');
  }

  Future<Map<String, dynamic>> fetchPlayer({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
    bool autoRefresh = false,
  }) {
    return _getJson(
      buildPlayerUri(
        nickname: nickname,
        platform: platform,
        season: season,
        refresh: refresh,
        autoRefresh: autoRefresh,
      ),
      receiveTimeout: refresh || autoRefresh
          ? const Duration(seconds: 40)
          : null,
    );
  }

  Future<Map<String, dynamic>> fetchMatchesSummary({
    required List<String> matchIds,
    required String nickname,
    required String platform,
  }) {
    return _postJson(
      buildMatchesSummaryUri(),
      body: {
        'matchIds': matchIds,
        'nickname': nickname,
        'platform': platform,
        'collect': false,
      },
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

  Future<Map<String, dynamic>> fetchPlayerMatches({
    required String nickname,
    required String platform,
    int page = 1,
    String filter = 'all',
  }) => _getJson(
    Uri.parse('$_baseUrl/api/pubg/player/matches').replace(
      queryParameters: {
        'nickname': nickname,
        'platform': platform,
        'page': '$page',
        'filter': filter,
      },
    ),
  );

  Future<Map<String, dynamic>> collectPlayerMatches({
    required String nickname,
    required String platform,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/pubg/player/matches'),
    body: {'nickname': nickname, 'platform': platform},
  );

  Future<Map<String, dynamic>> fetchEncounters({
    required String nickname,
    required String platform,
    required String accessToken,
    int page = 1,
  }) => _getJson(
    Uri.parse('$_baseUrl/api/pubg/encounters').replace(
      queryParameters: {
        'nickname': nickname,
        'platform': platform,
        'page': '$page',
      },
    ),
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> collectEncounters({
    required String nickname,
    required String platform,
    required String matchId,
    required String accessToken,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/pubg/encounters'),
    body: {
      'action': 'collect',
      'nickname': nickname,
      'platform': platform,
      'matchId': matchId,
    },
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> fetchEncounterProfile({
    required String nickname,
    required String platform,
    required String matchId,
    required String targetAccountId,
    required String accessToken,
    bool refresh = false,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/pubg/encounters'),
    body: {
      'action': 'profiles',
      'nickname': nickname,
      'platform': platform,
      'matchId': matchId,
      'targetAccountId': targetAccountId,
      'refresh': refresh,
    },
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> createBanWatch({
    required Map<String, dynamic> payload,
    required String accessToken,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/pubg/ban-watch'),
    body: payload,
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> fetchBanWatches({required String accessToken}) =>
      _getJson(
        Uri.parse('$_baseUrl/api/pubg/ban-watch'),
        accessToken: accessToken,
      );

  Future<Map<String, dynamic>> removeBanWatch({
    required String watchId,
    required String accessToken,
  }) async {
    try {
      if (accessToken.isEmpty) {
        throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: '로그인이 필요합니다.',
        );
      }
      final response = await _dio.deleteUri<dynamic>(
        Uri.parse(
          '$_baseUrl/api/pubg/ban-watch',
        ).replace(queryParameters: {'id': watchId}),
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _asJsonMap(response.data);
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<Map<String, dynamic>> fetchWeaponMastery({
    required String nickname,
    required String platform,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/pubg/player/weapon-mastery'),
    body: {'nickname': nickname, 'platform': platform},
  );

  Future<Map<String, dynamic>> fetchBattle({
    required String nick1,
    required String nick2,
    required String platform1,
    String? platform2,
    String matchType = 'all',
  }) => _getJson(
    Uri.parse('$_baseUrl/api/pubg/battle').replace(
      queryParameters: {
        'nick1': nick1,
        'nick2': nick2,
        'platform1': platform1,
        'platform2': platform2 ?? platform1,
        'matchType': matchType,
      },
    ),
  );

  Future<Map<String, dynamic>> fetchWeaponMeta({
    String matchType = 'all',
    String? patch,
  }) => _getJson(
    Uri.parse('$_baseUrl/api/pubg/meta').replace(
      queryParameters: {
        'matchType': matchType,
        if (patch != null && patch.isNotEmpty) 'patch': patch,
      },
    ),
  );

  Future<Map<String, dynamic>> fetchHotdrops(String mapId) => _getJson(
    Uri.parse(
      '$_baseUrl/api/pubg/hotdrop',
    ).replace(queryParameters: {'mapName': mapId.toLowerCase()}),
  );

  Future<Map<String, dynamic>> fetchTelemetry({
    required String matchId,
    required String nickname,
    required String platform,
    required String mapName,
  }) async {
    final envelope = await _getJson(
      Uri.parse('$_baseUrl/api/pubg/telemetry').replace(
        queryParameters: {
          'matchId': matchId,
          'nickname': nickname,
          'platform': platform,
          'mapName': mapName,
          'mode': 'lite',
        },
      ),
    );
    final identity = envelope['identity'];
    if (identity is! Map ||
        identity['matchId'] != matchId ||
        identity['platform'] != platform ||
        identity['mode'] != 'lite' ||
        !RegExp(
          r'^[a-f0-9]{32}$',
        ).hasMatch(identity['playerKey']?.toString() ?? '') ||
        identity['telemetryVersion'] is! num ||
        !(identity['telemetryVersion'] as num).isFinite ||
        (identity['telemetryVersion'] as num) <= 0) {
      throw const ApiException(
        kind: ApiErrorKind.parse,
        message: '리플레이 경기 정보가 요청과 일치하지 않습니다.',
      );
    }
    final url = Uri.tryParse(envelope['downloadUrl']?.toString() ?? '');
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.port != 443) {
      throw const ApiException(
        kind: ApiErrorKind.parse,
        message: '리플레이 다운로드 주소를 확인할 수 없습니다.',
      );
    }
    // 외부 서명 URL에는 앱 인증 토큰을 전달하지 않는다.
    final payload = await _getJson(url);
    final actual = payload['identity'];
    if (actual is! Map ||
        const [
          'matchId',
          'platform',
          'playerKey',
          'mode',
          'telemetryVersion',
        ].any((field) => actual[field] != identity[field])) {
      throw const ApiException(
        kind: ApiErrorKind.parse,
        message: '리플레이 파일의 경기 정보가 일치하지 않습니다.',
      );
    }
    return payload;
  }

  Future<Map<String, dynamic>> fetchSupportFaqs({
    String? category,
    String? query,
  }) => _getJson(
    Uri.parse('$_baseUrl/api/support/faqs').replace(
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    ),
  );

  Future<Map<String, dynamic>> fetchSupportTickets({
    required String accessToken,
  }) => _getJson(
    Uri.parse('$_baseUrl/api/support/tickets'),
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> fetchSupportTicket({
    required String ticketId,
    required String accessToken,
  }) => _getJson(
    Uri.parse('$_baseUrl/api/support/tickets/${Uri.encodeComponent(ticketId)}'),
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> createSupportTicket({
    required Map<String, dynamic> body,
    required String accessToken,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/support/tickets'),
    body: body,
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> createSupportMessage({
    required String ticketId,
    required String body,
    required String idempotencyKey,
    required String accessToken,
  }) => _postJson(
    Uri.parse(
      '$_baseUrl/api/support/tickets/${Uri.encodeComponent(ticketId)}/messages',
    ),
    body: {'body': body},
    headers: {'Idempotency-Key': idempotencyKey},
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> fetchSupportAttachmentUrl({
    required String attachmentId,
    required String accessToken,
  }) => _getJson(
    Uri.parse(
      '$_baseUrl/api/support/attachments/${Uri.encodeComponent(attachmentId)}/url',
    ),
    accessToken: accessToken,
  );

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
          'summaryContractVersion': 2,
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

  Future<Map<String, dynamic>> fetchBoardPost({
    required int postId,
    bool refresh = false,
    String? accessToken,
  }) => _getJson(
    buildBoardPostUri(postId, refresh: refresh),
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> createBoardPost({
    required String title,
    required String content,
    required String category,
    required String accessToken,
    List<String> contentImageIds = const [],
    String? thumbnailImageId,
  }) => _postJson(
    buildBoardPostsUri(),
    body: {
      'title': title,
      'content': content,
      'category': category,
      'contentImageIds': contentImageIds,
      'thumbnailImageId': thumbnailImageId,
    },
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> fetchBoardEdit({
    required int postId,
    required String accessToken,
  }) => _getJson(
    Uri.parse('$_baseUrl/api/mobile/board/posts/$postId/edit'),
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> updateBoardPost({
    required int postId,
    required Map<String, dynamic> body,
    required String accessToken,
  }) => _boardMutation(
    'PATCH',
    '/api/mobile/board/posts/$postId',
    body,
    accessToken,
  );

  Future<Map<String, dynamic>> deleteBoardPost({
    required int postId,
    required int expectedRevision,
    required String accessToken,
  }) => _boardMutation('DELETE', '/api/mobile/board/posts/$postId', {
    'expectedRevision': expectedRevision,
  }, accessToken);

  Future<Map<String, dynamic>> fetchBoardComments({
    required int postId,
    String? cursor,
    String? accessToken,
  }) => _getJson(
    Uri.parse(
      '$_baseUrl/api/mobile/board/posts/$postId/comments',
    ).replace(queryParameters: {'limit': '50', 'cursor': ?cursor}),
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> likeBoardPost({
    required int postId,
    required String accessToken,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/mobile/board/posts/$postId/likes'),
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> reportBoardContent({
    required String targetType,
    required int targetId,
    required String reason,
    String? detail,
    required String accessToken,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/board/report'),
    body: {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    },
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> reserveBoardImage({
    required String mimeType,
    required int byteSize,
    required String accessToken,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/board/images/reserve'),
    body: {'mimeType': mimeType, 'byteSize': byteSize},
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> completeBoardImage({
    required String imageId,
    required String accessToken,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/board/images/complete'),
    body: {'imageId': imageId},
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> releaseBoardImages({
    required List<String> imageIds,
    required String accessToken,
  }) => _postJson(
    Uri.parse('$_baseUrl/api/board/images/release'),
    body: {'imageIds': imageIds},
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> _boardMutation(
    String method,
    String path,
    Map<String, dynamic> body,
    String accessToken,
  ) async {
    try {
      if (accessToken.isEmpty) {
        throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: '로그인이 필요합니다.',
        );
      }
      final response = await _dio.requestUri<dynamic>(
        Uri.parse('$_baseUrl$path'),
        data: body,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      return _asJsonMap(response.data);
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<Map<String, dynamic>> createBoardComment({
    required int postId,
    required String content,
    required String accessToken,
    int? parentId,
  }) {
    final postUri = buildBoardPostUri(postId);
    return _postJson(
      postUri.replace(path: '${postUri.path}/comments'),
      body: {'content': content, 'parent_id': ?parentId},
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
    if (explicitToken != null && explicitToken.isEmpty) return null;
    if (explicitToken != null && explicitToken.isNotEmpty) {
      return {'Authorization': 'Bearer $explicitToken'};
    }
    final provider = authTokenProvider;
    if (provider == null) return null;
    final token = await provider();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    String? accessToken,
    Duration? receiveTimeout,
  }) async {
    try {
      if (accessToken != null && accessToken.isEmpty) {
        throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: '로그인이 필요합니다.',
        );
      }
      final response = await _dio.getUri<dynamic>(
        uri,
        options: accessToken == null && receiveTimeout == null
            ? null
            : Options(
                receiveTimeout: receiveTimeout,
                headers: {
                  if (accessToken != null)
                    'Authorization': 'Bearer $accessToken',
                },
              ),
      );
      return _asJsonMap(response.data);
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    Object? body,
    String? accessToken,
    Map<String, String> headers = const {},
  }) async {
    try {
      if (accessToken != null && accessToken.isEmpty) {
        throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: '로그인이 필요합니다.',
        );
      }
      final response = await _dio.postUri<dynamic>(
        uri,
        data: body,
        options: Options(
          headers: {
            ...headers,
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
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
