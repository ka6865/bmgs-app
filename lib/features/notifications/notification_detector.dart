import 'notification_models.dart';
import 'notification_settings.dart';

/// 티어 등급 순서. 낮은 인덱스가 낮은 등급이다.
///
/// Crystal은 Diamond보다 높고 Master보다 낮다.
/// 랭크 에셋(`/assets/rank/Crystal-1.webp` 등)에 실제로 존재하는 등급이다.
const _tierOrder = <String>[
  'Unranked',
  'Bronze',
  'Silver',
  'Gold',
  'Platinum',
  'Diamond',
  'Crystal',
  'Master',
  'Survivor',
];

/// 스냅샷 두 개를 비교해 알림 이벤트를 만든다.
///
/// 순수 함수다. 네트워크와 저장소에 의존하지 않으므로 그대로 서버로 옮길 수 있다.
/// [previous]가 null이면 첫 확인이므로 알림을 만들지 않는다. 앱을 처음 켰을 때
/// 과거 기록이 한꺼번에 알림으로 쏟아지는 것을 막는다.
List<BgmsNotification> detectNotifications({
  required PlayerSnapshot? previous,
  required PlayerSnapshot current,
  required NotificationSettings settings,
}) {
  if (previous == null) return const [];

  final events = <BgmsNotification>[];
  final timestamp = current.capturedAt;
  final idPrefix = '${current.playerId}:${timestamp.millisecondsSinceEpoch}';

  if (settings.isEnabled(BgmsNotificationKind.seasonChange) &&
      _isSeasonChanged(previous, current)) {
    events.add(
      BgmsNotification(
        id: '$idPrefix:season',
        kind: BgmsNotificationKind.seasonChange,
        nickname: current.nickname,
        platform: current.platform,
        title: '새 시즌이 시작되었습니다',
        body: '${current.nickname} 님의 새 시즌 전적을 확인해 보세요.',
        createdAt: timestamp,
      ),
    );
  }

  if (settings.isEnabled(BgmsNotificationKind.newMatch) &&
      _hasNewMatch(previous, current)) {
    events.add(
      BgmsNotification(
        id: '$idPrefix:match',
        kind: BgmsNotificationKind.newMatch,
        nickname: current.nickname,
        platform: current.platform,
        title: '${current.nickname} 님의 새 매치',
        body: _newMatchBody(previous, current),
        createdAt: timestamp,
      ),
    );
  }

  // 시즌이 바뀌면 티어가 초기화되므로 하락으로 오인하지 않도록 건너뛴다.
  if (settings.isEnabled(BgmsNotificationKind.tierChange) &&
      !_isSeasonChanged(previous, current) &&
      previous.tierName != current.tierName) {
    final promoted = _isPromotion(previous.tierName, current.tierName);
    events.add(
      BgmsNotification(
        id: '$idPrefix:tier',
        kind: BgmsNotificationKind.tierChange,
        nickname: current.nickname,
        platform: current.platform,
        title: promoted ? '티어가 올랐습니다' : '티어가 내려갔습니다',
        body:
            '${current.nickname} 님이 ${previous.tierName}에서 '
            '${current.tierName}(으)로 이동했습니다.',
        createdAt: timestamp,
      ),
    );
  }

  return events;
}

bool _isSeasonChanged(PlayerSnapshot previous, PlayerSnapshot current) {
  if (current.seasonId.isEmpty) return false;
  if (previous.seasonId.isEmpty) return false;
  return previous.seasonId != current.seasonId;
}

bool _hasNewMatch(PlayerSnapshot previous, PlayerSnapshot current) {
  if (current.latestMatchId.isEmpty) return false;
  return previous.latestMatchId != current.latestMatchId;
}

String _newMatchBody(PlayerSnapshot previous, PlayerSnapshot current) {
  final added = current.matchCount - previous.matchCount;
  if (added > 1) return '새 매치 $added건이 기록되었습니다.';
  return '새 매치가 기록되었습니다.';
}

/// 티어 상승 여부. 등급이 같으면 서브티어 숫자로 비교한다.
///
/// PUBG 서브티어는 숫자가 작을수록 높은 등급이다. Platinum 1이 Platinum 5보다 높다.
bool _isPromotion(String previousTier, String currentTier) {
  final previousRank = _tierRank(previousTier);
  final currentRank = _tierRank(currentTier);
  if (previousRank != currentRank) return currentRank > previousRank;

  final previousSub = _subTier(previousTier);
  final currentSub = _subTier(currentTier);
  if (previousSub == null || currentSub == null) return false;
  return currentSub < previousSub;
}

int _tierRank(String tierName) {
  final lower = tierName.toLowerCase();
  for (var index = _tierOrder.length - 1; index >= 0; index--) {
    if (lower.contains(_tierOrder[index].toLowerCase())) return index;
  }
  return 0;
}

int? _subTier(String tierName) {
  final match = RegExp(r'(\d+)').firstMatch(tierName);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
