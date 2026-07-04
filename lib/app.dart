import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';

class BgmsApp extends StatelessWidget {
  const BgmsApp({super.key});

  static final _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BGMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}
