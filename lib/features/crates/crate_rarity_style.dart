import 'package:flutter/material.dart';

import 'crate_models.dart';

/// 등급별 연출 색상.
///
/// 상위 등급은 채도를 높여 카드가 열릴 때 시선이 즉시 가도록 한다.
Color crateRarityColor(CrateRarity rarity) => switch (rarity) {
  CrateRarity.ultimate => const Color(0xFFFF4D6D),
  CrateRarity.legendary => const Color(0xFFFFC53D),
  CrateRarity.epic => const Color(0xFFB37FEB),
  CrateRarity.elite => const Color(0xFF4DA6FF),
  CrateRarity.rare => const Color(0xFF36CFC9),
  CrateRarity.special => const Color(0xFF95DE64),
  CrateRarity.common => const Color(0xFF8C8C8C),
};

/// 카드 배경 그라디언트. 등급 색을 어두운 배경에 얹는다.
LinearGradient crateRarityGradient(CrateRarity rarity) {
  final color = crateRarityColor(rarity);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      color.withValues(alpha: rarity.isHighlight ? 0.34 : 0.18),
      const Color(0xFF161616),
    ],
  );
}

/// 등급별 아이콘. 텍스트 없이도 등급이 읽히게 한다.
IconData crateRarityIcon(CrateRarity rarity) => switch (rarity) {
  CrateRarity.ultimate => Icons.local_fire_department,
  CrateRarity.legendary => Icons.auto_awesome,
  CrateRarity.epic => Icons.diamond,
  CrateRarity.elite => Icons.military_tech,
  CrateRarity.rare => Icons.star,
  CrateRarity.special => Icons.bolt,
  CrateRarity.common => Icons.inventory_2_outlined,
};
