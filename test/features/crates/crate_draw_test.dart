import 'dart:math';

import 'package:bgms_mobile_app/features/crates/crate_draw.dart';
import 'package:bgms_mobile_app/features/crates/crate_models.dart';
import 'package:flutter_test/flutter_test.dart';

CrateItem _item(
  String id,
  double probability, {
  CrateRarity rarity = CrateRarity.common,
  int tokenCount = 0,
}) {
  return CrateItem(
    id: id,
    name: id,
    rarity: rarity,
    probability: probability,
    imageUrl: null,
    tokenCount: tokenCount,
  );
}

void main() {
  test('확률이 높은 아이템이 더 자주 나온다', () {
    // 시드를 고정해 결과를 재현 가능하게 만든다.
    final machine = CrateDrawMachine(random: Random(42));
    final pool = [
      _item('common', 0.9),
      _item('rare', 0.09, rarity: CrateRarity.rare),
      _item('legend', 0.01, rarity: CrateRarity.legendary),
    ];

    final results = machine.draw(pool, count: 10000);
    final counts = <String, int>{};
    for (final r in results) {
      counts.update(r.item.id, (v) => v + 1, ifAbsent: () => 1);
    }

    // 90% 아이템은 8500~9500 사이에 들어와야 한다.
    expect(counts['common']!, greaterThan(8500));
    expect(counts['common']!, lessThan(9500));
    // 1% 아이템은 나오긴 하지만 드물다.
    expect(counts['legend']!, greaterThan(30));
    expect(counts['legend']!, lessThan(200));
  });

  test('확률 합이 1이 아니어도 비율대로 분배한다', () {
    final machine = CrateDrawMachine(random: Random(7));
    // 합이 0.5뿐인 풀. 비율은 4:1이다.
    final pool = [_item('a', 0.4), _item('b', 0.1)];

    final results = machine.draw(pool, count: 5000);
    final aCount = results.where((r) => r.item.id == 'a').length;

    // 4:1 비율이면 약 4000회다.
    expect(aCount, greaterThan(3700));
    expect(aCount, lessThan(4300));
  });

  test('같은 회차 안의 중복을 표시한다', () {
    final machine = CrateDrawMachine(random: Random(1));
    final pool = [_item('only', 1.0, tokenCount: 5)];

    final results = machine.draw(pool, count: 3);

    expect(results.first.isDuplicate, isFalse);
    expect(results[1].isDuplicate, isTrue);
    expect(results[2].isDuplicate, isTrue);
  });

  test('빈 풀은 예외를 던진다', () {
    final machine = CrateDrawMachine(random: Random(1));
    expect(() => machine.drawOne(const []), throwsArgumentError);
  });

  test('확률이 모두 0이면 균등 추첨으로 대체한다', () {
    final machine = CrateDrawMachine(random: Random(3));
    final pool = [_item('a', 0), _item('b', 0)];

    // 예외 없이 뽑히고 풀 안의 아이템이 나온다.
    final item = machine.drawOne(pool);
    expect(['a', 'b'], contains(item.id));
  });

  test('count가 0 이하면 빈 결과를 준다', () {
    final machine = CrateDrawMachine(random: Random(1));
    final pool = [_item('a', 1.0)];

    expect(machine.draw(pool, count: 0), isEmpty);
    expect(machine.draw(pool, count: -5), isEmpty);
  });

  group('CrateSessionStats', () {
    test('뽑기 결과를 누적한다', () {
      const stats = CrateSessionStats();
      final results = [
        CrateDrawResult(
          item: _item('a', 1, rarity: CrateRarity.legendary),
          isDuplicate: false,
        ),
        CrateDrawResult(
          item: _item('a', 1, rarity: CrateRarity.legendary, tokenCount: 10),
          isDuplicate: true,
        ),
      ];

      final next = stats.apply(results, cost: 1800);

      expect(next.drawCount, 2);
      expect(next.spentGcoin, 1800);
      // 중복분만 토큰으로 환산한다.
      expect(next.tokens, 10);
      expect(next.countOf(CrateRarity.legendary), 2);
      expect(next.highlightCount, 2);
    });

    test('여러 회차를 이어서 누적한다', () {
      final first = const CrateSessionStats().apply([
        CrateDrawResult(item: _item('a', 1), isDuplicate: false),
      ], cost: 200);
      final second = first.apply([
        CrateDrawResult(item: _item('b', 1), isDuplicate: false),
      ], cost: 200);

      expect(second.drawCount, 2);
      expect(second.spentGcoin, 400);
    });
  });
}
