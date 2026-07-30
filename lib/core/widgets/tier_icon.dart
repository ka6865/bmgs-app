import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/bgms_theme.dart';

/// 웹과 동일한 랭크 티어 아이콘을 서버에서 내려받아 표시한다.
///
/// 네트워크 실패 시 방패 아이콘으로 대체해 레이아웃이 흔들리지 않게 한다.
class TierIcon extends StatelessWidget {
  const TierIcon({
    super.key,
    required this.tier,
    this.subTier,
    this.size = 48,
  });

  final String? tier;
  final String? subTier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.local.tierIconUrl(tier, subTier);
    final color = BgmsColors.tierColor(tier);

    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        label: '${tier ?? '랭크 없음'} 티어 아이콘',
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.shield_outlined, size: size * 0.8, color: color),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Icon(
              Icons.shield_outlined,
              size: size * 0.8,
              color: BgmsColors.textMuted,
            );
          },
        ),
      ),
    );
  }
}
