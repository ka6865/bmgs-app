import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/stats/weapon_mastery_models.dart';
import 'package:bgms_mobile_app/features/stats/weapon_mastery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_http_adapter.dart';

void main() {
  test('갱신한 숙련도는 기기에 저장해 다음 진입에서 서버 호출 없이 보여준다', () async {
    SharedPreferences.setMockInitialValues({});
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/pubg/player/weapon-mastery': {
          'success': true,
          'weaponMastery': [
            {'weaponId': 'Item_Weapon_BerylM762_C', 'level': 87, 'kills': 3},
          ],
        },
      },
    );
    WeaponMasteryRepository repository() => WeaponMasteryRepository(
      client: BgmsApiClient(
        baseUrl: 'https://example.test',
        dio: createFakeDio(adapter),
      ),
    );

    expect(
      await repository().cached(nickname: 'Kang', platform: 'steam'),
      isNull,
    );
    await repository().refresh(nickname: 'Kang', platform: 'steam');
    final requests = adapter.requestedPaths.length;

    final cached = await repository().cached(
      nickname: 'kang',
      platform: 'STEAM',
    );
    expect(adapter.requestedPaths.length, requests);
    expect(cached!.items.single.label, '베릴 M762');
    expect(cached.items.single.level, 87);
    expect(
      await repository().cached(nickname: 'other', platform: 'steam'),
      isNull,
    );
  });

  test('이름표에 없는 무기는 내부 이름을 읽기 쉽게 바꾸고 공식 이미지 주소를 쓴다', () {
    final item = WeaponMasteryItem.fromJson({
      'weaponId': 'Item_Weapon_New_Gun_C',
    });
    expect(item.label, 'New Gun');
    expect(item.imageUrl, endsWith('/Weapon/Main/Item_Weapon_New_Gun_C.png'));
  });
}
