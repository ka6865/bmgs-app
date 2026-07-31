import 'package:flutter/material.dart';

import '../theme/bgms_theme.dart';

class BgmsBrandHeader extends StatelessWidget {
  const BgmsBrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.filled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// 배경 박스를 그릴지 여부. 홈처럼 상단을 가볍게 두는 화면은 false로 쓴다.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: filled
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(vertical: 4),
      decoration: filled
          ? BoxDecoration(
              color: BgmsColors.elevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BgmsColors.border),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: BgmsColors.accent,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BgmsColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
