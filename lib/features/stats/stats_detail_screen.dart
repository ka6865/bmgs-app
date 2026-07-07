import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'ai_coaching_card.dart';
import 'player_stats_models.dart';
import 'player_stats_repository.dart';

class StatsDetailScreen extends StatefulWidget {
  const StatsDetailScreen({
    super.key,
    required this.nickname,
    required this.platform,
  });

  final String? nickname;
  final String platform;

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
    _repository = PlayerStatsRepository();
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

  void _startFetch() {
    final nickname = widget.nickname?.trim() ?? '';
    if (nickname.isEmpty) {
      _statsFuture = null;
      return;
    }
    _statsFuture = _repository.fetchPlayerStats(
      nickname: nickname,
      platform: widget.platform,
      season: _selectedSeason,
    );
  }

  void _retry() {
    setState(_startFetch);
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
              return _StatsContent(
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

class _StatsContent extends StatelessWidget {
  const _StatsContent({
    required this.bundle,
    required this.selectedSeason,
    required this.onSeasonChanged,
  });

  final PlayerStatsBundle bundle;
  final String? selectedSeason;
  final ValueChanged<String?> onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    final profile = bundle.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 프로필 헤더 & 시즌 필터 드롭다운
        _ProfileHeader(
          profile: profile,
          selectedSeason: selectedSeason,
          onSeasonChanged: onSeasonChanged,
        ),
        const SizedBox(height: 12),

        // 2. 주요 스펙 지표들
        _MetricsGrid(profile: profile),
        if (!profile.hasSeasonStats) ...[
          const SizedBox(height: 12),
          const _StatePanel(
            icon: Icons.info_outline,
            title: '선택 시즌 기록이 비어 있습니다',
            body: '서버 응답은 정상이나 현재 시즌의 플레이 기록이 아직 없을 수 있습니다.',
          ),
        ],
        const SizedBox(height: 12),

        // 3. 매치 요약 및 리스트
        _MatchSummaryPanel(bundle: bundle),
        const SizedBox(height: 12),

        // 4. AI 코칭 리포트 카드
        AiCoachingCard(bundle: bundle),
      ],
    );
  }
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

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.profile});

  final PlayerStatsProfile profile;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric('K/D', profile.kd.toStringAsFixed(2), Icons.adjust),
      _Metric('ADR', profile.adr.toStringAsFixed(1), Icons.bolt),
      _Metric(
        '승률',
        '${profile.winRate.toStringAsFixed(1)}%',
        Icons.emoji_events,
      ),
      _Metric(
        '평균 순위',
        profile.averageRank > 0 ? profile.averageRank.toStringAsFixed(1) : '-',
        Icons.leaderboard,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: narrow ? 2 : 4,
            childAspectRatio: narrow ? 1.55 : 1.25,
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
                    Icon(metric.icon, size: 20, color: index == 0 ? BgmsColors.accent : Colors.white70),
                    const SizedBox(height: 8),
                    FittedBox(
                      child: Text(
                        metric.value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: index == 0
                              ? BgmsColors.accent
                              : BgmsColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(metric.label, maxLines: 1, style: const TextStyle(fontSize: 11, color: Colors.white60)),
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
                (match) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 0.5),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      '${match.mapName} · ${match.gameMode}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      '킬: ${match.kills} | 데미지: ${match.damage.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (match.rank != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: match.rank == 1 ? BgmsColors.accent.withValues(alpha: 0.15) : Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: match.rank == 1 ? BgmsColors.accent : Colors.white24,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '#${match.rank}',
                              style: TextStyle(
                                color: match.rank == 1 ? BgmsColors.accent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.white30),
                      ],
                    ),
                    onTap: () {
                      context.push(
                        '/stats/match/${match.matchId}',
                        extra: {
                          'nickname': bundle.profile.nickname,
                          'platform': bundle.profile.platform,
                          'summary': match,
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
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
