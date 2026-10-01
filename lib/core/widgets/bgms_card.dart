import 'package:flutter/material.dart';
import '../theme/bgms_theme.dart';

/// 앱 전반의 통일된 깊이감(Depth)과 테두리 효과를 제공하는 카드 컴포넌트.
class BgmsCard extends StatelessWidget {
  const BgmsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BgmsSpacing.lg),
    this.margin,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.borderColor,
    this.statusColor,
    this.isGlow = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? statusColor;
  final bool isGlow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? BgmsColors.surface;
    final effectiveBorder =
        borderColor ??
        (isGlow ? BgmsColors.accent.withValues(alpha: 0.5) : BgmsColors.border);

    Widget content = Padding(padding: padding, child: child);

    if (statusColor != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: statusColor),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    final boxDecoration = BoxDecoration(
      color: effectiveBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: effectiveBorder, width: 1.0),
      boxShadow: isGlow
          ? [
              BoxShadow(
                color: BgmsColors.accent.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ]
          : null,
    );

    Widget cardWidget = Container(
      margin: margin,
      decoration: boxDecoration,
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(borderRadius),
                onTap: onTap,
                child: content,
              ),
            )
          : content,
    );

    return cardWidget;
  }
}
