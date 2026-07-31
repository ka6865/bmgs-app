import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'player_stats_models.dart';

class PlayerStatsRepository {
  PlayerStatsRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  /// 요약 캐시가 없는 매치를 상세 API로 보완할 최대 건수.
  ///
  /// 서버 `matches-summary`는 캐시만 읽고 분석을 트리거하지 않는다.
  /// 반면 `match` 상세 API는 미분석 매치를 처리해 결과를 남기므로,
  /// 앞쪽 몇 건만 상세로 채워 "분석 대기" 카드가 계속 남는 것을 막는다.
  static const maxDetailBackfill = 4;

  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) async {
    try {
      final playerJson = await _client.fetchPlayer(
        nickname: nickname,
        platform: platform,
        season: season,
        refresh: refresh,
      );
      final profile = PlayerStatsProfile.fromJson(playerJson);
      final matchIds = profile.recentMatches.take(20).toList();

      if (matchIds.isEmpty) {
        return PlayerStatsBundle(
          profile: profile,
          matches: const [],
          summaryFallback: false,
        );
      }

      final summariesJson = await _client.fetchMatchesSummary(
        matchIds: matchIds,
        nickname: profile.nickname.isNotEmpty ? profile.nickname : nickname,
        platform: profile.platform,
      );
      final summaries = summariesJson['summaries'] as Map? ?? const {};
      final resolvedNickname = profile.nickname.isNotEmpty
          ? profile.nickname
          : nickname;
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

      await _backfillMissingSummaries(
        matches: matches,
        nickname: resolvedNickname,
        platform: profile.platform,
      );

      return PlayerStatsBundle(
        profile: profile,
        matches: matches,
        summaryFallback: matches.any((match) => match.isFallback),
      );
    } catch (error) {
      throw PlayerStatsException.from(ApiException.from(error));
    }
  }

  /// 요약이 비어 있는 매치를 상세 API로 채운다.
  ///
  /// 상세 호출은 비용이 크므로 앞쪽 [maxDetailBackfill]건만 처리하고,
  /// 개별 실패는 무시해 화면 전체가 막히지 않게 한다.
  Future<void> _backfillMissingSummaries({
    required List<MatchSummary> matches,
    required String nickname,
    required String platform,
  }) async {
    final targets = <int>[];
    for (var index = 0; index < matches.length; index++) {
      if (!matches[index].isFallback) continue;
      targets.add(index);
      if (targets.length >= maxDetailBackfill) break;
    }
    if (targets.isEmpty) return;

    final results = await Future.wait(
      targets.map((index) async {
        try {
          final json = await _client.fetchMatchDetail(
            matchId: matches[index].matchId,
            nickname: nickname,
            platform: platform,
          );
          return MatchSummary.fromJson(matches[index].matchId, json);
        } catch (_) {
          // 개별 매치 분석 실패는 fallback 카드로 남긴다.
          return null;
        }
      }),
    );

    for (var i = 0; i < targets.length; i++) {
      final resolved = results[i];
      if (resolved != null) matches[targets[i]] = resolved;
    }
  }
}

class PlayerStatsException implements Exception {
  const PlayerStatsException(
    this.message, {
    this.isRetryable = true,
    this.suggestions = const [],
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
    );
  }

  final String message;
  final bool isRetryable;

  /// 닉네임을 찾지 못했을 때 서버가 제안하는 유사 플레이어 목록.
  final List<PlayerSuggestion> suggestions;

  @override
  String toString() => message;
}
