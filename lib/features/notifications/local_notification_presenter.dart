import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/observability/app_logger.dart';
import 'notification_models.dart';
import 'notification_presenter.dart';

/// OS 로컬 알림을 실제로 띄우는 구현.
///
/// 권한 거부나 플랫폼 오류가 발생해도 예외를 밖으로 던지지 않는다. 알림은 보조
/// 기능이므로 실패가 화면 흐름을 막아서는 안 된다.
class LocalNotificationPresenter implements NotificationPresenter {
  LocalNotificationPresenter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'bgms_player_updates';
  static const _channelName = '전적 업데이트';
  static const _channelDescription = '즐겨찾기한 플레이어의 새 매치와 티어 변동 알림';

  bool _initialized = false;
  bool _granted = false;

  /// 앱 시작 시 한 번 호출한다. 알림 채널을 만들고 저장된 권한 상태를 확인한다.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          // 권한은 사용자가 설정 화면에서 명시적으로 요청할 때 받는다.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.defaultImportance,
        ),
      );

      _initialized = true;
      _granted = await _readPermission();
    } catch (error, stackTrace) {
      AppObservability.logger.warning(
        '로컬 알림 초기화에 실패했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'notifications', 'operation': 'initialize'},
      );
    }
  }

  @override
  Future<bool> hasPermission() async {
    if (!_initialized) await initialize();
    return _granted;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();

    try {
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        _granted =
            await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      } else if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        _granted = await android?.requestNotificationsPermission() ?? false;
      }
      return _granted;
    } catch (error, stackTrace) {
      AppObservability.logger.warning(
        '알림 권한 요청에 실패했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'notifications', 'operation': 'request_permission'},
      );
      return false;
    }
  }

  @override
  Future<void> show(BgmsNotification notification) async {
    if (!await hasPermission()) return;

    try {
      await _plugin.show(
        id: notification.id.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: notification.destination,
      );
    } catch (error, stackTrace) {
      AppObservability.logger.warning(
        '로컬 알림 표시에 실패했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {'feature': 'notifications', 'operation': 'show'},
      );
    }
  }

  Future<bool> _readPermission() async {
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.areNotificationsEnabled() ?? false;
      }
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final options = await ios?.checkPermissions();
        return options?.isAlertEnabled ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
