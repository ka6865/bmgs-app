import 'package:flutter/material.dart';
import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/bgms_card.dart';

/// 홈 화면에서 전술 지도로 이동하는 배너.
class HomeLiveBanner extends StatelessWidget {
  const HomeLiveBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BgmsCard(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: BgmsColors.elevated,
      borderColor: BgmsColors.accent.withValues(alpha: 0.3),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BgmsColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.map_outlined,
              color: BgmsColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '전술 지도',
                  style: TextStyle(
                    color: BgmsColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '맵별 차량과 주요 지점 위치 확인하기',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BgmsColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: BgmsColors.textMuted,
          ),
        ],
      ),
    );
  }
}
