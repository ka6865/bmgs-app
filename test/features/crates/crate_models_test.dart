import 'package:bgms_mobile_app/features/crates/crate_draw.dart';
import 'package:bgms_mobile_app/features/crates/crate_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('등급 문자열을 열거형으로 옮긴다', () {
    expect(CrateRarity.parse('ULTIMATE'), CrateRarity.ultimate);
    expect(CrateRarity.parse('legendary'), CrateRarity.legendary);
    expect(CrateRarity.parse('EPIC'), CrateRarity.epic);
    expect(CrateRarity.parse('ELITE'), CrateRarity.elite);
    // 모르는 값과 null은 일반으로 떨어뜨린다.
    expect(CrateRarity.parse('UNKNOWN'), CrateRarity.common);
    expect(CrateRarity.parse(null), CrateRarity.common);
  });

  test('상위 등급만 강조 대상이다', () {
    expect(CrateRarity.ultimate.isHighlight, isTrue);
    expect(CrateRarity.legendary.isHighlight, isTrue);
    expect(CrateRarity.epic.isHighlight, isFalse);
    expect(CrateRarity.common.isHighlight, isFalse);
  });

  test('실제 서버 응답 구조를 파싱한다', () {
    // Supabase 중첩 select 응답을 그대로 재현한다.
    final template = CrateTemplate.tryParse({
      'id': 'tpl-1',
      'name': '코스믹 칼리버 - 밀수품 상자',
      'description': '성장형 Kar98k 스킨',
      'image_url': '/images/crates/contraband_crate.png',
      'price_gcoin': 200,
      'bundle_price_gcoin': 1800,
      'crate_item_relations': [
        {
          'id': 'rel-1',
          'drop_type': 'base',
          'probability': 0.00875,
          'token_count': 0,
          'is_prime_parcel': false,
          'crate_item_assets': {
            'id': 'asset-1',
            'display_name': '코스믹 칼리버 - Kar98k',
            'rarity': 'LEGENDARY',
            'image_url': null,
          },
        },
        {
          'id': 'rel-2',
          'drop_type': 'base',
          'probability': 0.5,
          'token_count': 3,
          'is_prime_parcel': true,
          'crate_item_assets': {
            'id': 'asset-2',
            'display_name': '프라임 소포 아이템',
            'rarity': 'COMMON',
            'image_url': '',
          },
        },
      ],
    });

    expect(template, isNotNull);
    expect(template!.name, '코스믹 칼리버 - 밀수품 상자');
    expect(template.priceGcoin, 200);
    expect(template.bundlePriceGcoin, 1800);
    expect(template.items.length, 2);

    // 기본 그룹의 프라임 소포 자체도 당첨 대상이다.
    expect(template.baseItems.length, 2);
    expect(template.baseItems.first.rarity, CrateRarity.legendary);
    expect(template.baseItems.first.probability, 0.00875);

    // 빈 문자열 이미지는 null로 정리한다.
    final prime = template.items.firstWhere((i) => i.isPrimeParcel);
    expect(prime.imageUrl, isNull);
    expect(prime.tokenCount, 3);
  });

  test('확률이 0이거나 이름이 없는 항목은 버린다', () {
    final template = CrateTemplate.tryParse({
      'id': 'tpl-2',
      'name': '테스트 상자',
      'crate_item_relations': [
        {
          'drop_type': 'base',
          'probability': 0,
          'crate_item_assets': {'display_name': '확률 없음', 'rarity': 'RARE'},
        },
        {
          'drop_type': 'base',
          'probability': 0.3,
          'crate_item_assets': {'display_name': '  ', 'rarity': 'RARE'},
        },
        {
          'drop_type': 'base',
          'probability': 0.7,
          'crate_item_assets': {'display_name': '정상', 'rarity': 'RARE'},
        },
      ],
    });

    expect(template!.items.length, 1);
    expect(template.items.first.name, '정상');
  });

  test('기본·프라임·보너스를 분리하고 알 수 없는 그룹은 추첨하지 않는다', () {
    final template = CrateTemplate.tryParse({
      'name': '그룹 상자',
      'crate_item_relations': [
        for (final group in ['base', 'prime', 'bonus', 'unknown'])
          {
            'id': group,
            'drop_type': group,
            'probability': 1,
            'is_prime_parcel': group == 'base',
            'crate_item_assets': {'display_name': group, 'rarity': 'COMMON'},
          },
      ],
    })!;
    expect(template.baseItems.single.id, 'base');
    expect(template.baseItems.single.isPrimeParcel, isTrue);
    expect(template.primeItems.single.id, 'prime');
    expect(template.bonusItems.single.id, 'bonus');
    expect(template.items, hasLength(3));
    final results = CrateDrawMachine().draw(template.baseItems, count: 10);
    expect(results.every((result) => result.item.id == 'base'), isTrue);
  });

  test('아이템이 하나도 없으면 템플릿을 만들지 않는다', () {
    expect(
      CrateTemplate.tryParse({
        'id': 'tpl-3',
        'name': '빈 상자',
        'crate_item_relations': <Object>[],
      }),
      isNull,
    );
    expect(CrateTemplate.tryParse({'id': 'tpl-4', 'name': ''}), isNull);
  });
}
