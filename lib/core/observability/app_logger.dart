import 'package:flutter/foundation.dart';

enum AppLogLevel { info, warning, error }

class AppLogEntry {
  const AppLogEntry({
    required this.level,
    required this.message,
    required this.occurredAt,
    this.error,
    this.stackTrace,
    this.context = const {},
  });

  final AppLogLevel level;
  final String message;
  final DateTime occurredAt;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, Object?> context;
}

abstract class AppLogger {
  void info(String message, {Map<String, Object?> context = const {}});

  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  });

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  });
}

class InMemoryAppLogger implements AppLogger {
  final List<AppLogEntry> _entries = [];

  List<AppLogEntry> get entries => List.unmodifiable(_entries);

  @override
  void info(String message, {Map<String, Object?> context = const {}}) {
    _add(AppLogLevel.info, message, context: context);
  }

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    _add(
      AppLogLevel.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    _add(
      AppLogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void _add(
    AppLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    _entries.add(
      AppLogEntry(
        level: level,
        message: message,
        occurredAt: DateTime.now(),
        error: error,
        stackTrace: stackTrace,
        context: Map.unmodifiable(context),
      ),
    );
  }
}

class DebugAppLogger extends InMemoryAppLogger {
  @override
  void info(String message, {Map<String, Object?> context = const {}}) {
    super.info(message, context: context);
    _debugLog(AppLogLevel.info, message, context: context);
  }

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    super.warning(
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
    _debugLog(AppLogLevel.warning, message, error: error, context: context);
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    super.error(
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
    _debugLog(AppLogLevel.error, message, error: error, context: context);
  }

  void _debugLog(
    AppLogLevel level,
    String message, {
    Object? error,
    Map<String, Object?> context = const {},
  }) {
    if (kReleaseMode) return;
    debugPrint(
      '[BGMS ${level.name}] $message ${context.isEmpty ? '' : context}',
    );
    if (error != null) debugPrint('  error: $error');
  }
}

class AppObservability {
  AppObservability._();

  static AppLogger _logger = DebugAppLogger();

  static AppLogger get logger => _logger;

  static void configure({AppLogger? logger}) {
    if (logger != null) _logger = logger;
  }

  static void recordError(
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    _logger.error(
      '처리되지 않은 오류가 발생했습니다.',
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void configureFlutterErrorHandling() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _logger.error(
        'Flutter 프레임워크 오류가 발생했습니다.',
        error: details.exception,
        stackTrace: details.stack,
        context: {
          'library': details.library,
          'context': details.context?.toString(),
        },
      );
    };
  }
}
