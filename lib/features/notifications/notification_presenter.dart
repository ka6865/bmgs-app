import 'notification_models.dart';

/// OS 알림 표시 경계. 플랫폼 채널을 감싸 테스트에서 fake로 대체한다.
abstract class NotificationPresenter {
  /// 알림 권한을 요청한다. 허용 여부를 반환한다.
  Future<bool> requestPermission();

  /// 현재 권한이 허용 상태인지 확인한다.
  Future<bool> hasPermission();

  Future<void> show(BgmsNotification notification);
}

/// OS 알림을 띄우지 않는 구현. 테스트와 권한 거부 상태에서 쓴다.
class NoopNotificationPresenter implements NotificationPresenter {
  const NoopNotificationPresenter();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> show(BgmsNotification notification) async {}
}
