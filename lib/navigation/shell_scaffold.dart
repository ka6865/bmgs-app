import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/bgms_theme.dart';

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
      backgroundColor: BgmsColors.bgBase,
      body: SafeArea(
        child: ShellTabScope(
          currentIndex: _currentIndex,
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: const BoxDecoration(
              color: BgmsColors.glassBg,
              border: Border(
                top: BorderSide(color: BgmsColors.glassBorder, width: 1.0),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                indicatorColor: BgmsColors.accent.withValues(alpha: 0.15),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final isSelected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected
                        ? BgmsColors.accent
                        : BgmsColors.textSecondary,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final isSelected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    size: 22,
                    color: isSelected
                        ? BgmsColors.accent
                        : BgmsColors.textSecondary,
                  );
                }),
              ),
              child: NavigationBar(
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
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: '홈',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.query_stats),
                    selectedIcon: Icon(Icons.query_stats_rounded),
                    label: '전적',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.leaderboard),
                    selectedIcon: Icon(Icons.leaderboard_rounded),
                    label: '랭킹',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map),
                    selectedIcon: Icon(Icons.map_rounded),
                    label: '지도',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.forum),
                    selectedIcon: Icon(Icons.forum_rounded),
                    label: '게시판',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: '마이',
                  ),
                ],
              ),
            ),
          ),
        ),
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
