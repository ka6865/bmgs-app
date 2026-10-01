import 'package:flutter/material.dart';
import '../theme/bgms_theme.dart';

/// 최근 매치(최대 20전)의 순위 흐름을 한눈에 보여주는 미니 스파크라인 바 차트.
class BgmsSparklineBar extends StatelessWidget {
  const BgmsSparklineBar({super.key, required this.ranks, this.height = 36.0});

  /// 최근 경기 순위 목록 (왼쪽이 과거 또는 오른쪽이 최근 등 일관되게 전달).
  final List<int?> ranks;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (ranks.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '최근 경기 기록 없음',
            style: TextStyle(
              color: BgmsColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // 최대 20개까지만 표시
    final displayRanks = ranks.take(20).toList();

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < displayRanks.length; i++) ...[
            Expanded(child: _buildBar(displayRanks[i])),
            if (i < displayRanks.length - 1) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }

  Widget _buildBar(int? rank) {
    Color barColor;
    double barFraction;

    if (rank == null) {
      barColor = BgmsColors.defeat.withValues(alpha: 0.3);
      barFraction = 0.2;
    } else if (rank == 1) {
      barColor = BgmsColors.accent;
      barFraction = 1.0;
    } else if (rank <= 10) {
      barColor = BgmsColors.top10;
      barFraction = 0.7;
    } else {
      barColor = BgmsColors.defeat;
      // 11위부터 100위까지의 높이 점진적 감소 (0.55 -> 0.25)
      final normalized = ((rank - 10) / 90.0).clamp(0.0, 1.0);
      barFraction = 0.55 - (normalized * 0.3);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final barHeight = (constraints.maxHeight * barFraction).clamp(
          4.0,
          constraints.maxHeight,
        );
        return Tooltip(
          message: rank != null ? (rank == 1 ? '1위 (치킨)' : '$rank위') : '기록 없음',
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: rank == 1
                  ? [
                      BoxShadow(
                        color: BgmsColors.accent.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}
