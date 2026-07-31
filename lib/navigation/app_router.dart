import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/board/board_detail_screen.dart';
import '../features/board/board_screen.dart';
import '../features/crates/crates_screen.dart';
import '../features/home/home_screen.dart';
import '../features/maps/maps_screen.dart';
import '../features/my/my_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/rankings/rankings_screen.dart';
import '../features/stats/match_detail_screen.dart';
import '../features/stats/match_detail_repository.dart';
import '../features/stats/player_stats_models.dart';
import '../features/stats/player_stats_repository.dart';
import '../features/stats/stats_detail_screen.dart';
import '../core/config/app_config.dart';
import '../core/network/bgms_api_client.dart';
import '../core/player/player_search_flow.dart';
import '../core/player/player_suggestion_controller.dart';
import 'shell_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});

GoRouter createAppRouter({
  Future<SharedPreferences> Function()? homePreferencesLoader,
  Future<SharedPreferences> Function()? statsPreferencesLoader,
  PlayerStatsRepository? statsRepository,
  MatchDetailRepository? matchDetailRepository,
  PlayerSuggestionFetcher? suggestionFetcher,
  bool enableSuggestions = true,
}) {
  // 위젯 테스트는 enableSuggestions를 false로 두어 네트워크를 타지 않게 한다.
  final resolvedSuggestionFetcher = enableSuggestions
      ? (suggestionFetcher ??
            BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl).fetchSuggestions)
      : null;

  return GoRouter(
    initialLocation: '/',
    routes: [
      // 알림 센터는 확인 후 벗어나는 화면이므로 하단 탭 셸 밖에 둔다.
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // 상자깡 시뮬은 몰입해서 쓰는 화면이라 탭 전환 없이 전체를 쓴다.
      GoRoute(
        path: '/crates',
        builder: (context, state) => const CratesScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // 0. 홈 탭 브랜치
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => HomeScreen(
                  preferencesLoader: homePreferencesLoader,
                  suggestionFetcher: resolvedSuggestionFetcher,
                ),
              ),
            ],
          ),
          // 1. 전적 탭 브랜치
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => StatsDetailScreen(
                  nickname: state.uri.queryParameters['nickname'],
                  platform: normalizePlayerPlatform(
                    state.uri.queryParameters['platform'] ?? 'steam',
                  ),
                  repository: statsRepository,
                  preferencesLoader: statsPreferencesLoader,
                ),
                routes: [
                  GoRoute(
                    path: 'match/:matchId',
                    builder: (context, state) {
                      final matchId = state.pathParameters['matchId'] ?? '';
                      final extra = state.extra as Map<String, dynamic>? ?? {};
                      final query = state.uri.queryParameters;

                      final nickname =
                          extra['nickname'] as String? ??
                          query['nickname'] ??
                          '';
                      final platform = normalizePlayerPlatform(
                        extra['platform'] as String? ??
                            query['platform'] ??
                            'steam',
                      );

                      final summary =
                          extra['summary'] as MatchSummary? ??
                          MatchSummary(
                            matchId: matchId,
                            mapName: query['mapName'] ?? '맵 정보 없음',
                            mapId: query['mapId'],
                            gameMode: query['gameMode'] ?? '모드 정보 없음',
                            kills: int.tryParse(query['kills'] ?? '') ?? 0,
                            damage: double.tryParse(query['damage'] ?? '') ?? 0,
                            rank: int.tryParse(query['rank'] ?? ''),
                            isFallback: query['fallback'] == 'true',
                            createdAt:
                                DateTime.tryParse(query['date'] ?? '') ??
                                DateTime.now(),
                          );

                      return MatchDetailScreen(
                        matchId: matchId,
                        nickname: nickname,
                        platform: platform,
                        summary: summary,
                        repository: matchDetailRepository,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // 2. 랭킹 탭 브랜치
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rankings',
                builder: (context, state) => const RankingsScreen(),
              ),
            ],
          ),
          // 3. 지도 탭 브랜치
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/maps',
                builder: (context, state) => MapsScreen(
                  initialMapId: state.uri.queryParameters['mapId'],
                ),
              ),
            ],
          ),
          // 4. 게시판 탭 브랜치
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/board',
                builder: (context, state) => const BoardScreen(),
                routes: [
                  GoRoute(
                    path: ':postId',
                    builder: (context, state) => BoardDetailScreen(
                      postId:
                          int.tryParse(state.pathParameters['postId'] ?? '') ??
                          0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 5. 마이 탭 브랜치
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const MyScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
