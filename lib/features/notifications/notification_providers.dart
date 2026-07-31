import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../stats/player_stats_repository.dart';
import 'local_notification_presenter.dart';
import 'notification_models.dart';
import 'notification_presenter.dart';
import 'notification_service.dart';
import 'notification_settings.dart';
import 'notification_store.dart';

/// OS 알림 표시 구현. 테스트에서 fake로 override 한다.
final notificationPresenterProvider = Provider<NotificationPresenter>(
  (ref) => LocalNotificationPresenter(),
);

final notificationStoreProvider = FutureProvider<NotificationStore>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return NotificationStore(prefs);
});

final notificationServiceProvider = FutureProvider<NotificationService>((
  ref,
) async {
  return NotificationService(
    store: await ref.watch(notificationStoreProvider.future),
    playerStore: await ref.watch(localPlayerStoreProvider.future),
    statsRepository: PlayerStatsRepository(
      client: ref.watch(apiClientProvider),
    ),
    presenter: ref.watch(notificationPresenterProvider),
  );
});

final notificationsProvider = FutureProvider<List<BgmsNotification>>((
  ref,
) async {
  final store = await ref.watch(notificationStoreProvider.future);
  return store.getNotifications();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final store = await ref.watch(notificationStoreProvider.future);
  return store.unreadCount;
});

final notificationSettingsProvider = FutureProvider<NotificationSettings>((
  ref,
) async {
  final store = await ref.watch(notificationStoreProvider.future);
  return store.getSettings();
});

/// 알림 목록과 설정 변경을 담당한다. 변경 후 관련 provider를 무효화한다.
class NotificationController {
  NotificationController(this._ref);

  final Ref _ref;

  Future<NotificationStore> get _store =>
      _ref.read(notificationStoreProvider.future);

  void _invalidateList() {
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(unreadNotificationCountProvider);
  }

  /// 확인 주기가 지났으면 즐겨찾기 전적을 다시 확인한다.
  Future<int> checkIfDue() async {
    final service = await _ref.read(notificationServiceProvider.future);
    final created = await service.checkIfDue();
    if (created > 0) _invalidateList();
    return created;
  }

  Future<int> refreshNow() async {
    final service = await _ref.read(notificationServiceProvider.future);
    final created = await service.checkNow();
    _invalidateList();
    return created;
  }

  Future<void> markAsRead(String id) async {
    await (await _store).markAsRead(id);
    _invalidateList();
  }

  Future<void> markAllAsRead() async {
    await (await _store).markAllAsRead();
    _invalidateList();
  }

  Future<void> clearAll() async {
    await (await _store).clearAll();
    _invalidateList();
  }

  Future<void> saveSettings(NotificationSettings settings) async {
    await (await _store).saveSettings(settings);
    _ref.invalidate(notificationSettingsProvider);
  }
}

final notificationControllerProvider = Provider<NotificationController>(
  (ref) => NotificationController(ref),
);
