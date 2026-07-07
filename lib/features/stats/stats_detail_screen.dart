import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'ai_coaching_card.dart';
import 'player_stats_models.dart';
import 'player_stats_repository.dart';
import 'widgets/radar_chart_widget.dart';

class StatsDetailScreen extends StatefulWidget {
  const StatsDetailScreen({
    super.key,
    required this.nickname,
    required this.platform,
    this.repository,
  });

  final String? nickname;
  final String platform;
  final PlayerStatsRepository? repository;

  @override
  State<StatsDetailScreen> createState() => _StatsDetailScreenState();
}

class _StatsDetailScreenState extends State<StatsDetailScreen> {
  late final PlayerStatsRepository _repository;
  Future<PlayerStatsBundle>? _statsFuture;
  String? _selectedSeason;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PlayerStatsRepository();
    _startFetch();
  }

  @override
  void didUpdateWidget(covariant StatsDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nickname != widget.nickname ||
        oldWidget.platform != widget.platform) {
      _selectedSeason = null; // 닉네임이나 플랫폼이 바뀌면 시즌 필터 초기화
      _startFetch();
    }
  }

  void _startFetch({bool refresh = false}) {
    final nickname = widget.nickname?.trim() ?? '';
    if (nickname.isEmpty) {
      _statsFuture = null;
      return;
    }
    _statsFuture = _repository.fetchPlayerStats(
      nickname: nickname,
      platform: widget.platform,
      season: _selectedSeason,
      refresh: refresh,
    );
  }

  void _retry() {
    setState(() => _startFetch(refresh: true));
  }

  void _onSeasonChanged(String? newSeason) {
    if (newSeason == _selectedSeason) return;
    setState(() {
      _selectedSeason = newSeason;
      _startFetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nickname = widget.nickname?.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BgmsBrandHeader(
          title: '전적',
          subtitle: nickname.isEmpty ? '닉네임 검색 후 최근 기록을 확인합니다.' : nickname,
          trailing: nickname.isEmpty
              ? null
              : IconButton(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, color: BgmsColors.accent),
                  tooltip: '새로고침',
                ),
        ),
        const SizedBox(height: 16),
        if (nickname.isEmpty)
          const _StatePanel(
            icon: Icons.search_off,
            title: '검색할 닉네임이 없습니다',
            body: '홈에서 Steam 또는 Kakao 플랫폼을 선택하고 닉네임을 검색해 주세요.',
          )
        else
          FutureBuilder<PlayerStatsBundle>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _LoadingPanel(
                  nickname: nickname,
                  platform: widget.platform,
                );
              }
              if (snapshot.hasError) {
                return _ErrorPanel(
                  message: snapshot.error.toString(),
                  onRetry: _retry,
                );
              }
              final bundle = snapshot.data;
              if (bundle == null) {
                return const _StatePanel(
                  icon: Icons.inbox_outlined,
                  title: '전적 데이터가 없습니다',
                  body: '검색 결과를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
                );
              }
              final profile = bundle.profile;
              final currentSeasonId = _selectedSeason ?? profile.seasonId ?? '';
              return _StatsContent(
                key: ValueKey('${profile.nickname}_$currentSeasonId'),
                bundle: bundle,
                selectedSeason: _selectedSeason,
                onSeasonChanged: _onSeasonChanged,
              );
            },
          ),
      ],
    );
  }
}

class _StatsContent extends StatefulWidget {
  const _StatsContent({
    super.key,
    required this.bundle,
    required this.selectedSeason,
    required this.onSeasonChanged,
  });

  final PlayerStatsBundle bundle;
  final String? selectedSeason;
  final ValueChanged<String?> onSeasonChanged;

  @override
  State<_StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends State<_StatsContent> {
  static const double _targetCombatKD = 2.0;
  static const double _targetTacticalADR = 300.0;
  static const double _targetSurvivalSeconds = 1200.0;
  static const double _targetAvgAssists = 1.5;

  String _selectedQueue = 'ranked'; // 'ranked' | 'normal'
  String _selectedMode = 'squad'; // 'squad' | 'duo' | 'solo'

  @override
  Widget build(BuildContext context) {
    final profile = widget.bundle.profile;

    // 현재 선택된 큐/모드의 스탯 추출
    final queueStats = profile.modeStats[_selectedQueue];
    final currentStats = queueStats?[_selectedMode];
    final bool hasStats = currentStats != null && currentStats.roundsPlayed > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 프로필 헤더 & 시즌 필터 드롭다운
        _ProfileHeader(
          profile: profile,
          selectedSeason: widget.selectedSeason,
          onSeasonChanged: widget.onSeasonChanged,
        ),
        const SizedBox(height: 12),

        // 큐 선택 세그먼트 탭
        _buildQueueSegmentedControl(),
        const SizedBox(height: 8),

        // 모드 선택 슬라이딩 칩
        _buildModeChips(),
        const SizedBox(height: 16),

        // 2. 스탯 렌더링 또는 Empty State
        if (hasStats) ...[
          if (_selectedQueue == 'ranked') ...[
            _TierInfoPanel(stats: currentStats),
            const SizedBox(height: 12),
          ],
          // 레이더 차트 카드
          Card(
            color: const Color(0xFF161b26),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF232b3c)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    '성향 분석',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: RadarChartWidget(
                      combat: _calculateCombatScore(currentStats),
                      tactical: _calculateTacticalScore(currentStats),
                      survival: _calculateSurvivalScore(currentStats),
                      teamwork: _calculateTeamworkScore(currentStats),
                      grit: currentStats.top10Rate,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 6개 주요 메트릭 그리드
          _MetricsGrid(
            stats: currentStats,
            recentMatches: widget.bundle.matches
                .where((m) => m.gameMode.toLowerCase().contains(_selectedMode.toLowerCase()))
                .take(20)
                .toList(),
            isRanked: _selectedQueue == 'ranked',
          ),
        ] else ...[
          _EmptyStatsPanel(
            queueLabel: _selectedQueue == 'ranked' ? '경쟁전' : '일반전',
            modeLabel: _selectedMode == 'squad'
                ? '스쿼드'
                : _selectedMode == 'duo'
                    ? '듀오'
                    : '솔로',
          ),
        ],
        const SizedBox(height: 12),

        // 3. 매치 요약 및 리스트
        _MatchSummaryPanel(bundle: widget.bundle),
        const SizedBox(height: 12),

        // 4. AI 코칭 리포트 카드
        AiCoachingCard(bundle: widget.bundle),
      ],
    );
  }

  Widget _buildQueueSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161b26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF232b3c)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _buildQueueTabItem('ranked', '경쟁전')),
          Expanded(child: _buildQueueTabItem('normal', '일반전')),
        ],
      ),
    );
  }

  Widget _buildQueueTabItem(String queueKey, String label) {
    final isSelected = _selectedQueue == queueKey;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedQueue = queueKey;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? BgmsColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildModeChips() {
    final modes = [
      {'key': 'solo', 'label': '솔로'},
      {'key': 'duo', 'label': '듀오'},
      {'key': 'squad', 'label': '스쿼드'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: modes.map((mode) {
          final isSelected = _selectedMode == mode['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(mode['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedMode = mode['key']!;
                  });
                }
              },
              selectedColor: BgmsColors.accent,
              backgroundColor: const Color(0xFF161b26),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? BgmsColors.accent : const Color(0xFF232b3c),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  double _calculateCombatScore(GameModeStats stats) {
    return (stats.kd / _targetCombatKD * 100).clamp(0.0, 100.0);
  }

  double _calculateTacticalScore(GameModeStats stats) {
    return (stats.adr / _targetTacticalADR * 100).clamp(0.0, 100.0);
  }

  double _calculateSurvivalScore(GameModeStats stats) {
    if (stats.roundsPlayed == 0) return 0.0;
    final avgSurvival = stats.timeSurvived / stats.roundsPlayed;
    return (avgSurvival / _targetSurvivalSeconds * 100).clamp(0.0, 100.0);
  }

  double _calculateTeamworkScore(GameModeStats stats) {
    if (stats.roundsPlayed == 0) return 0.0;
    if (_selectedMode == 'solo') {
      // 솔로 모드에서는 어시스트가 불가능하므로, 탑10 비율(최소 20점 보장)로 보정하여 0점 수렴 방지
      return stats.top10Rate.clamp(20.0, 100.0);
    }
    final avgAssists = stats.assists / stats.roundsPlayed;
    return (avgAssists / _targetAvgAssists * 100).clamp(0.0, 100.0);
  }
}

Color _getTierColor(String tierName) {
  if (tierName.contains('Bronze')) return const Color(0xFFCD7F32);
  if (tierName.contains('Silver')) return const Color(0xFFC0C0C0);
  if (tierName.contains('Gold')) return const Color(0xFFFFD700);
  if (tierName.contains('Platinum')) return const Color(0xFFE5E4E2);
  if (tierName.contains('Diamond')) return const Color(0xFFB9F2FF);
  if (tierName.contains('Master')) return const Color(0xFFFF007F);
  if (tierName.contains('Grandmaster')) return const Color(0xFFFF3F3F);
  return BgmsColors.accent;
}

IconData _getTierIcon(String tierName) {
  if (tierName.contains('Bronze') || tierName.contains('Silver')) return Icons.shield;
  if (tierName.contains('Gold')) return Icons.emoji_events;
  if (tierName.contains('Platinum') || tierName.contains('Diamond')) return Icons.diamond;
  if (tierName.contains('Master')) return Icons.military_tech;
  if (tierName.contains('Grandmaster')) return Icons.local_fire_department;
  return Icons.stars;
}

class _TierInfoPanel extends StatelessWidget {
  const _TierInfoPanel({required this.stats});

  final GameModeStats stats;

  @override
  Widget build(BuildContext context) {
    final tierName = stats.currentTierName;
    final rp = stats.currentRankPoint;
    final bestRp = stats.bestRankPoint;

    // RP를 다음 백 단위 기준 진척도로 환산
    final double progress = (rp % 100) / 100.0;

    // 티어별 어울리는 아이콘 및 색상 설정
    final Color tierColor = _getTierColor(tierName);
    final IconData tierIcon = _getTierIcon(tierName);

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
                Icon(tierIcon, color: tierColor, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tierName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '현재 RP: $rp  (최고 RP: $bestRp)',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: tierColor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.stats,
    required this.recentMatches,
    required this.isRanked,
  });

  final GameModeStats stats;
  final List<MatchSummary> recentMatches;
  final bool isRanked;

  @override
  Widget build(BuildContext context) {
    // 1. 최근 매치 중 분석완료(fallback 아님) 매치 필터링
    final validMatches = recentMatches.where((m) => !m.isFallback).toList();

    double avgSurvivalTime = 0.0;
    double top10Rate = 0.0;
    double headshotRate = 0.0;

    if (isRanked) {
      if (validMatches.isNotEmpty) {
        // top10 진입 횟수 계산 (rank가 1~10 사이)
        final top10Count = validMatches.where((m) => m.rank != null && m.rank! <= 10).length;
        top10Rate = (top10Count / validMatches.length) * 100.0;

        // 헤드샷 비율 계산
        final totalKills = validMatches.fold<int>(0, (sum, m) => sum + m.kills);
        final totalHeadshots = validMatches.fold<int>(0, (sum, m) => sum + m.headshotKills);
        headshotRate = totalKills > 0 ? (totalHeadshots / totalKills * 100.0) : 0.0;
        
        // 생존 시간 계산
        final totalSurvival = validMatches.fold<double>(0, (sum, m) => sum + m.timeSurvived);
        avgSurvivalTime = totalSurvival / validMatches.length;
      }
    } else {
      // 일반전일 때는 기존 PUBG API 제공값 기반
      avgSurvivalTime = stats.roundsPlayed > 0 ? stats.timeSurvived / stats.roundsPlayed : 0.0;
      top10Rate = stats.top10Rate;
      headshotRate = stats.kills > 0 ? (stats.headshotKills / stats.kills * 100.0) : 0.0;
    }

    final survivalMinutes = (avgSurvivalTime / 60).floor();
    final survivalSeconds = (avgSurvivalTime % 60).round();
    
    // 생존 시간 표시 조건 (라운드 기록이 있거나 validMatches가 있을 때만 노출)
    final hasSurvivalData = isRanked ? validMatches.isNotEmpty : stats.roundsPlayed > 0;
    final survivalStr = hasSurvivalData ? '$survivalMinutes분 $survivalSeconds초' : '-';

    final metrics = [
      _Metric('KDA', stats.kda.toStringAsFixed(2), Icons.adjust),
      _Metric('ADR', stats.adr.toStringAsFixed(1), Icons.bolt),
      _Metric('승률', '${stats.winRate.toStringAsFixed(1)}%', Icons.emoji_events),
      _Metric('평균 생존 시간', survivalStr, Icons.hourglass_empty),
      _Metric('Top 10', '${top10Rate.toStringAsFixed(1)}%', Icons.leaderboard),
      _Metric('헤드샷 비율', '${headshotRate.toStringAsFixed(1)}%', Icons.gps_fixed),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 360 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            childAspectRatio: 1.25,
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
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(metric.icon, size: 18, color: index == 0 ? BgmsColors.accent : Colors.white70),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        metric.value,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: index == 0 ? BgmsColors.accent : BgmsColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Colors.white60),
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

class _EmptyStatsPanel extends StatelessWidget {
  const _EmptyStatsPanel({
    required this.queueLabel,
    required this.modeLabel,
  });

  final String queueLabel;
  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            const Text(
              '해당 모드 플레이 기록 없음',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '현재 시즌의 $queueLabel ($modeLabel) 플레이 기록이 아직 없습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchSummaryPanel extends StatelessWidget {
  const _MatchSummaryPanel({required this.bundle});

  final PlayerStatsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final matches = bundle.matches;

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
            Text(
              '최근 매치 리스트',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
            ),
            if (bundle.summaryFallback) ...[
              const SizedBox(height: 8),
              const Text('일부 매치는 상세 분석 캐시가 없어 모드 정보만 표시합니다.', style: TextStyle(color: Colors.white30, fontSize: 11)),
            ],
            const SizedBox(height: 12),
            if (matches.isEmpty)
              const Text('최근 매치가 없거나 아직 서버에 분석된 매치가 없습니다.', style: TextStyle(color: Colors.white60))
            else
              ...matches.map(
                (match) => _MatchCard(
                  match: match,
                  profile: bundle.profile,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.profile,
  });

  final MatchSummary match;
  final PlayerStatsProfile profile;

  String _formatElapsedTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime.toLocal());

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChicken = match.rank == 1;

    // 맵 그라데이션 획득
    final mapGradient = _getMapGradient(match.mapName);

    // 치킨 하이라이트 보완 그라데이션
    final finalGradient = isChicken
        ? LinearGradient(
            colors: [
              Colors.amber.withValues(alpha: 0.08),
              const Color(0xFF161b26).withValues(alpha: 0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : mapGradient;

    final border = Border.all(
      color: isChicken ? Colors.amber : const Color(0xFF232b3c),
      width: isChicken ? 1.5 : 0.8,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push(
              '/stats/match/${match.matchId}',
              extra: {
                'nickname': profile.nickname,
                'platform': profile.platform,
                'summary': match,
              },
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: finalGradient,
              borderRadius: BorderRadius.circular(12),
              border: border,
              boxShadow: isChicken
                  ? [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // 맵 전경의 기하학적 백그라운드 연출 (우측에 은은하게 위치)
                Positioned(
                  right: -20,
                  bottom: -20,
                  top: -20,
                  child: Opacity(
                    opacity: 0.08,
                    child: Icon(
                      Icons.map_outlined,
                      size: 130,
                      color: isChicken ? Colors.amber : Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단 윙 & 태그 라인
                      Row(
                        children: [
                          // 맵 종류 & 모드
                          Expanded(
                            child: Text(
                              '${match.mapName} · ${match.gameMode.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatElapsedTime(match.createdAt),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 티어 뱃지 노출
                          if (match.tier != null) ...[
                            _buildTierBadge(match.tierName),
                            const SizedBox(width: 8),
                          ],
                          // 순위 정보
                          if (match.rank != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isChicken ? Colors.amber : const Color(0xFF232b3c),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '#${match.rank}',
                                style: TextStyle(
                                  color: isChicken ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 중단 지표 라인
                      Row(
                        children: [
                          _buildMetricColumn('KILLS', '${match.kills}', Colors.redAccent),
                          const SizedBox(width: 24),
                          _buildMetricColumn('DAMAGE', match.damage.toStringAsFixed(0), Colors.amber),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: Colors.white30),
                        ],
                      ),
                      // 하단 우승(치킨) 리본 라벨 추가
                      if (isChicken) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.amber, Colors.orangeAccent],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'WINNER WINNER CHICKEN DINNER',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildTierBadge(String tierName) {
    final Color tierColor = _getTierColor(tierName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tierColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        tierName,
        style: TextStyle(
          color: tierColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Gradient _getMapGradient(String mapName) {
    final name = mapName.toLowerCase();
    if (name.contains('erangel')) {
      return LinearGradient(
        colors: [
          const Color(0xFF1b3c33).withValues(alpha: 0.8),
          const Color(0xFF0F2027).withValues(alpha: 0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (name.contains('miramar') || name.contains('desert')) {
      return LinearGradient(
        colors: [
          const Color(0xFF5A442E).withValues(alpha: 0.8),
          const Color(0xFF14110F).withValues(alpha: 0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (name.contains('sanhok')) {
      return LinearGradient(
        colors: [
          const Color(0xFF132e18).withValues(alpha: 0.8),
          const Color(0xFF08120a).withValues(alpha: 0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (name.contains('vikendi')) {
      return LinearGradient(
        colors: [
          const Color(0xFF243B55).withValues(alpha: 0.8),
          const Color(0xFF141E30).withValues(alpha: 0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (name.contains('deston')) {
      return LinearGradient(
        colors: [
          const Color(0xFF373B44).withValues(alpha: 0.8),
          const Color(0xFF1D2026).withValues(alpha: 0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (name.contains('taego')) {
      return LinearGradient(
        colors: [
          const Color(0xFF4B2329).withValues(alpha: 0.8),
          const Color(0xFF180A0C).withValues(alpha: 0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return LinearGradient(
      colors: [
        const Color(0xFF1e293b).withValues(alpha: 0.8),
        const Color(0xFF0f172a).withValues(alpha: 0.9),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.nickname, required this.platform});

  final String nickname;
  final String platform;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(color: BgmsColors.accent),
            const SizedBox(height: 24),
            Text(
              '$nickname 님의 전적을 분석 중입니다...',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '플랫폼: ${platform.toUpperCase()}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              '전적을 불러오지 못했습니다',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: BgmsColors.accent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.selectedSeason,
    required this.onSeasonChanged,
  });

  final PlayerStatsProfile profile;
  final String? selectedSeason;
  final ValueChanged<String?> onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    final updatedAt = profile.updatedAt;
    final seasons = profile.seasonsList;

    // 만약 API에서 주는 현재 활성 시즌이 있고 selectedSeason이 설정 안 되었을 때 대응
    final String currentSeasonId = selectedSeason ?? profile.seasonId ?? '';

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
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: BgmsColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.platform.toUpperCase(),
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF232b3c), height: 1),
            const SizedBox(height: 12),

            // 시즌 필터 드롭다운 UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 18, color: Colors.white70),
                    SizedBox(width: 6),
                    Text(
                      '조회 시즌',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ],
                ),
                if (seasons.isEmpty)
                  Text(
                    currentSeasonId.isEmpty ? '기본 시즌' : currentSeasonId,
                    style: const TextStyle(color: BgmsColors.accent, fontWeight: FontWeight.bold),
                  )
                else
                  DropdownButton<String>(
                    value: seasons.contains(currentSeasonId) ? currentSeasonId : seasons.first,
                    dropdownColor: const Color(0xFF161b26),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: BgmsColors.accent),
                    style: const TextStyle(
                      color: BgmsColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    items: seasons.map((season) {
                      return DropdownMenuItem<String>(
                        value: season,
                        child: Text(season),
                      );
                    }).toList(),
                    onChanged: onSeasonChanged,
                  ),
              ],
            ),
            if (updatedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                '동기화 시간: ${updatedAt.toLocal()}'.split('.').first,
                style: const TextStyle(color: BgmsColors.textMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
