import 'notification_models.dart';

/// 즐겨찾기 전적을 다시 확인할 최소 간격.
enum NotificationInterval { everyLaunch, hourly, sixHours, daily }

extension NotificationIntervalInfo on NotificationInterval {
  String get storageKey => switch (this) {
    NotificationInterval.everyLaunch => 'every_launch',
    NotificationInterval.hourly => 'hourly',
    NotificationInterval.sixHours => 'six_hours',
    NotificationInterval.daily => 'daily',
  };

  String get label => switch (this) {
    NotificationInterval.everyLaunch => '앱 실행마다',
    NotificationInterval.hourly => '1시간',
    NotificationInterval.sixHours => '6시간',
    NotificationInterval.daily => '하루',
  };

  Duration get duration => switch (this) {
    NotificationInterval.everyLaunch => Duration.zero,
    NotificationInterval.hourly => const Duration(hours: 1),
    NotificationInterval.sixHours => const Duration(hours: 6),
    NotificationInterval.daily => const Duration(days: 1),
  };

  static NotificationInterval fromStorageKey(String value) {
    for (final interval in NotificationInterval.values) {
      if (interval.storageKey == value) return interval;
    }
    return NotificationInterval.sixHours;
  }
}

/// 알림 설정. 종류별 on/off와 확인 주기를 담는다.
class NotificationSettings {
  const NotificationSettings({
    this.enabledKinds = const {
      BgmsNotificationKind.newMatch,
      BgmsNotificationKind.tierChange,
      BgmsNotificationKind.seasonChange,
    },
    this.interval = NotificationInterval.sixHours,
  });

  final Set<BgmsNotificationKind> enabledKinds;
  final NotificationInterval interval;

  static const defaults = NotificationSettings();

  bool isEnabled(BgmsNotificationKind kind) => enabledKinds.contains(kind);

  /// 하나도 켜져 있지 않으면 감지 자체를 건너뛴다.
  bool get hasAnyEnabled => enabledKinds.isNotEmpty;

  NotificationSettings copyWith({
    Set<BgmsNotificationKind>? enabledKinds,
    NotificationInterval? interval,
  }) {
    return NotificationSettings(
      enabledKinds: enabledKinds ?? this.enabledKinds,
      interval: interval ?? this.interval,
    );
  }

  NotificationSettings toggle(BgmsNotificationKind kind, bool enabled) {
    final next = Set<BgmsNotificationKind>.of(enabledKinds);
    if (enabled) {
      next.add(kind);
    } else {
      next.remove(kind);
    }
    return copyWith(enabledKinds: next);
  }

  /// 마지막 확인 시각 기준으로 다시 확인해야 하는지 판단한다.
  bool shouldCheck({required DateTime? lastCheckedAt, required DateTime now}) {
    if (!hasAnyEnabled) return false;
    if (lastCheckedAt == null) return true;
    if (interval == NotificationInterval.everyLaunch) return true;
    return now.difference(lastCheckedAt) >= interval.duration;
  }

  Map<String, dynamic> toJson() => {
    'kinds': enabledKinds.map((kind) => kind.storageKey).toList(),
    'interval': interval.storageKey,
  };

  static NotificationSettings fromJson(Map<String, dynamic> json) {
    final rawKinds = json['kinds'];
    final kinds = rawKinds is List
        ? rawKinds
              .map(
                (value) =>
                    BgmsNotificationKindLabel.fromStorageKey(value.toString()),
              )
              .whereType<BgmsNotificationKind>()
              .toSet()
        : defaults.enabledKinds;

    return NotificationSettings(
      enabledKinds: kinds,
      interval: NotificationIntervalInfo.fromStorageKey(
        json['interval']?.toString() ?? '',
      ),
    );
  }
}
