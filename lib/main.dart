import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/observability/app_logger.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      AppObservability.configureFlutterErrorHandling();

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppObservability.recordError(
          error,
          stackTrace,
          context: {'source': 'platform_dispatcher'},
        );
        return true;
      };

      if (AppConfig.local.canInitializeSupabase) {
        await Supabase.initialize(
          url: AppConfig.local.supabaseUrl!,
          publishableKey: AppConfig.local.supabaseAnonKey!,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
      }

      runApp(const ProviderScope(child: BgmsApp()));
    },
    (error, stackTrace) {
      AppObservability.recordError(
        error,
        stackTrace,
        context: {'source': 'run_zoned_guarded'},
      );
    },
  );
}
