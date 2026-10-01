import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'weapon_mastery_models.dart';

class WeaponMasteryRepository {
  WeaponMasteryRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);
  final BgmsApiClient _client;

  Future<List<WeaponMasteryItem>> refresh({
    required String nickname,
    required String platform,
  }) async {
    final json = await _client.fetchWeaponMastery(
      nickname: nickname,
      platform: platform,
    );
    if (json['success'] != true) {
      throw StateError(json['error']?.toString() ?? '무기 숙련도 갱신에 실패했습니다.');
    }
    return WeaponMasteryItem.parseList(json['weaponMastery']);
  }
}
