import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// 통합 테스트에서 찍은 스크린샷을 `screenshots/`에 저장한다.
///
/// 실행: `flutter drive --driver test_driver/integration_test.dart \
///   --target integration_test/app_walkthrough_test.dart -d DEVICE_ID`
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
