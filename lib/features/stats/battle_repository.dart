import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'battle_models.dart';

class BattleRepository {
  BattleRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<BattleResult> compare({
    required String firstNickname,
    required String secondNickname,
    required String firstPlatform,
    String? secondPlatform,
    String matchType = 'all',
  }) async {
    final json = await _client.fetchBattle(
      nick1: firstNickname,
      nick2: secondNickname,
      platform1: firstPlatform,
      platform2: secondPlatform,
      matchType: matchType,
    );
    return BattleResult.fromJson(json);
  }
}
