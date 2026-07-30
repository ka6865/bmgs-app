import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'ai_coaching_models.dart';
import 'player_stats_models.dart';

class AiCoachingRepository {
  AiCoachingRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<AiCoachingSummary> summarize({
    required PlayerStatsProfile profile,
    required List<MatchSummary> matches,
    bool allowRemote = true,
  }) async {
    if (profile.recentMatches.isEmpty) {
      return AiCoachingSummary.unavailable('최근 매치가 없어 AI 코칭 요약을 만들 수 없습니다.');
    }

    if (!allowRemote) {
      return AiCoachingSummary.unavailable('AI 원격 호출이 비활성화되어 있습니다.');
    }

    try {
      final body = await _client.fetchAiSummary(
        matchIds: profile.recentMatches.take(10).toList(),
        nickname: profile.nickname,
        platform: profile.platform,
        accessToken: _accessTokenOrNull(),
      );
      return AiCoachingSummary.fromNdjson(body);
    } catch (error) {
      final apiError = ApiException.from(error);
      // 402는 결제/쿼터 초과라서 dio 기본 분류에서 unknown으로 떨어진다.
      final isCostLimit =
          apiError.kind == ApiErrorKind.rateLimited ||
          apiError.statusCode == 402;
      if (apiError.kind == ApiErrorKind.unauthorized) {
        return AiCoachingSummary.loginRequired();
      }
      if (isCostLimit) {
        return AiCoachingSummary.costRestricted();
      }
      return AiCoachingSummary.unavailable('AI 요약을 불러오지 못했습니다. ${apiError.message}');
    }
  }

  String? _accessTokenOrNull() {
    if (!AppConfig.local.canInitializeSupabase) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }
}
