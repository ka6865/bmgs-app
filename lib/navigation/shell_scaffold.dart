import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.child});

  final Widget child;

  int _selectedIndex(String path) {
    if (path.startsWith('/stats')) return 1;
    if (path.startsWith('/rankings')) return 2;
    if (path.startsWith('/maps')) return 3;
    if (path.startsWith('/my')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(path),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/stats');
            case 2:
              context.go('/rankings');
            case 3:
              context.go('/maps');
            case 4:
              context.go('/my');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '홈'),
          NavigationDestination(icon: Icon(Icons.query_stats), label: '전적'),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: '랭킹'),
          NavigationDestination(icon: Icon(Icons.map), label: '지도'),
          NavigationDestination(icon: Icon(Icons.person), label: '마이'),
        ],
      ),
    );
  }
}
