import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/notifications/notification_providers.dart';
import 'navigation/app_router.dart';

/// 앱 루트. ProviderScope를 스스로 포함하므로 호출부에서 감쌀 필요가 없다.
class BgmsApp extends StatelessWidget {
  const BgmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _BgmsAppView());
  }
}

class _BgmsAppView extends ConsumerStatefulWidget {
  const _BgmsAppView();

  @override
  ConsumerState<_BgmsAppView> createState() => _BgmsAppViewState();
}

class _BgmsAppViewState extends ConsumerState<_BgmsAppView>
    with WidgetsBindingObserver {
  static final _router = createAppRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkNotifications();
    }
  }

  /// 앱이 앞으로 나올 때 확인 주기가 지났으면 즐겨찾기 전적을 다시 확인한다.
  ///
  /// 실패는 서비스 내부에서 로깅하고 넘긴다. 알림은 보조 기능이므로 앱 시작을 막지 않는다.
  void _checkNotifications() {
    Future<void>(() async {
      await ref.read(notificationControllerProvider).checkIfDue();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BGMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: _router,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        );
      },
    );
  }
}
