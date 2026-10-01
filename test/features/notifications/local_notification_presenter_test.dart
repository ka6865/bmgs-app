import 'package:bgms_mobile_app/features/notifications/local_notification_presenter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  test('OS 설정에서 변경한 알림 권한을 매번 다시 읽는다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    var granted = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'areNotificationsEnabled') return granted;
      return null;
    });
    final presenter = LocalNotificationPresenter();
    await presenter.initialize();
    expect(await presenter.hasPermission(), isTrue);

    granted = false;
    expect(await presenter.hasPermission(), isFalse);
    granted = true;
    expect(await presenter.hasPermission(), isTrue);
  });
}
