import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/bgms_theme.dart';
import '../crate_draw.dart';
import '../crate_models.dart';
import '../crate_rarity_style.dart';

/// 뽑기 결과 카드. 탭하거나 자동으로 뒤집혀 내용을 공개한다.
///
/// 상위 등급은 뒤집힌 뒤 발광 테두리가 맥동해 즉시 눈에 들어온다.
class CrateRevealCard extends StatefulWidget {
  const CrateRevealCard({
    super.key,
    required this.result,
    required this.revealDelay,
  });

  final CrateDrawResult result;

  /// 연속 뽑기에서 카드가 차례로 열리도록 주는 지연.
  final Duration revealDelay;

  @override
  State<CrateRevealCard> createState() => _CrateRevealCardState();
}

class _CrateRevealCardState extends State<CrateRevealCard>
    with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  void _scheduleReveal() {
    Future<void>.delayed(widget.revealDelay, () {
      if (!mounted) return;
      _reveal();
    });
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _flip.forward();
    if (widget.result.item.rarity.isHighlight) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.result.item;
    final color = crateRarityColor(item.rarity);

    return GestureDetector(
      // 기다리기 싫은 사용자는 눌러서 바로 열 수 있다.
      onTap: _reveal,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flip, _glow]),
        builder: (context, child) {
          final value = _flip.value;
          final angle = value * math.pi;
          final showFront = value >= 0.5;
          final glow = item.rarity.isHighlight ? _glow.value : 0.0;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showFront
                // 뒤집힌 뒤에는 앞면이 거울상이 되므로 한 번 더 회전시킨다.
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardFront(
                      item: item,
                      isDuplicate: widget.result.isDuplicate,
                      color: color,
                      glow: glow,
                    ),
                  )
                : const _CardBack(),
          );
        },
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BgmsColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BgmsColors.border),
      ),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 28,
          color: BgmsColors.textMuted,
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.item,
    required this.isDuplicate,
    required this.color,
    required this.glow,
  });

  final CrateItem item;
  final bool isDuplicate;
  final Color color;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: crateRarityGradient(item.rarity),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: item.rarity.isHighlight ? 0.9 : 0.4),
          width: item.rarity.isHighlight ? 1.6 : 1,
        ),
        boxShadow: item.rarity.isHighlight
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25 + glow * 0.35),
                  blurRadius: 12 + glow * 14,
                  spreadRadius: glow * 2,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(crateRarityIcon(item.rarity), size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.rarity.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (isDuplicate && item.tokenCount > 0)
                  Text(
                    '+${item.tokenCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: BgmsColors.textMuted,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              item.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
