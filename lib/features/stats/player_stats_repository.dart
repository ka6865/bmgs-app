import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
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
      );
    } catch (error) {
      throw PlayerStatsException.from(ApiException.from(error));
    }
  }
}

class PlayerStatsException implements Exception {
  const PlayerStatsException(this.message, {this.isRetryable = true});

  /// 정규화된 API 에러를 전적 화면 문구로 옮긴다.
  factory PlayerStatsException.from(ApiException error) {
    final message = switch (error.kind) {
      ApiErrorKind.notFound => '닉네임을 찾을 수 없습니다. 대소문자와 플랫폼을 확인해 주세요.',
      ApiErrorKind.rateLimited => 'PUBG API 호출 한도가 일시적으로 초과되었습니다. 잠시 후 다시 시도해 주세요.',
      _ => error.message,
    };
    return PlayerStatsException(message, isRetryable: error.isRetryable);
  }

  final String message;
  final bool isRetryable;

  @override
  String toString() => message;
}
