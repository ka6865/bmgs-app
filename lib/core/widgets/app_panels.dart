import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/bgms_theme.dart';

/// 배경 장식과 잉크 효과를 함께 제공하는 래퍼.
///
/// Card 중첩을 만들지 않으면서 InkWell이 요구하는 Material 조상을 보장한다.
class InkSurface extends StatelessWidget {
  const InkSurface({
    super.key,
    required this.decoration,
    required this.child,
    this.borderRadius = 8,
  });

  final BoxDecoration decoration;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// 카드로 감싸지 않는 섹션 레이아웃.
///
/// 카드 안에 카드를 두는 구조를 피하려고 소제목과 내용 밴드만 배치한다.
/// 내부에 카드형 항목이 반복되는 섹션은 [SectionCard] 대신 이 위젯을 쓴다.
class SectionBand extends StatelessWidget {
  const SectionBand({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final action = this.action;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: BgmsColors.textMuted),
              const SizedBox(width: BgmsSpacing.xs + 2),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: BgmsColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: BgmsSpacing.sm + 2),
        child,
      ],
    );
  }
}

/// 제목, 액션, 본문 구조를 가진 공통 섹션 카드.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.action,
    this.padding = BgmsSpacing.card,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final subtitle = this.subtitle;
    final leading = this.leading;
    final action = this.action;

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (leading != null) ...[
                    leading,
                    const SizedBox(width: BgmsSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: BgmsColors.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: BgmsSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// 로딩 중 표시하는 스켈레톤 블록.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = BgmsRadius.sm,
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.35 + (_controller.value * 0.35),
          child: child,
        );
      },
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: BgmsColors.elevated,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

/// 카드 형태의 로딩 스켈레톤. 로딩 중에도 레이아웃 높이를 유지한다.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, this.lines = 3, this.label});

  final int lines;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Card(
      child: Padding(
        padding: BgmsSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BgmsColors.textSecondary,
                ),
              ),
              const SizedBox(height: BgmsSpacing.md),
            ],
            for (var index = 0; index < lines; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == lines - 1 ? 0 : BgmsSpacing.sm,
                ),
                child: SkeletonBox(
                  height: index == 0 ? 22 : 14,
                  width: index == 0 ? 160 : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 정보성 빈 상태 패널.
class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Card(
      child: Padding(
        padding: BgmsSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(BgmsSpacing.sm),
                  decoration: const BoxDecoration(
                    color: BgmsColors.elevated,
                    borderRadius: BgmsRadius.md,
                  ),
                  child: Icon(icon, size: 20, color: BgmsColors.textSecondary),
                ),
                const SizedBox(width: BgmsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: BgmsSpacing.xs),
                      Text(
                        body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BgmsColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: BgmsSpacing.md),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// API 실패 상태 패널. 재시도 가능한 오류에는 다시 시도 버튼을 노출한다.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.error,
    this.onRetry,
    this.title = '데이터를 불러오지 못했습니다',
  });

  final Object error;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final apiError = ApiException.from(error);
    final onRetry = this.onRetry;

    return Card(
      child: Padding(
        padding: BgmsSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(BgmsSpacing.sm),
                  decoration: BoxDecoration(
                    color: BgmsColors.danger.withValues(alpha: 0.14),
                    borderRadius: BgmsRadius.md,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 20,
                    color: BgmsColors.danger,
                  ),
                ),
                const SizedBox(width: BgmsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: BgmsSpacing.xs),
                      Text(
                        apiError.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BgmsColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: BgmsSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 시도'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 지표 하나를 보여주는 셀. 값 길이에 따라 자동 축소한다.
class StatCell extends StatelessWidget {
  const StatCell({
    super.key,
    required this.label,
    required this.value,
    this.accentColor,
    this.suffix,
  });

  final String label;
  final String value;
  final Color? accentColor;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final suffix = this.suffix;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accentColor ?? BgmsColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    suffix,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BgmsColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: BgmsSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: BgmsColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// 라벨과 값을 한 줄로 보여준다.
class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: BgmsColors.textMuted),
        const SizedBox(width: BgmsSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
        ),
        const SizedBox(width: BgmsSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: valueColor ?? BgmsColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
