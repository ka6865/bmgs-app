import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/bgms_theme.dart';

/// 하루치 채용률 점. 패치 당일은 적용 전·후 두 점으로 나뉜다.
typedef MetaTrendPoint = ({String label, double share, int sample});

/// 선 하나(카테고리 또는 총기).
typedef MetaTrendLine = ({String name, List<MetaTrendPoint> points});

/// 웹 WeaponMetaDashboard와 같은 규칙으로 `dailyWeaponTrend`를 선으로 묶는다.
///
/// 카테고리 전체([category] null)면 카테고리마다 선을 하나씩, 카테고리를 고르면
/// 그 카테고리 선 하나, [weapon]을 고르면 그 총기 선 하나를 만든다.
List<MetaTrendLine> metaTrendLines(
  Map<String, dynamic> data, {
  String? category,
  String? weapon,
}) {
  final raw = data['dailyWeaponTrend'];
  if (raw is! List) return const [];
  final patchDay = _seoulDate(data['patchStartedAt']?.toString());
  final rows = raw.whereType<Map>().where((row) {
    if (weapon != null) {
      return row['scope'] == 'weapon' && row['weapon_name'] == weapon;
    }
    if (row['scope'] != 'category') return false;
    final rowCategory = row['weapon_category']?.toString();
    return category == null ? rowCategory != 'ALL' : rowCategory == category;
  });

  final lines = <String, List<MetaTrendPoint>>{};
  for (final row in rows) {
    final date = row['date']?.toString() ?? '';
    final picks = row['weapon_pick_count'];
    final sample = row['player_match_count'];
    if (date.length < 10 || picks is! num || sample is! num || sample <= 0) {
      continue;
    }
    final period = row['period'];
    final label =
        '${date.substring(5).replaceAll('-', '/')}'
        '${date == patchDay && period != null ? (period == 'pre' ? ' 전' : ' 후') : ''}';
    final name = weapon ?? row['weapon_category']?.toString() ?? '-';
    lines.putIfAbsent(name, () => []).add((
      label: label,
      share: picks / sample * 100,
      sample: sample.toInt(),
    ));
  }
  return [
    for (final entry in lines.entries) (name: entry.key, points: entry.value),
  ];
}

/// 패치 시작 시각을 한국 날짜(yyyy-MM-dd)로 바꾼다. 웹도 Asia/Seoul 기준이다.
String? _seoulDate(String? iso) {
  final time = DateTime.tryParse(iso ?? '');
  if (time == null) return null;
  final seoul = time.toUtc().add(const Duration(hours: 9));
  return '${seoul.year}-${seoul.month.toString().padLeft(2, '0')}-'
      '${seoul.day.toString().padLeft(2, '0')}';
}

const _lineColors = [
  BgmsColors.accent,
  Color(0xFF57C785),
  Color(0xFF3B82F6),
  Color(0xFFE5484D),
  Color(0xFFB07CFF),
  Color(0xFF2DD4BF),
  Color(0xFFF08A24),
];

class MetaTrendChart extends StatelessWidget {
  const MetaTrendChart({super.key, required this.lines});

  final List<MetaTrendLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Text(
        '선택한 조건의 일별 채용률 기록이 없습니다.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: BgmsColors.textMuted),
      );
    }
    // 선마다 날짜가 다를 수 있어 모든 라벨을 시간순(입력순) 하나의 축으로 모은다.
    final labels = <String>[];
    for (final line in lines) {
      for (final point in line.points) {
        if (!labels.contains(point.label)) labels.add(point.label);
      }
    }
    final maxShare = lines
        .expand((line) => line.points)
        .fold<double>(0, (max, point) => point.share > max ? point.share : max);
    final maxY = ((maxShare / 10).ceil() * 10).clamp(10, 100).toDouble();
    final labelStep = (labels.length / 4).ceil().clamp(1, labels.length);
    final muted = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: BgmsColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  for (final (index, label) in labels.indexed)
                    if (label.endsWith(' 후'))
                      VerticalLine(
                        x: index.toDouble(),
                        color: const Color(0xFF818CF8),
                        dashArray: [4, 4],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: muted,
                          labelResolver: (_) => '패치',
                        ),
                      ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: maxY / 4,
                    getTitlesWidget: (value, _) =>
                        Text('${value.toStringAsFixed(0)}%', style: muted),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 22,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 ||
                          index >= labels.length ||
                          index % labelStep != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[index].split(' ').first,
                          style: muted,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => BgmsColors.elevated,
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        '${lines[spot.barIndex].name} '
                        '${spot.y.toStringAsFixed(1)}%\n'
                        '${labels[spot.x.toInt()]} · 표본 '
                        '${_sampleAt(lines[spot.barIndex], labels[spot.x.toInt()])}경기',
                        TextStyle(
                          color:
                              _lineColors[spot.barIndex % _lineColors.length],
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                for (final (index, line) in lines.indexed)
                  LineChartBarData(
                    spots: [
                      for (final point in line.points)
                        FlSpot(
                          labels.indexOf(point.label).toDouble(),
                          point.share,
                        ),
                    ],
                    color: _lineColors[index % _lineColors.length],
                    barWidth: 2,
                    dotData: FlDotData(show: line.points.length <= 20),
                  ),
              ],
            ),
          ),
        ),
        if (lines.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (index, line) in lines.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 3,
                      color: _lineColors[index % _lineColors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      line.name,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  static int _sampleAt(MetaTrendLine line, String label) =>
      line.points.where((point) => point.label == label).firstOrNull?.sample ??
      0;
}
