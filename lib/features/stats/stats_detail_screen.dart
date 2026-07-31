import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_exception.dart';
import '../../core/observability/app_logger.dart';
import '../../core/player/player_search_flow.dart';
import '../../core/storage/local_player_store.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_brand_header.dart';
import '../../navigation/shell_scaffold.dart';
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
    this.preferencesLoader,
  });

  final String? nickname;
  final String platform;
  final PlayerStatsRepository? repository;
  final Future<SharedPreferences> Function()? preferencesLoader;

  @override
  State<StatsDetailScreen> createState() => _StatsDetailScreenState();
}

class _StatsDetailScreenState extends State<StatsDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final PlayerStatsRepository _repository;
  late final Future<void> _storeReady;
  Future<PlayerStatsBundle>? _statsFuture;
  LocalPlayerStore? _store;
  List<StoredPlayer> _recentPlayers = const [];
  String? _selectedSeason;
  String _searchPlatform = 'steam';
  bool _loadingStore = true;
  bool _searching = false;
  String? _searchError;
  bool? _wasActive;

  String get _normalizedPlatform => normalizePlayerPlatform(widget.platform);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PlayerStatsRepository();
    _searchPlatform = _normalizedPlatform;
    _storeReady = _loadStore();
    _startFetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = ShellTabScope.maybeOf(context)?.currentIndex == 1;
    if (isActive && _wasActive == false) {
      _refreshPlayers();
    }
    _wasActive = isActive;
  }

  @override
  void didUpdateWidget(covariant StatsDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nickname != widget.nickname ||
        oldWidget.platform != widget.platform) {
      _selectedSeason = null; // 닉네임이나 플랫폼이 바뀌면 시즌 필터 초기화
      _searchPlatform = _normalizedPlatform;
      _startFetch();
    }
  }

  Future<void> _loadStore() async {
    try {
      final prefs =
          await (widget.preferencesLoader?.call() ??
              SharedPreferences.getInstance());
      _store = LocalPlayerStore(prefs);
      await _refreshPlayers();
    } catch (error, stackTrace) {
      AppObservability.logger.warning(
        '전적 플레이어 저장소를 불러오지 못했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'stats', 'operation': 'load_player_store'},
      );
    } finally {
      if (mounted) {
        setState(() => _loadingStore = false);
      }
    }
  }

  Future<void> _refreshPlayers() async {
    final store = _store;
    if (store == null) return;
    final recent = await store.getRecentPlayers();
    if (!mounted) return;
    setState(() {
      _recentPlayers = recent;
    });
  }

  void _startFetch({bool refresh = false}) {
    final nickname = widget.nickname?.trim() ?? '';
    if (nickname.isEmpty) {
      _statsFuture = null;
      return;
    }
    _statsFuture = _repository.fetchPlayerStats(
      nickname: nickname,
      platform: _normalizedPlatform,
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

  Future<void> _searchPlayer({String? nickname, String? platform}) async {
    if (_searching) return;

    final cleanNickname = (nickname ?? _searchController.text).trim();
    final selectedPlatform = normalizePlayerPlatform(
      platform ?? _searchPlatform,
    );
    if (cleanNickname.isEmpty) {
      if (!mounted) return;
      setState(() => _searchError = '닉네임을 입력해 주세요.');
      return;
    }
    final requestUri = GoRouter.of(context).routeInformationProvider.value.uri;

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      await _storeReady;
      final destination = await preparePlayerSearch(
        store: _store,
        nickname: cleanNickname,
        platform: selectedPlatform,
      );
      if (!mounted) return;
      if (destination == null) return;

      try {
        await _refreshPlayers();
      } catch (error, stackTrace) {
        AppObservability.logger.warning(
          '전적 최근 분석 목록을 새로고침하지 못했습니다.',
          error: error,
          stackTrace: stackTrace,
          context: {'feature': 'stats', 'operation': 'refresh_player_list'},
        );
      }
      if (!mounted) return;
      if (!isPlayerSearchNavigationCurrent(
        requestUri: requestUri,
        currentUri: GoRouter.of(context).routeInformationProvider.value.uri,
      )) {
        return;
      }

      context.go(destination.location);
    } catch (error, stackTrace) {
      AppObservability.logger.error(
        '전적 플레이어 검색 중 오류가 발생했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'stats', 'operation': 'search_player'},
      );
      if (!mounted) return;
      setState(() => _searchError = '검색 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = widget.nickname?.trim() ?? '';

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenHeader(
          title: nickname.isEmpty ? '전적 분석' : '전적',
          subtitle: nickname.isEmpty ? null : nickname,
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
          _StatsSearchHub(
            controller: _searchController,
            platform: _searchPlatform,
            recentPlayers: _recentPlayers,
            loadingStore: _loadingStore,
            searching: _searching,
            errorText: _searchError,
            onPlatformChanged: (platform) {
              setState(() => _searchPlatform = platform);
            },
            onSearch: _searchPlayer,
            onTextChanged: () {
              if (_searchError == null) return;
              setState(() => _searchError = null);
            },
          )
        else
          FutureBuilder<PlayerStatsBundle>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _LoadingPanel(
                  nickname: nickname,
                  platform: _normalizedPlatform,
                );
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                final canRetry =
                    error is! PlayerStatsException || error.isRetryable;
                // 레포지토리가 모든 예외를 PlayerStatsException으로 감싸지만,
                // 예기치 못한 예외가 올라와도 원시 문자열을 노출하지 않는다.
                final message = error is PlayerStatsException
                    ? error.message
                    : ApiException.from(error ?? '').message;
                return _ErrorPanel(
                  message: message,
                  onRetry: canRetry ? _retry : null,
                  suggestions: error is PlayerStatsException
                      ? error.suggestions
                      : const [],
                  onSuggestionTap: (PlayerSuggestion suggestion) => context.go(
                    PlayerSearchDestination(
                      nickname: suggestion.nickname,
                      platform: suggestion.platform,
                    ).location,
                  ),
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

    // 검색 전에는 새로고침할 대상이 없으므로 결과 화면에서만 당겨서 새로고침을 붙인다.
    if (nickname.isEmpty) return content;
    return RefreshIndicator(onRefresh: () async => _retry(), child: content);
  }
}

class _StatsSearchHub extends StatelessWidget {
  const _StatsSearchHub({
    required this.controller,
    required this.platform,
    required this.recentPlayers,
    required this.loadingStore,
    required this.searching,
    required this.onPlatformChanged,
    required this.onSearch,
    required this.onTextChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String platform;
  final List<StoredPlayer> recentPlayers;
  final bool loadingStore;
  final bool searching;
  final String? errorText;
  final ValueChanged<String> onPlatformChanged;
  final Future<void> Function({String? nickname, String? platform}) onSearch;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '전적 검색',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  enabled: !searching,
                  onChanged: (_) => onTextChanged(),
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    hintText: 'PUBG 닉네임을 입력하세요',
                    errorText: errorText,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: searching ? null : () => onSearch(),
                      icon: searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      tooltip: '검색',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'steam', label: Text('Steam')),
                      ButtonSegment(value: 'kakao', label: Text('Kakao')),
                    ],
                    selected: {platform},
                    onSelectionChanged: searching
                        ? null
                        : (selection) => onPlatformChanged(selection.first),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: searching ? null : () => onSearch(),
                  icon: searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.query_stats),
                  label: Text(searching ? '검색 중...' : '분석 시작'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PlayerShortcutPanel(
          title: '최근 분석',
          icon: Icons.history,
          players: recentPlayers,
          loading: loadingStore,
          emptyText: '최근에 분석한 플레이어가 없습니다.',
          onTap: (player) =>
              onSearch(nickname: player.nickname, platform: player.platform),
        ),
      ],
    );
  }
}

class _PlayerShortcutPanel extends StatelessWidget {
  const _PlayerShortcutPanel({
    required this.title,
    required this.icon,
    required this.players,
    required this.loading,
    required this.emptyText,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final List<StoredPlayer> players;
  final bool loading;
  final String emptyText;
  final ValueChanged<StoredPlayer> onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: BgmsColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator()
            else if (players.isEmpty)
              Text(
                emptyText,
                style: const TextStyle(color: BgmsColors.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players
                    .map(
                      (player) => InputChip(
                        avatar: const Icon(Icons.history, size: 18),
                        label: Text('${player.nickname} · ${player.platform}'),
                        onPressed: () => onTap(player),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
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
          SectionBand(
            title: '성향 분석',
            icon: Icons.radar_outlined,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: BgmsColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BgmsColors.border),
              ),
              child: SizedBox(
                height: 220,
                child: RadarChartWidget(
                  combat: _calculateCombatScore(currentStats),
                  tactical: _calculateTacticalScore(currentStats),
                  survival: _calculateSurvivalScore(currentStats),
                  teamwork: _calculateTeamworkScore(currentStats),
                  grit: currentStats.top10Rate,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 6개 주요 메트릭 그리드
          _MetricsGrid(
            stats: currentStats,
            recentMatches: widget.bundle.matches
                .where(
                  (m) => m.gameMode.toLowerCase().contains(
                    _selectedMode.toLowerCase(),
                  ),
                )
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
        color: BgmsColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BgmsColors.border),
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
            color: isSelected ? Colors.black : BgmsColors.textSecondary,
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
              backgroundColor: BgmsColors.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : BgmsColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? BgmsColors.accent : BgmsColors.border,
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

/// 티어 색상은 웹 TIER_STYLE과 대응하는 공용 토큰을 쓴다.
///
/// 화면마다 색이 갈리지 않도록 [BgmsColors.tierColor]로 위임한다.
Color _getTierColor(String tierName) {
  if (tierName.isEmpty || tierName == '일반전') return BgmsColors.accent;
  final color = BgmsColors.tierColor(tierName);
  return color == BgmsColors.textMuted ? BgmsColors.accent : color;
}

IconData _getTierIcon(String tierName) {
  if (tierName.contains('Bronze') || tierName.contains('Silver')) {
    return Icons.shield;
  }
  if (tierName.contains('Gold')) return Icons.emoji_events;
  if (tierName.contains('Platinum') ||
      tierName.contains('Diamond') ||
      tierName.contains('Crystal')) {
    return Icons.diamond;
  }
  if (tierName.contains('Master') || tierName.contains('Survivor')) {
    return Icons.military_tech;
  }
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
      color: BgmsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BgmsColors.border),
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
                          color: BgmsColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '현재 RP: $rp  (최고 RP: $bestRp)',
                        style: const TextStyle(
                          color: BgmsColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: BgmsColors.border,
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
        final top10Count = validMatches
            .where((m) => m.rank != null && m.rank! <= 10)
            .length;
        top10Rate = (top10Count / validMatches.length) * 100.0;

        // 헤드샷 비율 계산
        final totalKills = validMatches.fold<int>(0, (sum, m) => sum + m.kills);
        final totalHeadshots = validMatches.fold<int>(
          0,
          (sum, m) => sum + m.headshotKills,
        );
        headshotRate = totalKills > 0
            ? (totalHeadshots / totalKills * 100.0)
            : 0.0;

        // 생존 시간 계산
        final totalSurvival = validMatches.fold<double>(
          0,
          (sum, m) => sum + m.timeSurvived,
        );
        avgSurvivalTime = totalSurvival / validMatches.length;
      }
    } else {
      // 일반전일 때는 기존 PUBG API 제공값 기반
      avgSurvivalTime = stats.roundsPlayed > 0
          ? stats.timeSurvived / stats.roundsPlayed
          : 0.0;
      top10Rate = stats.top10Rate;
      headshotRate = stats.kills > 0
          ? (stats.headshotKills / stats.kills * 100.0)
          : 0.0;
    }

    final survivalMinutes = (avgSurvivalTime / 60).floor();
    final survivalSeconds = (avgSurvivalTime % 60).round();

    // 생존 시간 표시 조건 (라운드 기록이 있거나 validMatches가 있을 때만 노출)
    final hasSurvivalData = isRanked
        ? validMatches.isNotEmpty
        : stats.roundsPlayed > 0;
    final survivalStr = hasSurvivalData
        ? '$survivalMinutes분 $survivalSeconds초'
        : '-';

    final metrics = [
      _Metric('KDA', stats.kda.toStringAsFixed(2), Icons.adjust),
      _Metric('ADR', stats.adr.toStringAsFixed(1), Icons.bolt),
      _Metric('승률', '${stats.winRate.toStringAsFixed(1)}%', Icons.emoji_events),
      _Metric('평균 생존 시간', survivalStr, Icons.hourglass_empty),
      _Metric('Top 10', '${top10Rate.toStringAsFixed(1)}%', Icons.leaderboard),
      _Metric('헤드샷 비율', '${headshotRate.toStringAsFixed(1)}%', Icons.gps_fixed),
    ];

    return SectionBand(
      title: '주요 지표',
      icon: Icons.insights_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossCount = constraints.maxWidth < 360 ? 2 : 3;
          return GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
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
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BgmsColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BgmsColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      metric.icon,
                      size: 18,
                      color: index == 0
                          ? BgmsColors.accent
                          : BgmsColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        metric.value,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: index == 0
                                  ? BgmsColors.accent
                                  : BgmsColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: BgmsColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyStatsPanel extends StatelessWidget {
  const _EmptyStatsPanel({required this.queueLabel, required this.modeLabel});

  final String queueLabel;
  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: BgmsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BgmsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: BgmsColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              '해당 모드 플레이 기록 없음',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: BgmsColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '현재 시즌의 $queueLabel ($modeLabel) 플레이 기록이 아직 없습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: BgmsColors.textMuted, fontSize: 13),
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

    // 최근 매치는 항상 전체를 보여준다.
    // 상단 큐/모드 선택은 시즌 지표에만 적용되고 이 리스트에는 걸지 않는다.
    return SectionBand(
      title: '최근 매치',
      icon: Icons.receipt_long_outlined,
      action: Text(
        '${matches.length}경기',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bundle.summaryFallback) ...[
            Text(
              '일부 매치는 서버 분석이 끝나지 않아 요약만 표시합니다.',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
            ),
            const SizedBox(height: 10),
          ],
          if (matches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: BgmsColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BgmsColors.border),
              ),
              child: Text(
                '최근 매치가 없거나 아직 서버에 분석된 매치가 없습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BgmsColors.textSecondary,
                ),
              ),
            )
          else
            ...matches.map(
              (match) => _MatchCard(match: match, profile: bundle.profile),
            ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.profile});

  final MatchSummary match;
  final PlayerStatsProfile profile;

  String _formatElapsedTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime.toLocal());
    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
    if (difference.inHours < 24) return '${difference.inHours}시간 전';
    return '${difference.inDays}일 전';
  }

  /// 순위 구간별 강조 색. 1등은 골드, 상위권은 강조색을 쓴다.
  Color get _rankColor {
    final rank = match.rank;
    if (rank == null) return BgmsColors.textMuted;
    if (rank == 1) return BgmsColors.accent;
    if (rank <= 10) return BgmsColors.success;
    return BgmsColors.textSecondary;
  }

  String get _modeLabel {
    final mode = match.gameMode.toLowerCase();
    final base = mode.contains('squad')
        ? '스쿼드'
        : mode.contains('duo')
        ? '듀오'
        : mode.contains('solo')
        ? '솔로'
        : match.gameMode;
    return mode.contains('fpp') ? '$base 1인칭' : base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChicken = match.rank == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkSurface(
        borderRadius: 10,
        decoration: BoxDecoration(
          color: isChicken
              ? BgmsColors.accent.withValues(alpha: 0.08)
              : BgmsColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isChicken
                ? BgmsColors.accent.withValues(alpha: 0.45)
                : BgmsColors.border,
          ),
        ),
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
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _RankBlock(rank: match.rank, color: _rankColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.mapName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isChicken) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.emoji_events,
                              size: 14,
                              color: BgmsColors.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _modeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: BgmsColors.textMuted,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (match.tier != null) ...[
                            _DotSeparator(),
                            Flexible(
                              child: Text(
                                match.tierName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _getTierColor(match.tierName),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                          _DotSeparator(),
                          Text(
                            _formatElapsedTime(match.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: BgmsColors.textMuted,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _MatchStat(label: '킬', value: '${match.kills}'),
                const SizedBox(width: 14),
                _MatchStat(label: '딜량', value: match.damage.toStringAsFixed(0)),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: BgmsColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 매치 순위를 좌측에 고정 폭으로 표시한다.
///
/// 폭을 고정해 매치마다 본문 시작 위치가 흔들리지 않게 한다.
class _RankBlock extends StatelessWidget {
  const _RankBlock({required this.rank, required this.color});

  final int? rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank == null ? '-' : '#$rank',
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '순위',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BgmsColors.textMuted,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 매치 카드 우측의 소형 지표.
class _MatchStat extends StatelessWidget {
  const _MatchStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: BgmsColors.textMuted,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

/// 메타 정보 사이의 가운뎃점 구분자.
class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '·',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
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
      color: BgmsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BgmsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: BgmsColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: BgmsColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BgmsColors.textSecondary,
                fontSize: 13,
              ),
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
      color: BgmsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BgmsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BgmsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BgmsColors.accent,
                  ),
                ),
                const SizedBox(width: BgmsSpacing.sm),
                Expanded(
                  child: Text(
                    '$nickname 님의 전적을 분석하고 있습니다',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  platform.toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: BgmsColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: BgmsSpacing.lg),
            const SkeletonBox(height: 72, borderRadius: BgmsRadius.md),
            const SizedBox(height: BgmsSpacing.sm),
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 52)),
                SizedBox(width: BgmsSpacing.sm),
                Expanded(child: SkeletonBox(height: 52)),
                SizedBox(width: BgmsSpacing.sm),
                Expanded(child: SkeletonBox(height: 52)),
              ],
            ),
            const SizedBox(height: BgmsSpacing.sm),
            const SkeletonBox(height: 44),
            const SizedBox(height: BgmsSpacing.sm),
            const SkeletonBox(height: 44),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    this.onRetry,
    this.suggestions = const [],
    this.onSuggestionTap,
  });

  final String message;
  final VoidCallback? onRetry;

  /// 닉네임을 찾지 못했을 때 서버가 제안한 유사 플레이어.
  final List<PlayerSuggestion> suggestions;
  final void Function(PlayerSuggestion suggestion)? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;
    final onSuggestionTap = this.onSuggestionTap;
    return Card(
      color: BgmsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BgmsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: BgmsColors.danger),
            const SizedBox(height: 16),
            Text(
              '전적을 불러오지 못했습니다',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BgmsColors.textSecondary),
            ),
            if (suggestions.isNotEmpty && onSuggestionTap != null) ...[
              const SizedBox(height: 16),
              Text(
                '혹시 이 플레이어를 찾으셨나요?',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: BgmsColors.textSecondary,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in suggestions.take(6))
                    ActionChip(
                      avatar: const Icon(Icons.person_search, size: 16),
                      label: Text(
                        '${suggestion.nickname} · ${suggestion.platform}',
                      ),
                      onPressed: () => onSuggestionTap(suggestion),
                    ),
                ],
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 시도'),
              ),
            ],
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
      color: BgmsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BgmsColors.border),
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
                        style: const TextStyle(
                          color: BgmsColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: BgmsColors.border, height: 1),
            const SizedBox(height: 12),

            // 시즌 필터 드롭다운 UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: BgmsColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '조회 시즌',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: BgmsColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (seasons.isEmpty)
                  Text(
                    currentSeasonId.isEmpty
                        ? '기본 시즌'
                        : seasonLabel(currentSeasonId),
                    style: const TextStyle(
                      color: BgmsColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  DropdownButton<String>(
                    value: seasons.contains(currentSeasonId)
                        ? currentSeasonId
                        : seasons.first,
                    dropdownColor: BgmsColors.surface,
                    underline: const SizedBox(),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: BgmsColors.accent,
                    ),
                    style: const TextStyle(
                      color: BgmsColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    items: seasons.map((season) {
                      return DropdownMenuItem<String>(
                        value: season,
                        child: Text(seasonLabel(season)),
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
                style: const TextStyle(
                  color: BgmsColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
