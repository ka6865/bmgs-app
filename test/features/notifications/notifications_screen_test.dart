import 'package:bgms_mobile_app/core/theme/app_theme.dart';
import 'package:bgms_mobile_app/features/notifications/notification_bell.dart';
import 'package:bgms_mobile_app/features/notifications/notification_models.dart';
import 'package:bgms_mobile_app/features/notifications/notification_providers.dart';
import 'package:bgms_mobile_app/features/notifications/notification_store.dart';
import 'package:bgms_mobile_app/features/notifications/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _base = DateTime.utc(2026, 7, 31, 12);

BgmsNotification _notification({
  required String id,
  BgmsNotificationKind kind = BgmsNotificationKind.newMatch,
  String title = '새 매치',
  bool isRead = false,
}) {
  return BgmsNotification(
    id: id,
    kind: kind,
    nickname: 'tester',
    platform: 'steam',
    title: title,
    body: '새 매치가 기록되었습니다.',
    createdAt: _base,
    isRead: isRead,
  );
}

Future<NotificationStore> _seed(List<BgmsNotification> items) async {
  SharedPreferences.setMockInitialValues({});
  final store = NotificationStore(await SharedPreferences.getInstance());
  await store.addAll(items);
  return store;
}

Future<void> _pumpScreen(WidgetTester tester, NotificationStore store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationStoreProvider.overrideWith((ref) async => store)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const NotificationsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('알림 목록을 렌더링한다', (tester) async {
    final store = await _seed([
      _notification(id: 'a', title: '새 매치'),
      _notification(
        id: 'b',
        kind: BgmsNotificationKind.tierChange,
        title: '티어가 올랐습니다',
      ),
    ]);

    await _pumpScreen(tester, store);

    expect(find.text('새 매치'), findsOneWidget);
    expect(find.text('티어가 올랐습니다'), findsOneWidget);
  });

  testWidgets('알림이 없으면 빈 상태를 보여준다', (tester) async {
    final store = await _seed(const []);
    await _pumpScreen(tester, store);

    expect(find.text('알림이 없습니다'), findsOneWidget);
  });

  testWidgets('모두 읽음을 누르면 미읽음이 사라진다', (tester) async {
    final store = await _seed([_notification(id: 'a'), _notification(id: 'b')]);
    await _pumpScreen(tester, store);
    expect(store.unreadCount, 2);

    await tester.tap(find.byIcon(Icons.done_all));
    await tester.pumpAndSettle();

    expect(store.unreadCount, 0);
  });

  testWidgets('모두 삭제는 확인 후 목록을 비운다', (tester) async {
    final store = await _seed([_notification(id: 'a')]);
    await _pumpScreen(tester, store);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(store.getNotifications(), isEmpty);
  });

  testWidgets('벨은 미읽음 수를 배지로 보여준다', (tester) async {
    final store = await _seed([
      _notification(id: 'a'),
      _notification(id: 'b'),
      _notification(id: 'c', isRead: true),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStoreProvider.overrideWith((ref) async => store),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: NotificationBell()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
  });

  testWidgets('미읽음이 없으면 배지를 숨긴다', (tester) async {
    final store = await _seed([_notification(id: 'a', isRead: true)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStoreProvider.overrideWith((ref) async => store),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: NotificationBell()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  test('상대 시각 표기', () {
    expect(relativeTimeLabel(_base, _base), '방금');
    expect(
      relativeTimeLabel(_base, _base.add(const Duration(minutes: 30))),
      '30분 전',
    );
    expect(
      relativeTimeLabel(_base, _base.add(const Duration(hours: 5))),
      '5시간 전',
    );
    expect(
      relativeTimeLabel(_base, _base.add(const Duration(days: 3))),
      '3일 전',
    );
    expect(
      relativeTimeLabel(_base, _base.add(const Duration(days: 10))),
      '2026.07.31',
    );
  });
}
