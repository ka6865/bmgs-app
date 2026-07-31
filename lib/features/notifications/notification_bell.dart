import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import 'notification_providers.dart';

/// 알림 센터 진입 버튼. 미읽음이 있으면 카운트 배지를 겹친다.
///
/// ProviderScope가 없는 트리(일부 위젯 테스트)에서도 렌더링되도록 미읽음 조회를
/// 별도 위젯으로 분리한다. 스코프가 없으면 배지 없이 아이콘만 보여준다.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      // ProviderScope 없이 화면만 띄우는 위젯 테스트에서는 배지를 생략한다.
      return const _BellFrame(unread: 0);
    }
    return const _UnreadBell();
  }
}

class _UnreadBell extends ConsumerWidget {
  const _UnreadBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    return _BellFrame(unread: unread);
  }
}

class _BellFrame extends StatelessWidget {
  const _BellFrame({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    const size = NotificationBell._size;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IconButton(
              tooltip: hasUnread ? '알림 $unread건' : '알림',
              padding: EdgeInsets.zero,
              onPressed: () => context.push('/notifications'),
              icon: Icon(
                hasUnread ? Icons.notifications_active : Icons.notifications_none,
                color: hasUnread
                    ? BgmsColors.accent
                    : BgmsColors.textSecondary,
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: 2,
              top: 2,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: BgmsColors.danger,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BgmsColors.bgBase, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: BgmsColors.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
