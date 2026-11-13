import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'match_ai_models.dart';

class MatchAiRepository {
  MatchAiRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<MatchAiResult> analyze({
    required String matchId,
    required String nickname,
    required String platform,
    required bool spicy,
  }) async {
    final body = await _client.fetchMatchAi(
      matchId: matchId,
      nickname: nickname,
      platform: platform,
      coachingStyle: spicy ? 'spicy' : 'mild',
      accessToken: await _accessTokenOrNull(),
    );
    return MatchAiResult.fromNdjson(body);
  }

  Future<String?> _accessTokenOrNull() async {
    if (!AppConfig.local.canInitializeSupabase) return null;
    try {
      final client = Supabase.instance.client;
      var session = client.auth.currentSession;
      if (session?.isExpired == true) {
        session = (await client.auth.refreshSession()).session;
      }
      return session?.accessToken;
    } catch (_) {
      return null;
    }
  }
}
