import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'squad_models.dart';

class SquadRepository {
  SquadRepository({BgmsApiClient? client, Future<String?> Function()? token})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl),
      _token = token ?? _supabaseToken;

  final BgmsApiClient _client;
  final Future<String?> Function() _token;

  Future<List<SquadGroup>> fetchGroups({
    required String nickname,
    required String platform,
  }) async => SquadGroup.listFromJson(
    await _client.fetchSquadAnalysis(nickname: nickname, platform: platform),
  );

  Future<SquadAnalysis> fetchAnalysis({
    required String nickname,
    required String platform,
    required String groupKey,
  }) async => SquadAnalysis.fromJson(
    await _client.fetchSquadAnalysis(
      nickname: nickname,
      platform: platform,
      groupKey: groupKey,
    ),
  );

  /// 로그인하지 않았으면 서버를 부르지 않고 unauthorized로 끝낸다.
  Future<SquadAiResult> fetchAi({
    required String nickname,
    required String platform,
    required String groupKey,
    required bool spicy,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: '스쿼드 AI 코칭은 로그인 후 이용할 수 있습니다.',
      );
    }
    return SquadAiResult.fromJson(
      await _client.fetchSquadAi(
        nickname: nickname,
        platform: platform,
        groupKey: groupKey,
        coachingStyle: spicy ? 'spicy' : 'mild',
        accessToken: token,
      ),
    );
  }

  static Future<String?> _supabaseToken() async {
    if (!AppConfig.local.canInitializeSupabase) return null;
    try {
      final auth = Supabase.instance.client.auth;
      var session = auth.currentSession;
      if (session?.isExpired == true) {
        session = (await auth.refreshSession()).session;
      }
      return session?.accessToken;
    } catch (_) {
      return null;
    }
  }
}
