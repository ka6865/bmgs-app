import 'dart:math';

import 'crate_models.dart';

/// 상자 뽑기 결과 한 장.
class CrateDrawResult {
  const CrateDrawResult({required this.item, required this.isDuplicate});

  final CrateItem item;

  /// 같은 회차 안에서 이미 나온 아이템인지. 중복은 토큰으로 환산된다.
  final bool isDuplicate;
}

/// 확률 기반 상자 뽑기.
///
/// 네트워크와 UI에 의존하지 않는 순수 로직이다. 시드를 주입할 수 있어
/// 확률 분포를 테스트로 검증할 수 있다.
class CrateDrawMachine {
  CrateDrawMachine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 한 번 뽑는다. 확률 합이 1보다 작으면 남는 몫은 최저 등급으로 흘린다.
  CrateItem drawOne(List<CrateItem> pool) {
    if (pool.isEmpty) {
      throw ArgumentError('뽑을 아이템이 없습니다.');
    }

    final total = pool.fold<double>(0, (sum, item) => sum + item.probability);
    // 확률 합이 0이면 균등 추첨으로 대체한다.
    if (total <= 0) return pool[_random.nextInt(pool.length)];

    final roll = _random.nextDouble() * total;
    var cursor = 0.0;
    for (final item in pool) {
      cursor += item.probability;
      if (roll < cursor) return item;
    }
    return pool.last;
  }

  /// [count]회 연속 뽑기. 회차 안의 중복 여부를 함께 표시한다.
  List<CrateDrawResult> draw(List<CrateItem> pool, {int count = 1}) {
    if (count <= 0) return const [];

    final seen = <String>{};
    final results = <CrateDrawResult>[];
    for (var i = 0; i < count; i++) {
      final item = drawOne(pool);
      results.add(CrateDrawResult(item: item, isDuplicate: !seen.add(item.id)));
    }
    return results;
  }
}

/// 누적 뽑기 통계. 사용자가 얼마를 썼고 무엇을 얻었는지 보여준다.
class CrateSessionStats {
  const CrateSessionStats({
    this.drawCount = 0,
    this.spentGcoin = 0,
    this.tokens = 0,
    this.rarityCounts = const {},
  });

  final int drawCount;
  final int spentGcoin;

  /// 중복 획득으로 쌓인 토큰.
  final int tokens;
  final Map<CrateRarity, int> rarityCounts;

  /// 결과를 반영한 새 통계를 만든다.
  CrateSessionStats apply(List<CrateDrawResult> results, {required int cost}) {
    final counts = Map<CrateRarity, int>.from(rarityCounts);
    var addedTokens = 0;
    for (final result in results) {
      counts.update(
        result.item.rarity,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (result.isDuplicate) addedTokens += result.item.tokenCount;
    }

    return CrateSessionStats(
      drawCount: drawCount + results.length,
      spentGcoin: spentGcoin + cost,
      tokens: tokens + addedTokens,
      rarityCounts: counts,
    );
  }

  int countOf(CrateRarity rarity) => rarityCounts[rarity] ?? 0;

  /// 상위 등급을 얻은 총 횟수.
  int get highlightCount =>
      countOf(CrateRarity.ultimate) + countOf(CrateRarity.legendary);
}
