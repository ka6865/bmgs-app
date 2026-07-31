import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_exception.dart';
import '../../core/observability/app_logger.dart';
import '../../core/player/player_search_flow.dart';
import '../../core/player/player_suggestion_controller.dart';
import '../../core/storage/local_player_store.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/bgms_brand_header.dart';
import '../../core/widgets/player_search_bar.dart';
import '../../navigation/shell_scaffold.dart';
import '../notifications/notification_bell.dart';
import 'widgets/home_dashboard_sections.dart';
import 'widgets/player_suggestion_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.preferencesLoader, this.suggestionFetcher});

  final Future<SharedPreferences> Function()? preferencesLoader;

  /// 닉네임 자동완성 조회. 지정하지 않으면 자동완성을 비활성한다.
  ///
  /// 위젯 테스트가 네트워크를 타지 않도록 주입 지점을 남긴다.
  final PlayerSuggestionFetcher? suggestionFetcher;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  String _platform = 'steam';
  late final Future<void> _storeReady;
  LocalPlayerStore? _store;
  List<StoredPlayer> _recentPlayers = const [];
  List<StoredPlayer> _favoritePlayers = const [];
  bool _loadingStore = true;
  bool _searching = false;
  String? _nicknameError;
  bool? _wasActive;
  PlayerSuggestionController? _suggestionController;

  @override
  void initState() {
    super.initState();
    _storeReady = _loadStore();

    final fetcher = widget.suggestionFetcher;
    if (fetcher != null) {
      _suggestionController =
          PlayerSuggestionController(
              fetch: (query) => _fetchMergedSuggestions(fetcher, query),
              onError: (error, stackTrace) {
                AppObservability.logger.warning(
                  '닉네임 자동완성 조회에 실패했습니다.',
                  error: error,
                  stackTrace: stackTrace,
                  context: {
                    'feature': 'home',
                    'operation': 'fetch_suggestions',
                  },
                );
              },
            )
            ..onChanged = () {
              if (mounted) setState(() {});
            };
    }
  }

  @override
  void dispose() {
    _suggestionController?.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = ShellTabScope.maybeOf(context)?.currentIndex == 0;
    if (isActive && _wasActive == false) {
      _refreshPlayers();
    }
    _wasActive = isActive;
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
        '홈 플레이어 저장소를 불러오지 못했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'home', 'operation': 'load_player_store'},
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
    final favorites = await store.getFavoritePlayers();
    if (!mounted) return;
    setState(() {
      _recentPlayers = recent;
      _favoritePlayers = favorites;
    });
  }

  /// 서버 후보와 로컬 기록을 합친다.
  ///
  /// 서버 `/api/pubg/suggest`는 색인된 닉네임만 돌려주므로 결과가 비는 경우가
  /// 잦다. 최근 검색과 즐겨찾기에서 일치하는 항목을 앞에 붙여 목록이
  /// 아예 뜨지 않는 상황을 줄인다.
  Future<List<PlayerSuggestion>> _fetchMergedSuggestions(
    PlayerSuggestionFetcher fetcher,
    String query,
  ) async {
    final local = _localSuggestions(query);
    try {
      final remote = await fetcher(query);
      final seen = <String>{};
      final merged = <PlayerSuggestion>[];
      for (final suggestion in [...local, ...remote]) {
        final key =
            '${suggestion.platform}:${suggestion.nickname.toLowerCase()}';
        if (seen.add(key)) merged.add(suggestion);
      }
      return merged;
    } catch (error) {
      // 서버 조회가 실패해도 로컬 기록만으로 후보를 제공한다.
      if (local.isEmpty) rethrow;
      return local;
    }
  }

  /// 최근 검색과 즐겨찾기에서 질의로 시작하거나 포함하는 항목을 찾는다.
  List<PlayerSuggestion> _localSuggestions(String query) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return const [];

    final seen = <String>{};
    final matched = <PlayerSuggestion>[];
    for (final player in [..._favoritePlayers, ..._recentPlayers]) {
      if (!player.nickname.toLowerCase().contains(lower)) continue;
      if (!seen.add(player.id)) continue;
      matched.add(
        PlayerSuggestion(nickname: player.nickname, platform: player.platform),
      );
    }
    return matched;
  }

  /// 입력 변화를 받아 검증 문구를 지우고 자동완성을 갱신한다.
  void _onNicknameChanged() {
    _suggestionController?.onQueryChanged(_nicknameController.text);
    if (_nicknameError == null) return;
    setState(() => _nicknameError = null);
  }

  Future<void> _search({String? nickname, String? platform}) async {
    if (_searching) return;

    // 검색을 실행하면 후보 목록을 닫는다.
    _suggestionController?.clear();

    final cleanNickname = (nickname ?? _nicknameController.text).trim();
    final selectedPlatform = normalizePlayerPlatform(platform ?? _platform);
    if (cleanNickname.isEmpty) {
      if (!mounted) return;
      setState(() {
        _nicknameError = '닉네임을 입력해 주세요.';
      });
      return;
    }
    final requestUri = GoRouter.of(context).routeInformationProvider.value.uri;

    setState(() {
      _searching = true;
      _nicknameError = null;
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
          '홈 최근 플레이어 목록을 새로고침하지 못했습니다.',
          error: error,
          stackTrace: stackTrace,
          context: {'feature': 'home', 'operation': 'refresh_player_list'},
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
        '홈 플레이어 검색 중 오류가 발생했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'home', 'operation': 'search_player'},
      );
      if (!mounted) return;
      setState(() => _nicknameError = '검색 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _toggleFavorite(StoredPlayer player) async {
    try {
      await _storeReady;
      final store = _store;
      if (store == null) return;

      await store.toggleFavorite(player.nickname, platform: player.platform);
      await _refreshPlayers();
    } catch (error, stackTrace) {
      AppObservability.logger.warning(
        '홈 즐겨찾기를 변경하지 못했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'home', 'operation': 'toggle_favorite'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestPlayer = _recentPlayers.isEmpty ? null : _recentPlayers.first;
    final remainingRecent = _recentPlayers.skip(1).toList();

    // 셸이 Scaffold를 제공하지만, 홈을 단독으로 띄우는 경우에도
    // TextField와 InkWell이 요구하는 Material 기반을 보장한다.
    return Material(
      color: BgmsColors.bgBase,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BgmsBrandHeader(title: 'BGMS', trailing: NotificationBell()),
            const SizedBox(height: 14),
            PlayerSearchBar(
              controller: _nicknameController,
              platform: _platform,
              searching: _searching,
              errorText: _nicknameError,
              onPlatformChanged: (platform) {
                setState(() => _platform = platform);
              },
              onSearch: _search,
              onTextChanged: _onNicknameChanged,
            ),
            if (_suggestionController != null)
              PlayerSuggestionList(
                suggestions: _suggestionController!.suggestions,
                onSelected: (suggestion) => _search(
                  nickname: suggestion.nickname,
                  platform: suggestion.platform,
                ),
              ),
            if (latestPlayer != null) ...[
              const SizedBox(height: 16),
              ContinuePlayerCard(
                player: latestPlayer,
                isFavorite: _favoritePlayers.any(
                  (player) => player.id == latestPlayer.id,
                ),
                onTap: () => _search(
                  nickname: latestPlayer.nickname,
                  platform: latestPlayer.platform,
                ),
                onFavoriteTap: () => _toggleFavorite(latestPlayer),
              ),
            ],
            const SizedBox(height: 20),
            FavoritePlayersSection(
              players: _favoritePlayers,
              loading: _loadingStore,
              onTap: (player) =>
                  _search(nickname: player.nickname, platform: player.platform),
            ),
            const SizedBox(height: 20),
            CrateSimBanner(onTap: () => context.push('/crates')),
            if (_loadingStore || remainingRecent.isNotEmpty) ...[
              const SizedBox(height: 20),
              RecentActivitySection(
                players: remainingRecent,
                loading: _loadingStore,
                onTap: (player) => _search(
                  nickname: player.nickname,
                  platform: player.platform,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
