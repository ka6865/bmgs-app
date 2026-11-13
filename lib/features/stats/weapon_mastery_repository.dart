import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'weapon_mastery_models.dart';

/// 마지막으로 갱신한 숙련도와 그 시각.
typedef WeaponMasterySnapshot = ({
  List<WeaponMasteryItem> items,
  DateTime savedAt,
});

class WeaponMasteryRepository {
  WeaponMasteryRepository({
    BgmsApiClient? client,
    Future<SharedPreferences> Function()? preferences,
  }) : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl),
       _preferences = preferences ?? SharedPreferences.getInstance;
  final BgmsApiClient _client;
  final Future<SharedPreferences> Function() _preferences;

  static String _key(String nickname, String platform) =>
      'bgms_weapon_mastery_v1:${platform.toLowerCase()}:${nickname.toLowerCase()}';

  /// 기기에 저장해 둔 마지막 결과. 없거나 읽지 못하면 null.
  Future<WeaponMasterySnapshot?> cached({
    required String nickname,
    required String platform,
  }) async {
    try {
      final raw = (await _preferences()).getString(_key(nickname, platform));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(json['savedAt']?.toString() ?? '');
      if (savedAt == null) return null;
      return (
        items: WeaponMasteryItem.parseList(json['weaponMastery']),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  /// 서버에 갱신을 요청하고 성공한 결과만 기기에 저장한다.
  Future<WeaponMasterySnapshot> refresh({
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
    final savedAt = DateTime.now();
    try {
      await (await _preferences()).setString(
        _key(nickname, platform),
        jsonEncode({
          'savedAt': savedAt.toIso8601String(),
          'weaponMastery': json['weaponMastery'],
        }),
      );
    } catch (_) {
      // 저장 실패는 이번 화면 표시를 막지 않는다. 다음에 열면 다시 갱신하면 된다.
    }
    return (
      items: WeaponMasteryItem.parseList(json['weaponMastery']),
      savedAt: savedAt,
    );
  }
}
