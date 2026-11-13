import 'package:flutter/material.dart';

import '../theme/bgms_theme.dart';

/// 한 경기를 자기장 페이즈 칸으로 그린다. 사망 페이즈까지 채우고 치킨은 전부 골드.
///
/// shortcut: 맵별 실제 페이즈 수 대신 9칸 고정, 서버가 맵별 페이즈 수를 주면 그 값으로 바꾼다.
class PhaseStrip extends StatelessWidget {
  const PhaseStrip({
    super.key,
    required this.deathPhase,
    required this.rank,
    this.height = 6,
  });

  static const phaseCount = 9;

  final int? deathPhase;
  final int? rank;
  final double height;

  bool get _isChicken => rank == 1;

  Color get _fill {
    if (_isChicken) return BgmsColors.accent;
    if (rank != null && rank! <= 10) return BgmsColors.top10;
    return BgmsColors.defeat;
  }

  int get _filled {
    if (_isChicken) return phaseCount;
    final phase = deathPhase;
    if (phase == null) return 0;
    return phase.clamp(0, phaseCount);
  }

  String get _label {
    if (_isChicken) return '치킨, 마지막 페이즈까지 생존';
    final phase = deathPhase;
    if (phase == null) return '페이즈 정보 없음';
    if (phase == 0) return '첫 자기장 전에 탈락';
    return '자기장 $phase페이즈에서 탈락';
  }

  @override
  Widget build(BuildContext context) {
    final filled = _filled;
    final unknown = !_isChicken && deathPhase == null;

    return Semantics(
      label: _label,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < phaseCount; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i < filled
                        ? _fill
                        : unknown
                        ? Colors.transparent
                        : BgmsColors.elevated,
                    border: unknown
                        ? Border.all(color: BgmsColors.border)
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
