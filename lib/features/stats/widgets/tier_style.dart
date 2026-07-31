import 'package:flutter/material.dart';

import '../../../core/theme/bgms_theme.dart';

/// 티어 색상. 화면마다 색이 갈리지 않도록 공용 토큰으로 위임한다.
Color getStatsTierColor(String tierName) {
  if (tierName.isEmpty || tierName == '일반전') return BgmsColors.accent;
  final color = BgmsColors.tierColor(tierName);
  return color == BgmsColors.textMuted ? BgmsColors.accent : color;
}

/// 티어 등급대별 아이콘.
IconData getStatsTierIcon(String tierName) {
  if (tierName.contains('Bronze') || tierName.contains('Silver')) {
    return Icons.shield;
  }
  if (tierName.contains('Gold')) return Icons.emoji_events;
  if (tierName.contains('Platinum') ||
      tierName.contains('Diamond') ||
      tierName.contains('Crystal')) {
    return Icons.diamond;
  }
  if (tierName.contains('Master') || tierName.contains('Survivor')) {
    return Icons.military_tech;
  }
  return Icons.stars;
}
