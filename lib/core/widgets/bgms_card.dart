import 'package:flutter/material.dart';
import '../theme/bgms_theme.dart';

/// 사선 커팅 모서리의 기본 패널. 상태는 테두리 색으로만 표시한다.
class BgmsCard extends StatelessWidget {
  const BgmsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BgmsSpacing.lg),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.statusColor,
    this.isGlow = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? statusColor;

  /// 치킨처럼 강조할 카드. 골드 테두리로 표시한다.
  final bool isGlow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(
      color:
          borderColor ??
          (isGlow
              ? BgmsColors.accent
              : statusColor?.withValues(alpha: 0.55) ?? BgmsColors.border),
    );
    final shape = BgmsShape.panel(side: side);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: backgroundColor ?? BgmsColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                customBorder: shape,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}
