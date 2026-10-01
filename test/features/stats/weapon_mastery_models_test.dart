import 'package:bgms_mobile_app/features/stats/weapon_mastery_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('공식과 경쟁전 무기 숙련도를 합산하고 킬 순으로 정렬한다', () {
    final weapons = WeaponMasteryItem.parseList([
      {
        'weaponId': 'Item_Weapon_AK47_C',
        'category': 'AR',
        'level': 7,
        'kills': 12,
        'rankKills': 3,
        'damagePlayer': 1420.5,
        'rankDamagePlayer': 300,
      },
      {
        'weaponId': 'Item_Weapon_M24_C',
        'category': 'SR',
        'level': 8,
        'kills': 9,
        'rankKills': 7,
        'damagePlayer': 800,
        'rankDamagePlayer': 500,
      },
    ]);

    expect(weapons.first.label, 'M24');
    expect(weapons.first.totalKills, 16);
    expect(weapons.first.totalDamage, 1300);
    expect(weapons.last.label, 'AK47');
    expect(weapons.last.totalKills, 15);
  });
}
