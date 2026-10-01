import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'player_match_history_models.dart';

class PlayerMatchHistoryRepository {
  PlayerMatchHistoryRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<PlayerMatchHistoryPage> fetchPage({
    required String nickname,
    required String platform,
    int page = 1,
    String filter = 'all',
  }) async {
    final json = await _client.fetchPlayerMatches(
      nickname: nickname,
      platform: platform,
      page: page,
      filter: filter,
    );
    return PlayerMatchHistoryPage.fromJson(json);
  }
}
