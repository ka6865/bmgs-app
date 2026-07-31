/// `division.bro.official.pc-2018-42` 형태의 시즌 ID를 `시즌 42`로 표기한다.
///
/// 웹의 `Season ${id.split('-').pop()}` 규칙과 같은 번호를 사용한다.
/// 번호를 해석할 수 없으면 원본 ID를 그대로 보여준다.
String seasonLabel(String seasonId) {
  final trimmed = seasonId.trim();
  if (trimmed.isEmpty) return '기본 시즌';
  final number = int.tryParse(trimmed.split('-').last);
  if (number == null) return trimmed;
  return '시즌 $number';
}

class GameModeStats {
  const GameModeStats({
    required this.roundsPlayed,
    required this.wins,
    required this.top10s,
    required this.losses,
    required this.kills,
    required this.assists,
    required this.damageDealt,
    required this.timeSurvived,
    required this.currentTier,
    required this.currentRankPoint,
    required this.bestTier,
    required this.bestRankPoint,
    required this.headshotKills,
    required this.longestKill,
  });

  final int roundsPlayed;
  final int wins;
  final int top10s;
  final int losses;
  final int kills;
  final int assists;
  final double damageDealt;
  final double timeSurvived;
  final Map<String, dynamic>? currentTier;
  final int currentRankPoint;
  final Map<String, dynamic>? bestTier;
  final int bestRankPoint;
  final int headshotKills;
  final double longestKill;

  double get kd => losses > 0 ? kills / losses : kills.toDouble();
  double get kda =>
      losses > 0 ? (kills + assists) / losses : (kills + assists).toDouble();
  double get adr => roundsPlayed > 0 ? damageDealt / roundsPlayed : 0.0;
  double get winRate => roundsPlayed > 0 ? (wins / roundsPlayed) * 100.0 : 0.0;
  double get top10Rate =>
      roundsPlayed > 0 ? (top10s / roundsPlayed) * 100.0 : 0.0;

  String get currentTierName {
    if (currentTier == null) return 'Unranked';
    final tier = currentTier!['tier']?.toString() ?? 'Unranked';
    final sub = currentTier!['subTier']?.toString() ?? '';
    return sub.isEmpty ? tier : '$tier $sub';
  }

  static GameModeStats fromJson(Map<String, dynamic> json) {
    final roundsPlayed = _asInt(json['roundsPlayed']);

    // 경쟁전(ranked) 응답은 top10s/timeSurvived 대신 top10Ratio(0~1)와
    // avgSurvivalTime(라운드당 초)을 내려준다. 일반전과 동일한 지표로 환산한다.
    final top10s = json['top10s'] != null
        ? _asInt(json['top10s'])
        : (_asDouble(json['top10Ratio']) * roundsPlayed).round();
    final timeSurvived = json['timeSurvived'] != null
        ? _asDouble(json['timeSurvived'])
        : _asDouble(json['avgSurvivalTime']) * roundsPlayed;

    return GameModeStats(
      roundsPlayed: roundsPlayed,
      wins: _asInt(json['wins']),
      top10s: top10s,
      losses: _asInt(json['losses'] ?? json['deaths']),
      kills: _asInt(json['kills']),
      assists: _asInt(json['assists']),
      damageDealt: _asDouble(json['damageDealt']),
      timeSurvived: timeSurvived,
      currentTier: json['currentTier'] is Map
          ? Map<String, dynamic>.from(json['currentTier'])
          : null,
      currentRankPoint: _asInt(json['currentRankPoint'] ?? json['rankPoints']),
      bestTier: json['bestTier'] is Map
          ? Map<String, dynamic>.from(json['bestTier'])
          : null,
      bestRankPoint: _asInt(json['bestRankPoint'] ?? json['bestRankPoints']),
      headshotKills: _asInt(json['headshotKills']),
      longestKill: _asDouble(json['longestKill']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}

class PlayerStatsProfile {
  const PlayerStatsProfile({
    required this.nickname,
    required this.platform,
    required this.seasonId,
    required this.kd,
    required this.adr,
    required this.winRate,
    required this.averageRank,
    required this.roundsPlayed,
    required this.recentMatches,
    required this.matchModes,
    required this.seasonsList,
    required this.updatedAt,
    required this.modeStats,
  });

  final String nickname;
  final String platform;
  final String? seasonId;
  final double kd;
  final double adr;
  final double winRate;
  final double averageRank;
  final int roundsPlayed;
  final List<String> recentMatches;
  final Map<String, String> matchModes;
  final List<String> seasonsList;
  final DateTime? updatedAt;
  final Map<String, Map<String, GameModeStats>> modeStats;

  bool get hasSeasonStats => roundsPlayed > 0;

  static PlayerStatsProfile fromJson(Map<String, dynamic> json) {
    final stats = json['stats'];
    final Map<String, Map<String, GameModeStats>> parsedModeStats = {};

    if (stats is Map) {
      for (final queue in const ['ranked', 'normal']) {
        final queueStats = stats[queue];
        if (queueStats is Map) {
          final Map<String, GameModeStats> modeMap = {};
          for (final mode in const ['squad', 'duo', 'solo']) {
            final mStats = queueStats[mode];
            if (mStats is Map) {
              modeMap[mode] = GameModeStats.fromJson(
                Map<String, dynamic>.from(mStats),
              );
            }
          }
          if (modeMap.isNotEmpty) {
            parsedModeStats[queue] = modeMap;
          }
        }
      }
    }

    int totalRounds = 0;
    int losses = 0;
    int wins = 0;
    int kills = 0;
    double damage = 0;
    double rankPoints = 0;
    double bestRankPoint = 0;

    for (final queue in parsedModeStats.values) {
      for (final stats in queue.values) {
        totalRounds += stats.roundsPlayed;
        losses += stats.losses;
        wins += stats.wins;
        kills += stats.kills;
        damage += stats.damageDealt;
        rankPoints += stats.currentRankPoint;
        bestRankPoint += stats.bestRankPoint;
      }
    }

    // 서버는 `seasons: [{id, name}]` 형태로 내려준다.
    // 과거 문자열 배열(`seasonsList`)도 계속 지원한다.
    final rawSeasons = json['seasons'] ?? json['seasonsList'];
    final List<String> parsedSeasons = rawSeasons is List
        ? rawSeasons
              .map(
                (season) => season is Map
                    ? (season['id']?.toString() ?? '')
                    : season.toString(),
              )
              .where((id) => id.isNotEmpty)
              .toList()
        : const <String>[];

    return PlayerStatsProfile(
      nickname: json['nickname']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'steam',
      seasonId: json['seasonId']?.toString(),
      kd: losses > 0 ? kills / losses : kills.toDouble(),
      adr: totalRounds > 0 ? damage / totalRounds : 0,
      winRate: totalRounds > 0 ? wins / totalRounds * 100 : 0,
      averageRank: totalRounds > 0
          ? (rankPoints > 0 ? rankPoints : bestRankPoint) / totalRounds
          : 0,
      roundsPlayed: totalRounds,
      recentMatches: (json['recentMatches'] as List? ?? const [])
          .map((matchId) => matchId.toString())
          .where((matchId) => matchId.isNotEmpty)
          .toList(),
      matchModes: (json['matchModes'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      seasonsList: parsedSeasons,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      modeStats: parsedModeStats,
    );
  }
}

class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.mapName,
    this.mapId,
    required this.gameMode,
    required this.kills,
    required this.damage,
    required this.rank,
    required this.isFallback,
    this.tier,
    required this.createdAt,
    this.headshotKills = 0,
    this.timeSurvived = 0.0,
  });

  final String matchId;
  final String mapName;
  final String? mapId;
  final String gameMode;
  final int kills;
  final double damage;
  final int? rank;
  final bool isFallback;
  final Map<String, dynamic>? tier;
  final DateTime createdAt;
  final int headshotKills;
  final double timeSurvived;

  String get tierName {
    if (tier == null) return '';
    final t = tier!['tier']?.toString() ?? '';
    final sub = tier!['subTier']?.toString() ?? '';
    return sub.isEmpty ? t : '$t $sub';
  }

  static MatchSummary fallback({
    required String matchId,
    required String gameMode,
  }) {
    return MatchSummary(
      matchId: matchId,
      mapName: '분석 대기',
      mapId: null,
      gameMode: gameMode.isEmpty ? '모드 확인 중' : gameMode,
      kills: 0,
      damage: 0,
      rank: null,
      isFallback: true,
      tier: null,
      createdAt: DateTime.now(),
      headshotKills: 0,
      timeSurvived: 0.0,
    );
  }

  static MatchSummary fromJson(String matchId, Map<String, dynamic> json) {
    final matchInfo = json['matchInfo'] is Map
        ? json['matchInfo'] as Map
        : null;
    final player = json['player'] is Map ? json['player'] as Map : null;
    final stats = json['stats'] is Map ? json['stats'] as Map : null;

    final dateStr = _firstText([
      json['createdAt'],
      matchInfo?['date'],
    ], fallback: DateTime.now().toIso8601String());

    return MatchSummary(
      matchId: matchId,
      mapName: _firstText([
        json['mapName'],
        json['map'],
        matchInfo?['mapName'],
        matchInfo?['map'],
      ], fallback: '맵 정보 없음'),
      mapId: _nullableText([json['mapId'], matchInfo?['mapId']]),
      gameMode: _firstText([
        json['gameMode'],
        matchInfo?['mode'],
        matchInfo?['gameMode'],
      ], fallback: '모드 정보 없음'),
      kills: _firstNum([
        json['kills'],
        player?['kills'],
        stats?['kills'],
      ]).round(),
      damage: _firstNum([
        json['damage'],
        json['damageDealt'],
        player?['damage'],
        player?['damageDealt'],
        stats?['damage'],
        stats?['damageDealt'],
      ]),
      rank: _nullableInt([
        json['rank'],
        json['winPlace'],
        player?['rank'],
        player?['winPlace'],
        stats?['rank'],
        stats?['winPlace'],
      ]),
      isFallback: false,
      tier: json['tier'] is Map
          ? Map<String, dynamic>.from(json['tier'])
          : (json['currentTier'] is Map
                ? Map<String, dynamic>.from(json['currentTier'])
                : null),
      createdAt: DateTime.tryParse(dateStr) ?? DateTime.now(),
      headshotKills: _firstNum([
        json['headshotKills'],
        player?['headshotKills'],
        stats?['headshotKills'],
      ]).round(),
      timeSurvived: _firstNum([
        json['timeSurvived'],
        player?['timeSurvived'],
        stats?['timeSurvived'],
      ]),
    );
  }

  static String _firstText(List<Object?> values, {required String fallback}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static String? _nullableText(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static double _firstNum(List<Object?> values) {
    for (final value in values) {
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static int? _nullableInt(List<Object?> values) {
    final value = _firstNum(values);
    return value > 0 ? value.round() : null;
  }
}

class PlayerStatsBundle {
  const PlayerStatsBundle({
    required this.profile,
    required this.matches,
    required this.summaryFallback,
  });

  final PlayerStatsProfile profile;
  final List<MatchSummary> matches;
  final bool summaryFallback;
}

/// 전체 매치 화면의 모드 필터 유틸.
///
/// 서버가 주는 `squad-fpp`, `duo-fpp` 같은 값을 같은 그룹으로 묶는다.
class MatchModeFilters {
  const MatchModeFilters._();

  /// 필터 칩 노출 순서.
  static const order = ['solo', 'duo', 'squad'];

  /// 모드 문자열을 solo/duo/squad로 정규화한다. 알 수 없으면 null이다.
  static String? normalize(String gameMode) {
    final lower = gameMode.toLowerCase();
    if (lower.contains('squad')) return 'squad';
    if (lower.contains('duo')) return 'duo';
    if (lower.contains('solo')) return 'solo';
    return null;
  }

  static String label(String mode) => switch (mode) {
    'solo' => '솔로',
    'duo' => '듀오',
    'squad' => '스쿼드',
    _ => mode,
  };

  /// 목록에 실제로 존재하는 모드만 [order] 순서로 돌려준다.
  static List<String> availableModes(List<MatchSummary> matches) {
    final modes = <String>{};
    for (final match in matches) {
      final mode = normalize(match.gameMode);
      if (mode != null) modes.add(mode);
    }
    return order.where(modes.contains).toList();
  }

  /// 선택된 모드로 매치를 좁힌다. `all`이면 전체를 그대로 준다.
  static List<MatchSummary> apply(List<MatchSummary> matches, String mode) {
    if (mode == 'all') return matches;
    return matches.where((match) => normalize(match.gameMode) == mode).toList();
  }
}
