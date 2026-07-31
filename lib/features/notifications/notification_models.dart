import '../stats/player_stats_models.dart';

/// 알림 종류. 설정에서 종류별로 켜고 끌 수 있다.
enum BgmsNotificationKind { newMatch, tierChange, seasonChange }

extension BgmsNotificationKindLabel on BgmsNotificationKind {
  /// 저장소 직렬화 키. enum 이름 변경과 무관하게 유지한다.
  String get storageKey => switch (this) {
    BgmsNotificationKind.newMatch => 'new_match',
    BgmsNotificationKind.tierChange => 'tier_change',
    BgmsNotificationKind.seasonChange => 'season_change',
  };

  String get label => switch (this) {
    BgmsNotificationKind.newMatch => '새 매치',
    BgmsNotificationKind.tierChange => '티어 변동',
    BgmsNotificationKind.seasonChange => '시즌 변경',
  };

  static BgmsNotificationKind? fromStorageKey(String value) {
    for (final kind in BgmsNotificationKind.values) {
      if (kind.storageKey == value) return kind;
    }
    return null;
  }
}

/// 플레이어 한 명의 마지막 확인 상태. 다음 확인 때 비교 기준이 된다.
class PlayerSnapshot {
  const PlayerSnapshot({
    required this.nickname,
    required this.platform,
    required this.latestMatchId,
    required this.matchCount,
    required this.tierName,
    required this.seasonId,
    required this.capturedAt,
  });

  final String nickname;
  final String platform;

  /// 최근 매치 목록의 첫 항목. 비어 있으면 빈 문자열이다.
  final String latestMatchId;
  final int matchCount;
  final String tierName;
  final String seasonId;
  final DateTime capturedAt;

  String get playerId => '${platform.toLowerCase()}:${nickname.toLowerCase()}';

  /// API 응답에서 비교에 필요한 값만 추려낸다.
  static PlayerSnapshot fromProfile(
    PlayerStatsProfile profile, {
    required DateTime capturedAt,
  }) {
    return PlayerSnapshot(
      nickname: profile.nickname,
      platform: profile.platform,
      latestMatchId: profile.recentMatches.isEmpty
          ? ''
          : profile.recentMatches.first,
      matchCount: profile.recentMatches.length,
      tierName: _resolveTierName(profile),
      seasonId: profile.seasonId ?? '',
      capturedAt: capturedAt,
    );
  }

  /// 경쟁전 스쿼드 티어를 대표 티어로 쓴다. 없으면 다른 모드를 순서대로 찾는다.
  static String _resolveTierName(PlayerStatsProfile profile) {
    final ranked = profile.modeStats['ranked'];
    if (ranked == null || ranked.isEmpty) return 'Unranked';

    for (final mode in const ['squad', 'squad-fpp', 'duo', 'duo-fpp', 'solo']) {
      final stats = ranked[mode];
      if (stats != null && stats.currentTier != null) {
        return stats.currentTierName;
      }
    }
    final first = ranked.values.firstWhere(
      (stats) => stats.currentTier != null,
      orElse: () => ranked.values.first,
    );
    return first.currentTierName;
  }

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'platform': platform,
    'latestMatchId': latestMatchId,
    'matchCount': matchCount,
    'tierName': tierName,
    'seasonId': seasonId,
    'capturedAt': capturedAt.toIso8601String(),
  };

  static PlayerSnapshot? fromJson(Map<String, dynamic> json) {
    final nickname = json['nickname']?.toString() ?? '';
    final platform = json['platform']?.toString() ?? '';
    if (nickname.isEmpty || platform.isEmpty) return null;

    return PlayerSnapshot(
      nickname: nickname,
      platform: platform,
      latestMatchId: json['latestMatchId']?.toString() ?? '',
      matchCount: int.tryParse(json['matchCount']?.toString() ?? '') ?? 0,
      tierName: json['tierName']?.toString() ?? 'Unranked',
      seasonId: json['seasonId']?.toString() ?? '',
      capturedAt:
          DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// 사용자에게 보여줄 알림 한 건.
class BgmsNotification {
  const BgmsNotification({
    required this.id,
    required this.kind,
    required this.nickname,
    required this.platform,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final BgmsNotificationKind kind;
  final String nickname;
  final String platform;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// 알림을 누르면 이동할 전적 화면 경로.
  String get destination => Uri(
    path: '/stats',
    queryParameters: {'nickname': nickname, 'platform': platform},
  ).toString();

  BgmsNotification copyWith({bool? isRead}) {
    return BgmsNotification(
      id: id,
      kind: kind,
      nickname: nickname,
      platform: platform,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.storageKey,
    'nickname': nickname,
    'platform': platform,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };

  static BgmsNotification? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final kind = BgmsNotificationKindLabel.fromStorageKey(
      json['kind']?.toString() ?? '',
    );
    if (id.isEmpty || kind == null) return null;

    return BgmsNotification(
      id: id,
      kind: kind,
      nickname: json['nickname']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'steam',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: json['isRead'] == true,
    );
  }
}
