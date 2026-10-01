import 'package:bgms_mobile_app/features/notifications/notification_models.dart';
import 'package:bgms_mobile_app/features/notifications/notification_settings.dart';
import 'package:bgms_mobile_app/features/notifications/notification_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _base = DateTime.utc(2026, 7, 31, 12);

BgmsNotification _notification({
  required String id,
  BgmsNotificationKind kind = BgmsNotificationKind.newMatch,
  DateTime? createdAt,
  bool isRead = false,
}) {
  return BgmsNotification(
    id: id,
    kind: kind,
    nickname: 'tester',
    platform: 'steam',
    title: '새 매치',
    body: '새 매치가 기록되었습니다.',
    createdAt: createdAt ?? _base,
    isRead: isRead,
  );
}

Future<NotificationStore> _buildStore() async {
  SharedPreferences.setMockInitialValues({});
  return NotificationStore(await SharedPreferences.getInstance());
}

void main() {
  test('알림을 저장하고 다시 읽는다', () async {
    final store = await _buildStore();
    await store.addAll([_notification(id: 'a')]);

    final items = store.getNotifications();
    expect(items, hasLength(1));
    expect(items.single.id, 'a');
    expect(items.single.kind, BgmsNotificationKind.newMatch);
    expect(items.single.isRead, isFalse);
  });

  test('최신 알림이 앞에 온다', () async {
    final store = await _buildStore();
    await store.addAll([
      _notification(id: 'old', createdAt: _base),
      _notification(id: 'new', createdAt: _base.add(const Duration(hours: 1))),
    ]);

    expect(store.getNotifications().first.id, 'new');
  });

  test('같은 id는 중복 저장하지 않는다', () async {
    final store = await _buildStore();
    await store.addAll([_notification(id: 'a')]);
    await store.addAll([_notification(id: 'a')]);

    expect(store.getNotifications(), hasLength(1));
  });

  test('상한을 넘으면 오래된 알림을 버린다', () async {
    final store = await _buildStore();
    await store.addAll([
      for (var index = 0; index < NotificationStore.maxItems + 10; index++)
        _notification(
          id: 'item-$index',
          createdAt: _base.add(Duration(minutes: index)),
        ),
    ]);

    final items = store.getNotifications();
    expect(items, hasLength(NotificationStore.maxItems));
    expect(items.first.id, 'item-59');
    expect(items.map((item) => item.id), isNot(contains('item-0')));
  });

  test('개별 읽음과 전체 읽음을 처리한다', () async {
    final store = await _buildStore();
    await store.addAll([_notification(id: 'a'), _notification(id: 'b')]);
    expect(store.unreadCount, 2);

    await store.markAsRead('a');
    expect(store.unreadCount, 1);

    await store.markAllAsRead();
    expect(store.unreadCount, 0);
  });

  test('전체 삭제로 목록을 비운다', () async {
    final store = await _buildStore();
    await store.addAll([_notification(id: 'a')]);
    await store.clearAll();

    expect(store.getNotifications(), isEmpty);
  });

  test('스냅샷을 플레이어별로 저장하고 조회한다', () async {
    final store = await _buildStore();
    final snapshot = PlayerSnapshot(
      nickname: 'Tester',
      platform: 'Steam',
      latestMatchId: 'match-1',
      matchCount: 5,
      tierName: 'Gold 2',
      seasonId: 'season-42',
      capturedAt: _base,
    );

    await store.saveSnapshot(snapshot);
    final loaded = store.getSnapshot('steam:tester');

    expect(loaded, isNotNull);
    expect(loaded!.latestMatchId, 'match-1');
    expect(loaded.tierName, 'Gold 2');
  });

  test('설정 기본값은 전체 활성이고 6시간 주기다', () async {
    final store = await _buildStore();
    final settings = store.getSettings();

    expect(settings.enabledKinds, hasLength(3));
    expect(settings.interval, NotificationInterval.sixHours);
  });

  test('설정 변경이 저장된다', () async {
    final store = await _buildStore();
    await store.saveSettings(
      NotificationSettings.defaults
          .toggle(BgmsNotificationKind.newMatch, false)
          .copyWith(interval: NotificationInterval.daily),
    );

    final settings = store.getSettings();
    expect(settings.isEnabled(BgmsNotificationKind.newMatch), isFalse);
    expect(settings.isEnabled(BgmsNotificationKind.tierChange), isTrue);
    expect(settings.interval, NotificationInterval.daily);
  });

  test('마지막 확인 시각을 기록한다', () async {
    final store = await _buildStore();
    expect(store.getLastCheckedAt(), isNull);

    await store.saveLastCheckedAt(_base);
    expect(store.getLastCheckedAt(), _base);
  });
}
