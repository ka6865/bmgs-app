import 'package:bgms_mobile_app/features/tools/game_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('부착물 음수 변화량과 미제공 값·슬롯 분기를 보존한다', () {
    final muzzle = GameAttachment.fromJson({
      'id': 'm',
      'name': '총구',
      'slot': 'muzzle',
      'vertical_recoil': -20,
    });
    final grip = GameAttachment.fromJson({
      'id': 'g',
      'name': '손잡이',
      'slot': 'grip',
      'vertical_recoil': '-15',
    });
    expect(
      attachmentEffect(
        [muzzle, grip],
        ['muzzle', 'grip', 'stock'],
        (p) => p.verticalRecoil,
      ),
      -35,
    );
    expect(
      attachmentEffect([muzzle], ['muzzle'], (p) => p.horizontalRecoil),
      isNull,
    );
    expect(attachmentEffect([muzzle], ['magazine'], (p) => p.reloadSpeed), 0);
    const weapon = GameWeapon(id: 'ar_m416', name: 'M416', type: 'AR');
    expect(
      weaponAttachmentSlots(weapon),
      containsAll(['muzzle', 'grip', 'magazine', 'sight', 'stock']),
    );
    expect(
      weaponAttachmentSlots(
        const GameWeapon(id: 'smg_p90', name: 'P90', type: 'SMG'),
      ),
      isEmpty,
    );
  });
  test('웹과 같은 가방·조끼 용량과 단위 무게×수량을 계산한다', () {
    expect(backpackCapacity(hasVest: false, level: 0), 70);
    expect(backpackCapacity(hasVest: true, level: 0), 120);
    expect(backpackCapacity(hasVest: false, level: 3), 320);
    expect(backpackCapacity(hasVest: true, level: 1), 270);
    expect(backpackCapacity(hasVest: true, level: 2), 320);
    expect(backpackCapacity(hasVest: true, level: 3), 370);
    const items = [
      BackpackItem(id: 'ammo', name: '탄약', category: 'ammo', weight: 0.5),
      BackpackItem(id: 'heal', name: '회복', category: 'consumables', weight: 10),
    ];
    expect(inventoryWeight(items, {'ammo': 30, 'heal': 2}), 35);
    expect(inventoryWeight(items, {}), 0);
    expect(gameNumber(null), isNull);
    expect(gameNumber(-1), isNull);
    expect(gameNumber(double.infinity), isNull);
    expect(gameNumber('0.5'), 0.5);
    final weapon = GameWeapon.fromJson({'id': 'a', 'name': '총기', 'type': 'AR'});
    expect(weapon.damage, isNull);
    expect(weapon.bulletSpeed, isNull);
  });
}
