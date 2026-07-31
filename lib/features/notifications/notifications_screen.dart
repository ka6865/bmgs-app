import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import 'notification_models.dart';
import 'notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final controller = ref.read(notificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        backgroundColor: BgmsColors.surface,
        actions: [
          IconButton(
            tooltip: '전적 다시 확인',
            onPressed: () async {
              final created = await controller.refreshNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    created > 0
                        ? '새 알림 $created건을 확인했습니다.'
                        : '변경된 전적이 없습니다.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '모두 읽음',
            onPressed: controller.markAllAsRead,
            icon: const Icon(Icons.done_all),
          ),
          IconButton(
            tooltip: '모두 삭제',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: BgmsColors.surface,
                  title: const Text('알림을 모두 삭제할까요?'),
                  content: const Text('삭제한 알림은 복구할 수 없습니다.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await controller.clearAll();
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: switch (notifications) {
        AsyncLoading() => const Padding(
          padding: EdgeInsets.all(BgmsSpacing.lg),
          child: LoadingCard(lines: 5, label: '알림을 불러오고 있습니다'),
        ),
        AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(BgmsSpacing.lg),
          child: ErrorPanel(
            error: error,
            onRetry: () => ref.invalidate(notificationsProvider),
            title: '알림을 불러오지 못했습니다',
          ),
        ),
        AsyncValue(:final value) => _NotificationList(
          notifications: value ?? const [],
        ),
      },
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.notifications});

  final List<BgmsNotification> notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notifications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(BgmsSpacing.lg),
        child: InfoPanel(
          icon: Icons.notifications_none,
          title: '알림이 없습니다',
          body: '즐겨찾기한 플레이어의 새 매치와 티어 변동을 여기서 확인합니다.',
        ),
      );
    }

    final controller = ref.read(notificationControllerProvider);

    return ListView.separated(
      padding: const EdgeInsets.all(BgmsSpacing.lg),
      itemCount: notifications.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: BgmsSpacing.sm),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationTile(
          notification: notification,
          onTap: () async {
            await controller.markAsRead(notification.id);
            if (!context.mounted) return;
            context.go(notification.destination);
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final BgmsNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.kind) {
    BgmsNotificationKind.newMatch => Icons.sports_esports_outlined,
    BgmsNotificationKind.tierChange => Icons.military_tech_outlined,
    BgmsNotificationKind.seasonChange => Icons.event_repeat_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return Card(
      color: unread ? BgmsColors.elevated : BgmsColors.surface,
      child: InkWell(
        borderRadius: BgmsRadius.lg,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BgmsSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(BgmsSpacing.sm),
                decoration: BoxDecoration(
                  color: unread
                      ? BgmsColors.accent.withValues(alpha: 0.16)
                      : BgmsColors.border,
                  borderRadius: BgmsRadius.md,
                ),
                child: Icon(
                  _icon,
                  size: 18,
                  color: unread ? BgmsColors.accent : BgmsColors.textSecondary,
                ),
              ),
              const SizedBox(width: BgmsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BgmsColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: BgmsSpacing.xs),
                    Text(
                      relativeTimeLabel(notification.createdAt, DateTime.now()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BgmsColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: BgmsSpacing.sm),
                  decoration: const BoxDecoration(
                    color: BgmsColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 알림 시각을 상대 표기로 바꾼다. 하루가 넘으면 일 단위로 표시한다.
String relativeTimeLabel(DateTime target, DateTime now) {
  final diff = now.difference(target);
  if (diff.isNegative || diff.inMinutes < 1) return '방금';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${target.year}.${target.month.toString().padLeft(2, '0')}.'
      '${target.day.toString().padLeft(2, '0')}';
}
