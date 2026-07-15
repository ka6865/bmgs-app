import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatefulWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(covariant ShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _currentIndex = widget.navigationShell.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ShellTabScope(
          currentIndex: _currentIndex,
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          final selectedIndex = _currentIndex;
          setState(() => _currentIndex = index);
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == selectedIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '홈'),
          NavigationDestination(icon: Icon(Icons.query_stats), label: '전적'),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: '랭킹'),
          NavigationDestination(icon: Icon(Icons.map), label: '지도'),
          NavigationDestination(icon: Icon(Icons.forum), label: '게시판'),
          NavigationDestination(icon: Icon(Icons.person), label: '마이'),
        ],
      ),
    );
  }
}

class ShellTabScope extends InheritedWidget {
  const ShellTabScope({
    super.key,
    required this.currentIndex,
    required super.child,
  });

  final int currentIndex;

  static ShellTabScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellTabScope>();
  }

  @override
  bool updateShouldNotify(ShellTabScope oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}
