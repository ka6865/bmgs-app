import 'package:bgms_mobile_app/core/observability/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InMemoryAppLogger records error entries with context', () {
    final logger = InMemoryAppLogger();
    final error = StateError('network failed');
    final stackTrace = StackTrace.current;

    logger.error(
      '전적 조회 실패',
      error: error,
      stackTrace: stackTrace,
      context: {'feature': 'stats'},
    );

    expect(logger.entries, hasLength(1));
    expect(logger.entries.single.level, AppLogLevel.error);
    expect(logger.entries.single.message, '전적 조회 실패');
    expect(logger.entries.single.error, same(error));
    expect(logger.entries.single.stackTrace, same(stackTrace));
    expect(logger.entries.single.context['feature'], 'stats');
  });

  test(
    'AppObservability forwards uncaught errors to the configured logger',
    () {
      final logger = InMemoryAppLogger();
      final error = ArgumentError('bad input');
      final stackTrace = StackTrace.current;

      AppObservability.configure(logger: logger);
      AppObservability.recordError(
        error,
        stackTrace,
        context: {'source': 'test'},
      );

      expect(logger.entries, hasLength(1));
      expect(logger.entries.single.level, AppLogLevel.error);
      expect(logger.entries.single.message, '처리되지 않은 오류가 발생했습니다.');
      expect(logger.entries.single.error, same(error));
      expect(logger.entries.single.context['source'], 'test');
    },
  );
}
