import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/bgms_theme.dart';

class RadarChartWidget extends StatefulWidget {
  const RadarChartWidget({
    super.key,
    required this.combat,
    required this.tactical,
    required this.survival,
    required this.teamwork,
    required this.grit,
  });

  final double combat;
  final double tactical;
  final double survival;
  final double teamwork;
  final double grit;

  @override
  State<RadarChartWidget> createState() => _RadarChartWidgetState();
}

class _RadarChartWidgetState extends State<RadarChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  late double _combat;
  late double _tactical;
  late double _survival;
  late double _teamwork;
  late double _grit;

  @override
  void initState() {
    super.initState();
    _combat = widget.combat;
    _tactical = widget.tactical;
    _survival = widget.survival;
    _teamwork = widget.teamwork;
    _grit = widget.grit;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant RadarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.combat != widget.combat ||
        oldWidget.tactical != widget.tactical ||
        oldWidget.survival != widget.survival ||
        oldWidget.teamwork != widget.teamwork ||
        oldWidget.grit != widget.grit) {
      setState(() {
        _combat = widget.combat;
        _tactical = widget.tactical;
        _survival = widget.survival;
        _teamwork = widget.teamwork;
        _grit = widget.grit;
      });
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _RadarChartPainter(
            combat: _combat * _animation.value,
            tactical: _tactical * _animation.value,
            survival: _survival * _animation.value,
            teamwork: _teamwork * _animation.value,
            grit: _grit * _animation.value,
          ),
        );
      },
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  _RadarChartPainter({
    required this.combat,
    required this.tactical,
    required this.survival,
    required this.teamwork,
    required this.grit,
  });

  final double combat;
  final double tactical;
  final double survival;
  final double teamwork;
  final double grit;

  static const List<String> labels = ['전투', '전술', '생존', '팀워크', '끈기'];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    // 레이블 공간을 확보하기 위해 반지름에서 패딩을 뺍니다.
    final radius = (min(size.width, size.height) / 2) - 36.0;
    if (radius <= 0) return;

    final stats = [combat, tactical, survival, teamwork, grit];
    const double angleStep = 2 * pi / 5;

    // 1. 다중 배경 격자(5개 수준) 그리기
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final gridLevels = [0.2, 0.4, 0.6, 0.8, 1.0];
    for (final level in gridLevels) {
      final path = Path();
      for (int i = 0; i < 5; i++) {
        final angle = -pi / 2 + i * angleStep;
        final x = center.dx + radius * level * cos(angle);
        final y = center.dy + radius * level * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 2. 중심에서 꼭짓점으로 이어지는 축선 그리기
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * angleStep;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // 3. 채워진 다각형 스탯 영역 그리기 (반투명 그라데이션 및 외곽선 강조)
    final fillPath = Path();
    bool hasValidData = false;
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * angleStep;
      final ratio = (stats[i].clamp(0.0, 100.0)) / 100.0;
      final x = center.dx + radius * ratio * cos(angle);
      final y = center.dy + radius * ratio * sin(angle);
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
      if (ratio > 0) hasValidData = true;
    }
    fillPath.close();

    if (hasValidData) {
      // 반투명 방사형 그라데이션 컬러링
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            BgmsColors.accent.withValues(alpha: 0.15),
            BgmsColors.accent.withValues(alpha: 0.45),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawPath(fillPath, fillPaint);

      // 외곽선 강조
      final borderPaint = Paint()
        ..color = BgmsColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(fillPath, borderPaint);

      // 각 스탯 꼭짓점에 작은 마커 점 그리기
      final pointPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final pointOutlinePaint = Paint()
        ..color = BgmsColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (int i = 0; i < 5; i++) {
        final angle = -pi / 2 + i * angleStep;
        final ratio = (stats[i].clamp(0.0, 100.0)) / 100.0;
        final x = center.dx + radius * ratio * cos(angle);
        final y = center.dy + radius * ratio * sin(angle);
        canvas.drawCircle(Offset(x, y), 3.5, pointPaint);
        canvas.drawCircle(Offset(x, y), 3.5, pointOutlinePaint);
      }
    }

    // 4. 축별 레이블(Label) 표시
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * angleStep;
      final labelRadius = radius + 14.0;
      final x = center.dx + labelRadius * cos(angle);
      final y = center.dy + labelRadius * sin(angle);

      final textSpan = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: BgmsColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final double cosVal = cos(angle);
      final double sinVal = sin(angle);

      double dx = x;
      double dy = y;

      // X축 보정
      if (cosVal.abs() < 0.15) {
        dx = x - textPainter.width / 2;
      } else if (cosVal > 0) {
        dx = x;
      } else {
        dx = x - textPainter.width;
      }

      // Y축 보정
      if (sinVal.abs() < 0.15) {
        dy = y - textPainter.height / 2;
      } else if (sinVal > 0) {
        dy = y;
      } else {
        dy = y - textPainter.height;
      }

      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.combat != combat ||
        oldDelegate.tactical != tactical ||
        oldDelegate.survival != survival ||
        oldDelegate.teamwork != teamwork ||
        oldDelegate.grit != grit;
  }
}
