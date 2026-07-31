import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import 'notification_models.dart';
import 'notification_providers.dart';
import 'notification_settings.dart';

/// 마이 탭의 알림 설정 카드. 종류별 on/off와 확인 주기를 다룬다.
class NotificationSettingsCard extends ConsumerStatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  ConsumerState<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState
    extends ConsumerState<NotificationSettingsCard> {
  bool? _permissionGranted;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final presenter = ref.read(notificationPresenterProvider);
    final granted = await presenter.hasPermission();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    final presenter = ref.read(notificationPresenterProvider);
    final granted = await presenter.requestPermission();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _requesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(notificationSettingsProvider).value ??
        NotificationSettings.defaults;
    final controller = ref.read(notificationControllerProvider);
    final granted = _permissionGranted;

    return SectionCard(
      title: '알림 설정',
      subtitle: '즐겨찾기한 플레이어의 전적 변화를 앱에서 확인합니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final kind in BgmsNotificationKind.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(kind.label),
              value: settings.isEnabled(kind),
              activeThumbColor: BgmsColors.accent,
              onChanged: (enabled) =>
                  controller.saveSettings(settings.toggle(kind, enabled)),
            ),
          const Divider(color: BgmsColors.border, height: BgmsSpacing.xl),
          Text(
            '확인 주기',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BgmsColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: BgmsSpacing.sm),
          Wrap(
            spacing: BgmsSpacing.sm,
            runSpacing: BgmsSpacing.sm,
            children: [
              for (final interval in NotificationInterval.values)
                ChoiceChip(
                  label: Text(interval.label),
                  selected: settings.interval == interval,
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (!selected) return;
                    controller.saveSettings(
                      settings.copyWith(interval: interval),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: BgmsSpacing.md),
          if (granted == false)
            Row(
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  size: 16,
                  color: BgmsColors.textMuted,
                ),
                const SizedBox(width: BgmsSpacing.sm),
                Expanded(
                  child: Text(
                    '기기 알림이 꺼져 있습니다. 앱 안에서는 계속 확인할 수 있습니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BgmsColors.textMuted,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _requesting ? null : _requestPermission,
                  child: Text(_requesting ? '요청 중' : '허용'),
                ),
              ],
            )
          else if (granted == true)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: BgmsColors.success,
                ),
                const SizedBox(width: BgmsSpacing.sm),
                Expanded(
                  child: Text(
                    '기기 알림이 켜져 있습니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BgmsColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
