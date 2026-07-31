import 'package:flutter/material.dart';

import '../theme/bgms_theme.dart';

/// 화면 제목 헤더.
///
/// 브랜드 로고 서체는 홈에서만 쓴다. 나머지 화면은 하단 탭에 이미 이름이 있으므로
/// 제목을 일반 서체로 낮춰 같은 이름이 두 번 강조되지 않게 한다.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;

  /// 화면 상태를 알려주는 짧은 보조 문구. 기능 사용법 설명에는 쓰지 않는다.
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final trailing = this.trailing;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BgmsColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }
}

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
