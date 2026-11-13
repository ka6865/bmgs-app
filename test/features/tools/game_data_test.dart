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
  test('게임 숫자와 무기 응답을 안전하게 읽는다', () {
    expect(gameNumber(null), isNull);
    expect(gameNumber(-1), isNull);
    expect(gameNumber(double.infinity), isNull);
    expect(gameNumber('0.5'), 0.5);
    final weapon = GameWeapon.fromJson({'id': 'a', 'name': '총기', 'type': 'AR'});
    expect(weapon.damage, isNull);
    expect(weapon.bulletSpeed, isNull);
  });
}
