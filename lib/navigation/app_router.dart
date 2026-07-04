import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/maps/maps_screen.dart';
import '../features/my/my_screen.dart';
import '../features/rankings/rankings_screen.dart';
import '../features/stats/stats_detail_screen.dart';
import 'shell_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/stats',
            builder: (context, state) => StatsDetailScreen(
              nickname: state.uri.queryParameters['nickname'],
              platform: state.uri.queryParameters['platform'] ?? 'steam',
            ),
          ),
          GoRoute(
            path: '/rankings',
            builder: (context, state) => const RankingsScreen(),
          ),
          GoRoute(path: '/maps', builder: (context, state) => const MapsScreen()),
          GoRoute(path: '/my', builder: (context, state) => const MyScreen()),
        ],
      ),
    ],
  );
}
