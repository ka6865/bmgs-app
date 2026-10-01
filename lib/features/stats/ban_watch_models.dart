class BanWatchItem {
  const BanWatchItem({
    required this.id,
    required this.platform,
    required this.targetAccountId,
    required this.nickname,
    required this.eventAt,
    required this.createdAt,
    required this.activeUntil,
    this.mapName,
    this.weapon,
    this.baselineStatus,
    this.currentStatus,
    this.currentCheckedAt,
    this.currentError,
  });

  final String id;
  final String platform;
  final String targetAccountId;
  final String nickname;
  final DateTime? eventAt;
  final DateTime? createdAt;
  final DateTime? activeUntil;
  final String? mapName;
  final String? weapon;
  final String? baselineStatus;
  final String? currentStatus;
  final DateTime? currentCheckedAt;
  final String? currentError;

  factory BanWatchItem.fromJson(Map<String, dynamic> json) => BanWatchItem(
    id: json['id']?.toString() ?? '',
    platform: json['platform']?.toString() ?? '',
    targetAccountId: json['targetAccountId']?.toString() ?? '',
    nickname: json['nicknameAtMatch']?.toString() ?? '상대',
    eventAt: _date(json['eventAt']),
    createdAt: _date(json['createdAt']),
    activeUntil: _date(json['activeUntil']),
    mapName: _text(json['mapName']),
    weapon: _text(json['weapon']),
    baselineStatus: _text(json['baselineStatus']),
    currentStatus: _text(json['currentStatus']),
    currentCheckedAt: _date(json['currentCheckedAt']),
    currentError: _text(json['currentError']),
  );

  String get statusLabel => switch (currentStatus) {
    'none' => '현재 제재 표시 없음',
    'temporary' => '임시 제재 확인',
    'permanent' => '영구 제재 확인',
    'unknown' => '제재 상태 확인 실패',
    _ => '확인 대기',
  };

  bool get hasStatusChange =>
      baselineStatus != null &&
      currentStatus != null &&
      baselineStatus != currentStatus;
}

class BanWatchList {
  const BanWatchList({required this.items});

  final List<BanWatchItem> items;

  factory BanWatchList.fromJson(Map<String, dynamic> json) {
    final rawEnvelope = json['data'];
    final envelope = rawEnvelope is Map
        ? Map<String, dynamic>.from(rawEnvelope)
        : json;
    final statusByTarget = <String, Map<String, dynamic>>{};
    final rawStatuses = envelope['statuses'];
    if (rawStatuses is List) {
      for (final rawStatus in rawStatuses.whereType<Map>()) {
        final status = Map<String, dynamic>.from(rawStatus);
        final platform = status['platform']?.toString() ?? '';
        final accountId = status['accountId']?.toString() ?? '';
        if (platform.isNotEmpty && accountId.isNotEmpty) {
          statusByTarget['$platform:$accountId'] = status;
        }
      }
    }
    final rawItems = envelope['items'];
    return BanWatchList(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((raw) {
                  final item = Map<String, dynamic>.from(raw);
                  final key = '${item['platform']}:${item['targetAccountId']}';
                  final status = statusByTarget[key];
                  if (status != null && item['currentStatus'] == null) {
                    item['currentStatus'] = status['status'];
                    item['currentCheckedAt'] = status['checkedAt'];
                    item['currentError'] = status['lastError'];
                  }
                  return BanWatchItem.fromJson(item);
                })
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();
