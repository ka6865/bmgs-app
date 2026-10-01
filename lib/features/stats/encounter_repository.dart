import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'encounter_models.dart';

class EncounterRepository {
  EncounterRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<EncounterPage> fetch({
    required String nickname,
    required String platform,
    required String accessToken,
    int page = 1,
  }) async {
    final json = await _client.fetchEncounters(
      nickname: nickname,
      platform: platform,
      page: page,
      accessToken: accessToken,
    );
    return EncounterPage.fromJson(json);
  }

  Future<void> collect({
    required String nickname,
    required String platform,
    required String matchId,
    required String accessToken,
  }) async {
    await _client.collectEncounters(
      nickname: nickname,
      platform: platform,
      matchId: matchId,
      accessToken: accessToken,
    );
  }

  Future<EncounterProfile> fetchProfile({
    required String nickname,
    required String platform,
    required String matchId,
    required String targetAccountId,
    required String accessToken,
    bool refresh = false,
  }) async {
    final json = await _client.fetchEncounterProfile(
      nickname: nickname,
      platform: platform,
      matchId: matchId,
      targetAccountId: targetAccountId,
      accessToken: accessToken,
      refresh: refresh,
    );
    final rawProfile = json['profile'];
    return EncounterProfile.fromJson(
      rawProfile is Map
          ? Map<String, dynamic>.from(rawProfile)
          : const <String, dynamic>{},
    );
  }

  Future<void> watch({
    required Map<String, dynamic> payload,
    required String accessToken,
  }) async {
    await _client.createBanWatch(payload: payload, accessToken: accessToken);
  }
}
