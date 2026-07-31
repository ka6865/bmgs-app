import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_models.dart';
import 'notification_settings.dart';

/// 알림 목록, 스냅샷, 설정을 로컬에 보관한다.
///
/// 직렬화와 영속화만 담당하고 감지 판단은 하지 않는다.
class NotificationStore {
  NotificationStore(this._prefs);

  final SharedPreferences _prefs;

  static const _itemsKey = 'bgms.notifications.items';
  static const _snapshotsKey = 'bgms.notifications.snapshots';
  static const _settingsKey = 'bgms.notifications.settings';
  static const _lastCheckKey = 'bgms.notifications.lastCheck';

  /// 보관할 알림 최대 건수. 저장 용량을 예측 가능하게 유지한다.
  static const maxItems = 50;

  List<BgmsNotification> getNotifications() {
    final raw = _prefs.getStringList(_itemsKey) ?? const <String>[];
    final items = raw
        .map(_decodeNotification)
        .whereType<BgmsNotification>()
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  int get unreadCount =>
      getNotifications().where((item) => !item.isRead).length;

  /// 새 알림을 앞쪽에 추가한다. 같은 id는 무시하고 상한을 넘으면 오래된 것을 버린다.
  Future<void> addAll(List<BgmsNotification> incoming) async {
    if (incoming.isEmpty) return;

    final current = getNotifications();
    final existingIds = current.map((item) => item.id).toSet();
    final fresh = incoming.where((item) => !existingIds.contains(item.id));
    if (fresh.isEmpty) return;

    final merged = <BgmsNotification>[...fresh, ...current];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeNotifications(merged.take(maxItems).toList());
  }

  Future<void> markAsRead(String id) async {
    final next = getNotifications()
        .map((item) => item.id == id ? item.copyWith(isRead: true) : item)
        .toList();
    await _writeNotifications(next);
  }

  Future<void> markAllAsRead() async {
    final next = getNotifications()
        .map((item) => item.copyWith(isRead: true))
        .toList();
    await _writeNotifications(next);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_itemsKey);
  }

  PlayerSnapshot? getSnapshot(String playerId) => getSnapshots()[playerId];

  Map<String, PlayerSnapshot> getSnapshots() {
    final raw = _prefs.getString(_snapshotsKey);
    if (raw == null || raw.isEmpty) return const {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};

      final result = <String, PlayerSnapshot>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final snapshot = PlayerSnapshot.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (snapshot != null) result[entry.key.toString()] = snapshot;
      }
      return result;
    } catch (_) {
      // 저장 형식이 깨졌으면 스냅샷을 버리고 다음 확인에서 새로 만든다.
      return const {};
    }
  }

  Future<void> saveSnapshot(PlayerSnapshot snapshot) async {
    final next = Map<String, PlayerSnapshot>.of(getSnapshots());
    next[snapshot.playerId] = snapshot;
    await _prefs.setString(
      _snapshotsKey,
      jsonEncode(
        next.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  NotificationSettings getSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return NotificationSettings.defaults;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return NotificationSettings.defaults;
      return NotificationSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return NotificationSettings.defaults;
    }
  }

  Future<void> saveSettings(NotificationSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  DateTime? getLastCheckedAt() {
    final raw = _prefs.getString(_lastCheckKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveLastCheckedAt(DateTime value) async {
    await _prefs.setString(_lastCheckKey, value.toIso8601String());
  }

  Future<void> _writeNotifications(List<BgmsNotification> items) async {
    await _prefs.setStringList(
      _itemsKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  BgmsNotification? _decodeNotification(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return BgmsNotification.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
