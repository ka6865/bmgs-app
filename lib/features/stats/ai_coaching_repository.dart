import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
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
      final summary = AiCoachingSummary.fromNdjson(body);
      if (summary.status == AiCoachingStatus.available) {
        return summary;
      }
      return summary;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return AiCoachingSummary.loginRequired();
      }
      if (status == 402 || status == 429) {
        return AiCoachingSummary.costRestricted();
      }
      return AiCoachingSummary.unavailable(
        'AI 요약 API 실패: ${_dioMessage(error)}',
      );
    } catch (error) {
      return AiCoachingSummary.unavailable('AI 요약 응답 파싱 실패: $error');
    }
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

  String? _accessTokenOrNull() {
    if (!AppConfig.local.canInitializeSupabase) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }
}
