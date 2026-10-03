import 'dart:async';

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
import '../../core/widgets/bgms_sparkline_bar.dart';
import '../../core/widgets/player_search_bar.dart';
import '../../navigation/shell_scaffold.dart';
import 'ai_coaching_card.dart';
import 'all_matches_screen.dart';
import 'battle_screen.dart';
import 'ban_watch_screen.dart';
import 'encounter_screen.dart';
import 'player_match_history_screen.dart';
import 'player_stats_models.dart';
import 'player_stats_repository.dart';
import 'widgets/match_card.dart';
import 'widgets/radar_chart_widget.dart';
import 'weapon_mastery_screen.dart';

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
  bool _isFavorite = false;
  DateTime? _refreshAvailableAt;
  Timer? _refreshCooldownTimer;
  String? _preferredQueue;
  String? _preferredMode;
  PlayerStatsBundle? _lastBundle;
  int _requestGeneration = 0;
  bool _isRequestInFlight = false;

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
    _refreshCooldownTimer?.cancel();
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
      _preferredQueue = null;
      _preferredMode = null;
      _lastBundle = null;
      _refreshCooldownTimer?.cancel();
      _refreshAvailableAt = null;
      _searchPlatform = _normalizedPlatform;
      _isFavorite = false;
      _startFetch();
      _refreshPlayers();
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
    final nickname = widget.nickname?.trim() ?? '';
    final platform = _normalizedPlatform;
    final recent = await store.getRecentPlayers();
    final favorite = nickname.isEmpty
        ? false
        : await store.isFavorite(nickname, platform: platform);
    if (!mounted ||
        nickname != (widget.nickname?.trim() ?? '') ||
        platform != _normalizedPlatform) {
      return;
    }
    setState(() {
      _recentPlayers = recent;
      _isFavorite = favorite;
    });
  }

  /// 지금 보고 있는 플레이어의 즐겨찾기를 토글한다.
  ///
  /// 홈으로 돌아가지 않고 전적 화면에서 바로 등록할 수 있게 한다.
  Future<void> _toggleFavorite() async {
    final nickname = widget.nickname?.trim() ?? '';
    final platform = _normalizedPlatform;
    if (nickname.isEmpty) return;
    try {
      await _storeReady;
      final store = _store;
      if (store == null) return;

      await store.toggleFavorite(nickname, platform: platform);
      await _refreshPlayers();
      if (!mounted ||
          nickname != (widget.nickname?.trim() ?? '') ||
          platform != _normalizedPlatform) {
        return;
      }
      // _refreshPlayers 이후 _isFavorite은 이미 새 상태다.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 해제했습니다.'),
        ),
      );
    } catch (error, stackTrace) {
      AppObservability.logger.warning(
        '전적 즐겨찾기를 변경하지 못했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'stats', 'operation': 'toggle_favorite'},
      );
    }
  }

  void _startFetch({bool refresh = false}) {
    final generation = ++_requestGeneration;
    final nickname = widget.nickname?.trim() ?? '';
    if (nickname.isEmpty) {
      _statsFuture = null;
      _isRequestInFlight = false;
      return;
    }
    _statsFuture = _observeStatsRequest(
      refresh: refresh,
      nickname: nickname,
      platform: _normalizedPlatform,
      generation: generation,
      season: _selectedSeason,
    );
  }

  Future<PlayerStatsBundle> _observeStatsRequest({
    required bool refresh,
    required String nickname,
    required String platform,
    required int generation,
    required String? season,
  }) async {
    _isRequestInFlight = true;
    try {
      final bundle = await _repository.fetchPlayerStats(
        nickname: nickname,
        platform: platform,
        season: season,
        refresh: refresh,
      );
      if (!mounted || generation != _requestGeneration) return bundle;
      _lastBundle = bundle;
      final initial = bundle.profile.firstPlayedMode;
      _preferredQueue ??= initial.queue;
      _preferredMode ??= initial.mode;
      if (bundle.refreshError == null &&
          (bundle.requestedRefresh ||
              refresh ||
              bundle.profile.retryAfterSeconds != null)) {
        _setRefreshCooldownSeconds(bundle.profile.retryAfterSeconds);
      }
      return bundle;
    } on PlayerStatsException catch (error) {
      if (!mounted || generation != _requestGeneration) rethrow;
      _setRefreshCooldown(error.retryAfter);
      final previous = _lastBundle;
      if (refresh && previous != null) {
        return PlayerStatsBundle(
          profile: previous.profile,
          matches: previous.matches,
          summaryFallback: previous.summaryFallback,
          summaryError: previous.summaryError,
          requestedRefresh: true,
          refreshError: error.message,
          collectionMessage: previous.collectionMessage,
          collectionAvailableAt: previous.collectionAvailableAt,
        );
      }
      rethrow;
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isRequestInFlight = false);
      }
    }
  }

  bool get _isRefreshCoolingDown {
    final availableAt = _refreshAvailableAt;
    return availableAt != null && availableAt.isAfter(DateTime.now());
  }

  int? get _refreshRemainingSeconds {
    final availableAt = _refreshAvailableAt;
    if (availableAt == null) return null;
    final remaining = availableAt.difference(DateTime.now()).inMilliseconds;
    return remaining > 0 ? (remaining / 1000).ceil() : null;
  }

  void _setRefreshCooldownSeconds(int? seconds) {
    _setRefreshCooldown(seconds == null ? null : Duration(seconds: seconds));
  }

  void _setRefreshCooldown(Duration? duration) {
    final nextAvailableAt = duration == null || duration <= Duration.zero
        ? null
        : DateTime.now().add(duration);
    if (_refreshAvailableAt == nextAvailableAt) return;
    _refreshAvailableAt = nextAvailableAt;
    _refreshCooldownTimer?.cancel();
    if (nextAvailableAt != null) {
      _refreshCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!_isRefreshCoolingDown) {
          _refreshCooldownTimer?.cancel();
          setState(() => _refreshAvailableAt = null);
          return;
        }
        setState(() {});
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _retry() async {
    if (_isRequestInFlight) {
      try {
        await _statsFuture;
      } catch (_) {}
      return;
    }
    if (_isRefreshCoolingDown) return;
    setState(() => _startFetch(refresh: true));
    try {
      await _statsFuture;
    } catch (_) {
      // FutureBuilder가 오류 상태와 재시도 안내를 렌더링한다.
    }
  }

  void _onSeasonChanged(String? newSeason) {
    if (newSeason == _selectedSeason) return;
    setState(() {
      _selectedSeason = newSeason;
      _lastBundle = null;
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

    // 셸이 Scaffold를 제공하지만, 전적 화면을 단독으로 띄우는 경우에도
    // TextField와 InkWell이 요구하는 Material 기반을 보장한다.
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenHeader(
          title: nickname.isEmpty ? '전적 분석' : '전적',
          subtitle: nickname.isEmpty ? null : nickname,
          trailing: nickname.isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _isFavorite ? Icons.star : Icons.star_border,
                        color: _isFavorite
                            ? BgmsColors.accent
                            : BgmsColors.textSecondary,
                      ),
                      tooltip: _isFavorite ? '즐겨찾기 해제' : '즐겨찾기에 추가',
                    ),
                    IconButton(
                      onPressed: _isRefreshCoolingDown || _isRequestInFlight
                          ? null
                          : _retry,
                      icon: const Icon(Icons.refresh, color: BgmsColors.accent),
                      tooltip: _isRefreshCoolingDown
                          ? '${_refreshRemainingSeconds ?? 1}초 후 새로고침 가능'
                          : '새로고침',
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BattleScreen(
                            initialNickname: nickname,
                            initialPlatform: _normalizedPlatform,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.compare_arrows),
                      tooltip: '전적 비교',
                    ),
                  ],
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
                    (error is! PlayerStatsException || error.isRetryable) &&
                    !_isRefreshCoolingDown;
                // 레포지토리가 모든 예외를 PlayerStatsException으로 감싸지만,
                // 예기치 못한 예외가 올라와도 원시 문자열을 노출하지 않는다.
                final message = error is PlayerStatsException
                    ? error.message
                    : ApiException.from(error ?? '').message;
                return _ErrorPanel(
                  message: message,
                  onRetry: canRetry ? _retry : null,
                  retryAfterSeconds: _refreshRemainingSeconds,
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
                key: ValueKey(
                  '${profile.platform}:${profile.nickname}:$currentSeasonId',
                ),
                bundle: bundle,
                selectedSeason: _selectedSeason,
                onSeasonChanged: _onSeasonChanged,
                refreshRemainingSeconds: _refreshRemainingSeconds,
                preferredQueue: _preferredQueue,
                preferredMode: _preferredMode,
                onModeChanged: (queue, mode) {
                  _preferredQueue = queue;
                  _preferredMode = mode;
                },
              );
            },
          ),
      ],
    );

    final content = Material(color: BgmsColors.bgBase, child: list);

    // 검색 전에는 새로고침할 대상이 없으므로 결과 화면에서만 당겨서 새로고침을 붙인다.
    if (nickname.isEmpty) return content;
    return RefreshIndicator(onRefresh: _retry, child: content);
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
        // 홈과 같은 검색 바를 재사용해 검색 UI가 중복되지 않게 한다.
        PlayerSearchBar(
          controller: controller,
          platform: platform,
          searching: searching,
          errorText: errorText,
          onPlatformChanged: onPlatformChanged,
          onSearch: onSearch,
          onTextChanged: onTextChanged,
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
    this.refreshRemainingSeconds,
    this.preferredQueue,
    this.preferredMode,
    required this.onModeChanged,
  });

  final PlayerStatsBundle bundle;
  final String? selectedSeason;
  final ValueChanged<String?> onSeasonChanged;
  final int? refreshRemainingSeconds;
  final String? preferredQueue;
  final String? preferredMode;
  final void Function(String queue, String mode) onModeChanged;

  @override
  State<_StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends State<_StatsContent> {
  static const double _targetCombatKD = 2.0;
  static const double _targetTacticalADR = 300.0;
  static const double _targetSurvivalSeconds = 1200.0;
  static const double _targetAvgAssists = 1.5;

  late String _selectedQueue;
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    final initial = widget.bundle.profile.firstPlayedMode;
    _selectedQueue = widget.preferredQueue ?? initial.queue;
    _selectedMode = widget.preferredMode ?? initial.mode;
  }

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
          refreshRemainingSeconds: widget.refreshRemainingSeconds,
        ),
        if (widget.bundle.refreshError != null)
          Text(
            '최신 갱신 실패 · 이전 기록을 유지합니다. ${widget.bundle.refreshError}',
            style: const TextStyle(color: BgmsColors.textSecondary),
          )
        else
          Text(switch (profile.syncStatus) {
            PlayerSyncStatus.saved =>
              '시즌 지표 새 저장 완료 · 경기 수집 상태는 DB 이력에서 확인하세요.',
            PlayerSyncStatus.cached => 'DB에 저장된 시즌 기록을 표시합니다.',
            PlayerSyncStatus.partial =>
              profile.updatedAt == null
                  ? '일부 전적 갱신 실패 · 저장된 기록 기준 시각을 확인할 수 없습니다.'
                  : '일부 전적 갱신 실패 · 이전 기록 기준 시간을 유지합니다.',
            PlayerSyncStatus.saveFailed =>
              profile.updatedAt == null
                  ? 'DB 저장 실패 · 새 저장이 완료되지 않았습니다. 저장된 기록 기준 시각을 확인할 수 없습니다.'
                  : 'DB 저장 실패 · 새 저장이 완료되지 않았습니다. 이전 기록 기준 시간을 유지합니다.',
            PlayerSyncStatus.unknown => '시즌 기록의 DB 저장 상태를 확인할 수 없습니다.',
          }, style: const TextStyle(color: BgmsColors.textSecondary)),
        if (widget.bundle.collectionMessage != null)
          Text(
            widget.bundle.collectionMessage!,
            style: const TextStyle(color: BgmsColors.textSecondary),
          ),
        Text(switch (profile.historyDiscoveryStatus) {
          HistoryDiscoveryStatus.queued =>
            '경기 수집 목록 등록 완료 · DB 전체 경기 이력에서 수집 진행을 확인하세요.',
          HistoryDiscoveryStatus.failed =>
            '경기 수집 목록 등록 실패 · DB 전체 경기 이력에서 기존 저장 기록을 확인하세요.',
          HistoryDiscoveryStatus.unknown => '경기 수집 목록 등록 상태를 확인할 수 없습니다.',
        }, style: const TextStyle(color: BgmsColors.textSecondary)),
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
                  (m) =>
                      MatchModeFilters.normalize(m.gameMode) == _selectedMode,
                )
                .take(20)
                .toList(),
            isRanked: _selectedQueue == 'ranked',
          ),
        ] else if (profile.statsAvailability[_selectedQueue]?.status ==
            StatsAvailabilityStatus.unavailable) ...[
          const _StatePanel(
            icon: Icons.cloud_off_outlined,
            title: '시즌 지표 조회 불가',
            body: '이 큐의 전적을 지금 확인할 수 없습니다. 플레이 기록이 없다는 뜻은 아닙니다.',
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
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            setState(() {
              _selectedQueue = queueKey;
              widget.onModeChanged(_selectedQueue, _selectedMode);
            });
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
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
              materialTapTargetSize: MaterialTapTargetSize.padded,
              label: Text(mode['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedMode = mode['key']!;
                    widget.onModeChanged(_selectedQueue, _selectedMode);
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
    // 시즌 지표에 다른 큐의 최근 경기를 섞지 않는다.
    final avgSurvivalTime = stats.roundsPlayed > 0
        ? stats.timeSurvived / stats.roundsPlayed
        : 0.0;
    final top10Rate = stats.top10Rate;
    final rankedSamples = recentMatches
        .where(
          (match) =>
              !match.isFallback &&
              match.matchType?.trim().toLowerCase() == 'competitive' &&
              match.kills != null,
        )
        .toList();
    final sampledKills = rankedSamples.fold<int>(
      0,
      (total, match) => total + match.kills!,
    );
    final sampledHeadshots = rankedSamples.fold<int>(
      0,
      (total, match) => total + match.headshotKills,
    );
    // 경쟁전 API는 헤드샷 합계를 제공하지 않는다. 확인된 경쟁전 표본만 쓴다.
    final headshotRate = isRanked
        ? sampledKills > 0
              ? sampledHeadshots / sampledKills * 100.0
              : 0.0
        : stats.kills > 0
        ? stats.headshotKills / stats.kills * 100.0
        : 0.0;
    final survivalTotalSeconds = avgSurvivalTime.round();
    final survivalStr = stats.roundsPlayed > 0
        ? '${survivalTotalSeconds ~/ 60}분 ${survivalTotalSeconds % 60}초'
        : '-';
    final headshotStr = isRanked && rankedSamples.isEmpty
        ? '-'
        : '${headshotRate.toStringAsFixed(1)}%';

    final metrics = [
      _Metric('KDA', stats.kda.toStringAsFixed(2), Icons.adjust),
      _Metric('ADR', stats.adr.toStringAsFixed(1), Icons.bolt),
      _Metric('승률', '${stats.winRate.toStringAsFixed(1)}%', Icons.emoji_events),
      _Metric('평균 생존 시간', survivalStr, Icons.hourglass_empty),
      _Metric('Top 10', '${top10Rate.toStringAsFixed(1)}%', Icons.leaderboard),
      _Metric(isRanked ? '최근 경쟁전 헤드샷' : '헤드샷 비율', headshotStr, Icons.gps_fixed),
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

  /// 전적 화면에 미리 보여줄 매치 수. 나머지는 전체 보기에서 확인한다.
  static const _previewCount = 5;

  @override
  Widget build(BuildContext context) {
    final matches = bundle.matches;

    // 전적 화면에는 앞쪽 몇 건만 미리 보여준다.
    // 전체 목록과 모드 필터는 '전체 보기'로 열리는 별도 화면에서 제공한다.
    // 상단 큐/모드 선택은 시즌 지표용이라 이 리스트에는 걸지 않는다.
    final preview = matches.take(_previewCount).toList();
    final hasMore = matches.length > _previewCount;

    return SectionBand(
      title: '최근 매치 · 모든 모드',
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
          if (bundle.summaryError != null) ...[
            Text(
              '최근 매치 요약을 불러오지 못했습니다. ${bundle.summaryError}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
            ),
            const SizedBox(height: 10),
          ] else if (bundle.summaryFallback) ...[
            Text(
              '일부 매치의 서버 기록을 찾지 못했습니다. 자동 분석이 진행 중인 상태는 아닙니다.',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
            ),
            const SizedBox(height: 10),
          ],
          const Text(
            '최근 경기 목록은 모든 큐·모드의 최신 최대 20경기입니다. 상단 선택은 시즌 지표에 적용됩니다. DB 전체 경기 이력은 별도 조회합니다.',
          ),
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
                '표시할 최근 경기가 없습니다. 과거에 저장된 기록은 DB 전체 경기 이력에서 확인하세요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BgmsColors.textSecondary,
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: BgmsColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BgmsColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '최근 순위 흐름',
                        style: TextStyle(
                          color: BgmsColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '치킨 ${matches.where((m) => m.rank == 1).length}회',
                        style: const TextStyle(
                          color: BgmsColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  BgmsSparklineBar(
                    ranks: matches.take(20).map((m) => m.rank).toList(),
                  ),
                ],
              ),
            ),
            ...preview.map(
              (match) => MatchCard(match: match, profile: bundle.profile),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => AllMatchesScreen(
                      matches: matches,
                      profile: bundle.profile,
                      summaryFallback:
                          bundle.summaryFallback && bundle.summaryError == null,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt, size: 18),
              label: Text(
                hasMore ? '최근 ${matches.length}경기 보기' : '최근 경기 · 모드별 필터',
              ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PlayerMatchHistoryScreen(
                    profile: bundle.profile,
                    initialCollectAvailableAt: bundle.collectionAvailableAt,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('DB 전체 경기 이력'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => WeaponMasteryScreen(
                    nickname: bundle.profile.nickname,
                    platform: bundle.profile.platform,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: const Text('무기 숙련도'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => EncounterScreen(
                    nickname: bundle.profile.nickname,
                    platform: bundle.profile.platform,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.people_outline, size: 18),
            label: const Text('만난 상대 · 관심 등록'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const BanWatchScreen(),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('관심 추적 목록'),
          ),
        ],
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
    this.retryAfterSeconds,
  });

  final String message;
  final VoidCallback? onRetry;

  /// 닉네임을 찾지 못했을 때 서버가 제안한 유사 플레이어.
  final List<PlayerSuggestion> suggestions;
  final void Function(PlayerSuggestion suggestion)? onSuggestionTap;
  final int? retryAfterSeconds;

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
            if (retryAfterSeconds != null) ...[
              const SizedBox(height: 12),
              Text(
                '${retryAfterSeconds!}초 후 다시 시도할 수 있습니다.',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
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
    this.refreshRemainingSeconds,
  });

  final PlayerStatsProfile profile;
  final String? selectedSeason;
  final ValueChanged<String?> onSeasonChanged;
  final int? refreshRemainingSeconds;

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
                '시즌 기록 기준: ${updatedAt.toLocal()}'.split('.').first,
                style: const TextStyle(
                  color: BgmsColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
            _AvailabilityNotice(
              availability: profile.statsAvailability,
              retryAfterSeconds: refreshRemainingSeconds,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityNotice extends StatelessWidget {
  const _AvailabilityNotice({
    required this.availability,
    this.retryAfterSeconds,
  });

  final Map<String, StatsAvailability> availability;
  final int? retryAfterSeconds;

  @override
  Widget build(BuildContext context) {
    final states = availability.entries
        .where((entry) => entry.value.status != StatsAvailabilityStatus.ready)
        .toList(growable: false);
    final retry = retryAfterSeconds;
    if (states.isEmpty && retry == null) return const SizedBox.shrink();

    String queueLabel(String queue) => queue == 'ranked' ? '경쟁전' : '일반전';
    String stateText(MapEntry<String, StatsAvailability> entry) {
      return switch (entry.value.status) {
        StatsAvailabilityStatus.stale =>
          '${queueLabel(entry.key)}은 이전 동기화 기록입니다.',
        StatsAvailabilityStatus.unavailable =>
          '${queueLabel(entry.key)} 데이터를 지금 불러올 수 없습니다.',
        StatsAvailabilityStatus.unknown => '',
        StatsAvailabilityStatus.ready => '',
      };
    }

    final messages = states
        .map(stateText)
        .where((message) => message.isNotEmpty)
        .toList();
    if (retry != null && retry > 0) {
      messages.add('$retry초 후 새로고침할 수 있습니다.');
    }
    if (messages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 15, color: BgmsColors.textMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              messages.join(' '),
              style: const TextStyle(color: BgmsColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
