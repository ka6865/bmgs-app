import 'package:flutter/material.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'match_detail_models.dart';
import 'match_detail_repository.dart';
import 'player_stats_models.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.nickname,
    required this.platform,
    required this.summary,
  });

  final String matchId;
  final String nickname;
  final String platform;
  final MatchSummary summary;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  late final MatchDetailRepository _repository;
  late Future<MatchDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _repository = MatchDetailRepository();
    _detailFuture = _loadDetail();
  }

  @override
  void didUpdateWidget(covariant MatchDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId ||
        oldWidget.nickname != widget.nickname ||
        oldWidget.platform != widget.platform) {
      _detailFuture = _loadDetail();
    }
  }

  Future<MatchDetail> _loadDetail() {
    return _repository.fetchMatchDetail(
      summary: widget.summary,
      nickname: widget.nickname,
      platform: widget.platform,
    );
  }

  void _retry() {
    setState(() => _detailFuture = _loadDetail());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchDetail>(
      future: _detailFuture,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0b0f19),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          backgroundColor: const Color(0xFF0b0f19),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              BgmsBrandHeader(
                title: '매치 분석 리포트',
                subtitle: detail == null
                    ? widget.matchId
                    : '${detail.mapName} · ${detail.gameMode}',
                trailing: IconButton(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, color: BgmsColors.accent),
                  tooltip: '새로고침',
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  detail == null)
                const _LoadingCard()
              else
                _DetailContent(
                  detail:
                      detail ??
                      MatchDetail.fromSummary(
                        widget.summary,
                        nickname: widget.nickname,
                      ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.detail});

  final MatchDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 프로필 카드 & 매치 메타
        _MetadataCard(detail: detail),
        const SizedBox(height: 12),

        // 2. 기본 지표 격자 (순위, 킬, 데미지 등)
        _MetricGrid(detail: detail),
        const SizedBox(height: 12),

        // 3. [고도화] 벤치마크 점수 카드 (웹의 Benchmark Breakdown 이식)
        if (!detail.isFallback) ...[
          _BenchmarkScoreCard(benchmark: detail.benchmark),
          const SizedBox(height: 12),
        ],

        // 4. [고도화] 교전 포지셔닝 & 고립 지수 분석 카드
        if (!detail.isFallback) ...[
          _TacticalPositioningCard(isolation: detail.isolationData),
          const SizedBox(height: 12),
        ],

        // 5. [고도화] 팀 백업 및 유틸리티 레이턴시 카드
        if (!detail.isFallback) ...[
          _TeamBackupCard(trade: detail.tradeStats),
          const SizedBox(height: 12),
        ],

        // 6. [고도화] 차량 및 교전 압박 특수 지표 카드
        if (!detail.isFallback && _hasSpecialStats(detail)) ...[
          _SpecialCombatCard(
            vehicle: detail.vehicleCombat,
            pressure: detail.combatPressure,
            duel: detail.duelStats,
          ),
          const SizedBox(height: 12),
        ],


      ],
    );
  }

  bool _hasSpecialStats(MatchDetail detail) {
    final v = detail.vehicleCombat;
    final totalVehicle = v.leadShotKills + v.leadShotKnocks + v.ridingShotKills + v.ridingShotKnocks + v.roadKills + v.roadKnocks;
    return totalVehicle > 0 || detail.combatPressure.pressureIndex > 0 || detail.duelStats.reversalAttempts > 0;
  }


}

// ---------------------------------------------------------------------------
// 1. 매치 메타데이터 정보 카드
// ---------------------------------------------------------------------------
class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.detail});

  final MatchDetail detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: BgmsColors.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: detail.isFallback ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: detail.isFallback ? Colors.amber : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    detail.isFallback ? '대기 중' : '분석 완료',
                    style: TextStyle(
                      color: detail.isFallback ? Colors.amber : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${detail.mapName} · ${detail.gameMode}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              '매치 ID: ${detail.matchId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BgmsColors.textMuted,
              ),
            ),
            if (detail.message != null) ...[
              const SizedBox(height: 12),
              Text(
                detail.message!,
                style: const TextStyle(color: BgmsColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 기본 지표 격자 뷰
// ---------------------------------------------------------------------------
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.detail});

  final MatchDetail detail;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _DetailMetric('순위', detail.rank == null ? '-' : '#${detail.rank}'),
      _DetailMetric('개인 킬', '${detail.kills}'),
      _DetailMetric('가한 피해량', detail.damage.toStringAsFixed(0)),
      _DetailMetric('생존 시간', detail.survivalText),
      _DetailMetric('스쿼드 총 킬', detail.teamKills > 0 ? '${detail.teamKills}' : '-'),
      _DetailMetric('맵 코드', detail.mapId ?? detail.mapName),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: narrow ? 2 : 3,
            childAspectRatio: narrow ? 1.8 : 1.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Card(
              color: const Color(0xFF161b26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF232b3c)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      child: Text(
                        metric.value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: index == 0
                              ? BgmsColors.accent
                              : BgmsColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: BgmsColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. 벤치마크 점수 카드 (Breakdown)
// ---------------------------------------------------------------------------
class _BenchmarkScoreCard extends StatelessWidget {
  const _BenchmarkScoreCard({required this.benchmark});

  final BenchmarkBreakdown benchmark;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '상위권 벤치마크 점수',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                ),
                Text(
                  '${benchmark.tier} 등급',
                  style: const TextStyle(color: BgmsColors.accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BenchmarkMetricIndicator(
                    label: '교전 능력',
                    score: benchmark.combat,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BenchmarkMetricIndicator(
                    label: '전술 운영',
                    score: benchmark.tactical,
                    color: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BenchmarkMetricIndicator(
                    label: '생존 관리',
                    score: benchmark.survival,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('전술 매치 종합 점수', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        benchmark.score.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: BgmsColors.accent),
                      ),
                      const Text(' / 100 점', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      if (benchmark.impactGrade != null) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.purpleAccent, width: 0.5),
                          ),
                          child: Text(
                            benchmark.impactGrade!,
                            style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (benchmark.impactReasons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: benchmark.impactReasons.map((reason) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          reason,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenchmarkMetricIndicator extends StatelessWidget {
  const _BenchmarkMetricIndicator({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: score / 100,
          backgroundColor: Colors.white10,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 4),
        Text(
          '${score.toStringAsFixed(1)}점',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. 교전 포지셔닝 & 고립 지수 분석 카드
// ---------------------------------------------------------------------------
class _TacticalPositioningCard extends StatelessWidget {
  const _TacticalPositioningCard({required this.isolation});

  final IsolationData isolation;

  @override
  Widget build(BuildContext context) {
    final bool isHighlyIsolated = isolation.isolationIndex >= 3.5;

    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '교전 포지셔닝 및 고립 지수',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniDataBox(
                    label: '고립 지수 (Isolation)',
                    value: isolation.isolationIndex.toStringAsFixed(2),
                    valueColor: isHighlyIsolated ? Colors.redAccent : BgmsColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniDataBox(
                    label: '교전 시 고립도',
                    value: isolation.combatIsolation.toStringAsFixed(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniDataBox(
                    label: '가장 가까운 팀원 거리',
                    value: '${isolation.minDist.toStringAsFixed(1)}m',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniDataBox(
                    label: '교차 피격(포위) 여부',
                    value: isolation.isCrossfire ? '피격 노출' : '안전',
                    valueColor: isolation.isCrossfire ? Colors.redAccent : Colors.greenAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isHighlyIsolated ? Colors.redAccent.withValues(alpha: 0.05) : Colors.greenAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHighlyIsolated ? Colors.redAccent.withValues(alpha: 0.2) : Colors.greenAccent.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isHighlyIsolated ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: isHighlyIsolated ? Colors.redAccent : Colors.greenAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isHighlyIsolated
                          ? '교전 중 대열을 이탈해 혼자 고립되는 경향이 발견되었습니다. 팀원과의 거리를 유지해 백업을 확보하세요.'
                          : '팀과의 안정적인 대열 유지를 유지하며 안전하게 교전을 진행했습니다.',
                      style: TextStyle(
                        color: isHighlyIsolated ? Colors.redAccent : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. 팀 백업 및 소생 지표 카드
// ---------------------------------------------------------------------------
class _TeamBackupCard extends StatelessWidget {
  const _TeamBackupCard({required this.trade});

  final TradeStats trade;

  @override
  Widget build(BuildContext context) {
    final hasTradeLatency = trade.tradeLatencyMs > 0;
    final double backupSec = trade.tradeLatencyMs / 1000;

    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '팀 백업 및 소생 기여도',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniDataBox(
                    label: '평균 백업 시간 (초)',
                    value: hasTradeLatency ? '${backupSec.toStringAsFixed(2)}초' : 'N/A',
                    valueColor: hasTradeLatency
                        ? (backupSec < 10.0 ? Colors.greenAccent : Colors.amberAccent)
                        : Colors.white30,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniDataBox(
                    label: '엄폐율 (Cover Rate)',
                    value: '${trade.coverRate.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniDataBox(
                    label: '아군 복수 킬 (Trade Kills)',
                    value: '${trade.tradeKills}회',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniDataBox(
                    label: '연막 구출 소생 시도',
                    value: '${trade.smokeRescues} / ${trade.smokeCount}회',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasTradeLatency) ...[
              const Text('백업 반응 속도 평가', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (20.0 - backupSec).clamp(0.0, 20.0) / 20.0,
                backgroundColor: Colors.white10,
                color: backupSec < 8 ? Colors.greenAccent : (backupSec < 15 ? Colors.amberAccent : Colors.redAccent),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 4),
              Text(
                backupSec < 8
                    ? '⚡ 초광속 백업! 아군이 쓰러지자마자 적을 처리했습니다.'
                    : (backupSec < 15 ? '안정적인 대응 속도로 아군 교전을 지원했습니다.' : '백업 템포가 약간 느립니다. 팀원이 싸우는 위치에 더 빠르게 개입하세요.'),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. 특수 전투 지표 (차량, 압박, 1대1) 카드
// ---------------------------------------------------------------------------
class _SpecialCombatCard extends StatelessWidget {
  const _SpecialCombatCard({
    required this.vehicle,
    required this.pressure,
    required this.duel,
  });

  final VehicleCombatStats vehicle;
  final CombatPressure pressure;
  final DuelStats duel;

  @override
  Widget build(BuildContext context) {
    final hasVehicleStats = (vehicle.leadShotKills + vehicle.leadShotKnocks + vehicle.ridingShotKills + vehicle.ridingShotKnocks + vehicle.roadKills + vehicle.roadKnocks) > 0;

    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '특수 전투 지표 및 1:1 결정력',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
            ),
            if (hasVehicleStats) ...[
              const SizedBox(height: 16),
              const Text('🚗 차량 교전 성과', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MiniDataBox(
                      label: '리드샷 (주행차 표적 사격)',
                      value: '기절 ${vehicle.leadShotKnocks} / 킬 ${vehicle.leadShotKills}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniDataBox(
                      label: '라이딩샷 (탑승 사격)',
                      value: '기절 ${vehicle.ridingShotKnocks} / 킬 ${vehicle.ridingShotKills}',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text('🔥 교전 컨트롤 및 결투 승률', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniDataBox(
                    label: '1대1 결투 승률',
                    value: '${duel.duelWinRate.toStringAsFixed(0)}%',
                    valueColor: duel.duelWinRate >= 60 ? Colors.greenAccent : (duel.duelWinRate >= 45 ? Colors.white : Colors.redAccent),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniDataBox(
                    label: '역전 승리 (Reversals)',
                    value: '${duel.reversals} / ${duel.reversalAttempts}회',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniDataBox(
                    label: '교전 위기 극복(클러치)',
                    value: pressure.isClutched ? '클러치 성공!' : '없음',
                    valueColor: pressure.isClutched ? BgmsColors.accent : Colors.white30,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniDataBox(
                    label: '최대 유효 타격 거리',
                    value: '${pressure.maxHitDistance.toStringAsFixed(1)}m',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 공통 소형 데이터 박스 위젯
// ---------------------------------------------------------------------------
class _MiniDataBox extends StatelessWidget {
  const _MiniDataBox({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFF161b26),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(color: BgmsColors.accent),
      ),
    );
  }
}

class _DetailMetric {
  const _DetailMetric(this.label, this.value);

  final String label;
  final String value;
}
