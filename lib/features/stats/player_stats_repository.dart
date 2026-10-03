import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'player_match_history_models.dart';
import 'player_stats_models.dart';

class PlayerStatsRepository {
  PlayerStatsRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
    bool includeSummaries = true,
  }) async {
    // 화면 진입의 기본 시즌만 서버의 15분 기준 자동 갱신 대상으로 삼는다.
    // 알림은 includeSummaries:false를 사용하며 과거 시즌은 저장 기록만 읽는다.
    final autoRefresh = !refresh && includeSummaries && season == null;
    try {
      final playerJson = await _client.fetchPlayer(
        nickname: nickname,
        platform: platform,
        season: season,
        refresh: refresh,
        autoRefresh: autoRefresh,
      );
      final profile = PlayerStatsProfile.fromJson(playerJson);
      String? collectionMessage;
      DateTime? collectionAvailableAt;
      if (includeSummaries &&
          (refresh || profile.syncStatus == PlayerSyncStatus.saved)) {
        // 사용자 갱신 또는 새 저장 후 한 배치만 처리한다. 반복 수집하지 않는다.
        try {
          final result = PlayerMatchCollectionResult.fromJson(
            await _client.collectPlayerMatches(
              nickname: profile.nickname.isEmpty ? nickname : profile.nickname,
              platform: profile.platform,
            ),
          );
          final collection = result.collection;
          collectionAvailableAt = DateTime.now().add(
            Duration(seconds: collection?.rateLimited == true ? 60 : 15),
          );
          final pending = result.historyIngest?.pendingCount;
          collectionMessage = collection == null
              ? '경기 수집 결과를 확인할 수 없습니다. DB 전체 경기 이력에서 확인하세요.'
              : '경기 수집 DB 저장 확인 ${collection.saved ?? '?'}경기'
                    '${collection.newSaved == null ? ' (신규 저장 구분 불가)' : ' · 신규 ${collection.newSaved}경기'}'
                    ' · ${pending == null ? '대기 상태 불명' : '수집 대기 $pending경기'}'
                    '${collection.rateLimited == true ? ' · 호출 한도 도달' : ''}'
                    '${(collection.retry ?? 0) > 0 ? ' · 재시도 대기 ${collection.retry}경기' : ''}'
                    '${(collection.unavailable ?? 0) > 0 ? ' · 만료·조회 불가 ${collection.unavailable}경기' : ''}. DB 전체 경기 이력에서 확인하세요.';
        } catch (error) {
          final apiError = ApiException.from(error);
          if (apiError.kind == ApiErrorKind.rateLimited) {
            collectionAvailableAt = DateTime.now().add(
              apiError.retryAfter ?? const Duration(seconds: 15),
            );
          }
          collectionMessage =
              '경기 수집 실패 · 시즌 기록은 유지합니다. ${apiError.message} DB 전체 경기 이력에서 다시 수집할 수 있습니다.';
        }
      }
      final matchIds = profile.recentMatches.take(20).toList();

      if (matchIds.isEmpty || !includeSummaries) {
        return PlayerStatsBundle(
          profile: profile,
          matches: const [],
          summaryFallback: false,
          requestedRefresh: refresh,
          collectionMessage: collectionMessage,
          collectionAvailableAt: collectionAvailableAt,
        );
      }

      final resolvedNickname = profile.nickname.isNotEmpty
          ? profile.nickname
          : nickname;
      Map summaries = const {};
      String? summaryError;
      try {
        final summariesJson = await _client.fetchMatchesSummary(
          matchIds: matchIds,
          nickname: resolvedNickname,
          platform: profile.platform,
        );
        summaries = summariesJson['summaries'] as Map? ?? const {};
      } catch (error) {
        summaryError = ApiException.from(error).message;
      }
      final matches = matchIds.map((matchId) {
        final summary = summaries[matchId];
        if (summary is Map) {
          return MatchSummary.fromJson(
            matchId,
            Map<String, dynamic>.from(summary),
          );
        }
        return MatchSummary.fallback(
          matchId: matchId,
          gameMode: profile.matchModes[matchId] ?? '',
        );
      }).toList();

      return PlayerStatsBundle(
        profile: profile,
        matches: matches,
        summaryFallback: matches.any((match) => match.isFallback),
        summaryError: summaryError,
        requestedRefresh: refresh,
        collectionMessage: collectionMessage,
        collectionAvailableAt: collectionAvailableAt,
      );
    } catch (error) {
      throw PlayerStatsException.from(ApiException.from(error));
    }
  }
}

class PlayerStatsException implements Exception {
  const PlayerStatsException(
    this.message, {
    this.isRetryable = true,
    this.suggestions = const [],
    this.retryAfter,
  });

  /// 정규화된 API 에러를 전적 화면 문구로 옮긴다.
  factory PlayerStatsException.from(ApiException error) {
    final message = switch (error.kind) {
      ApiErrorKind.notFound => '닉네임을 찾을 수 없습니다. 대소문자와 플랫폼을 확인해 주세요.',
      ApiErrorKind.rateLimited =>
        'PUBG API 호출 한도가 일시적으로 초과되었습니다. 잠시 후 다시 시도해 주세요.',
      _ => error.message,
    };
    return PlayerStatsException(
      message,
      isRetryable: error.isRetryable,
      suggestions: error.suggestions,
      retryAfter: error.retryAfter,
    );
  }

  final String message;
  final bool isRetryable;

  /// 닉네임을 찾지 못했을 때 서버가 제안하는 유사 플레이어 목록.
  final List<PlayerSuggestion> suggestions;
  final Duration? retryAfter;

  @override
  String toString() => message;
}
