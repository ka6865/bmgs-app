import 'player_stats_models.dart';

/// 1. 팀 백업 지표 모델
class TradeStats {
  const TradeStats({
    required this.teammateKnocks,
    required this.suppCount,
    required this.tradeKills,
    required this.smokeCount,
    required this.smokeRescues,
    required this.revCount,
    required this.baitCount,
    required this.tradeLatencyMs,
    required this.reactionLatencyMs,
    required this.coverRate,
    required this.enemyTeamWipes,
  });

  final int teammateKnocks;
  final int suppCount;
  final int tradeKills;
  final int smokeCount;
  final int smokeRescues;
  final int revCount;
  final int baitCount;
  final double tradeLatencyMs;
  final double reactionLatencyMs;
  final double coverRate;
  final int enemyTeamWipes;

  static TradeStats fromJson(Map<String, dynamic> json) {
    return TradeStats(
      teammateKnocks: _asInt(json['teammateKnocks']),
      suppCount: _asInt(json['suppCount']),
      tradeKills: _asInt(json['tradeKills']),
      smokeCount: _asInt(json['smokeCount']),
      smokeRescues: _asInt(json['smokeRescues']),
      revCount: _asInt(json['revCount']),
      baitCount: _asInt(json['baitCount']),
      tradeLatencyMs: _asDouble(json['tradeLatencyMs']),
      reactionLatencyMs: _asDouble(json['reactionLatencyMs']),
      coverRate: _asDouble(json['coverRate']),
      enemyTeamWipes: _asInt(json['enemyTeamWipes']),
    );
  }

  static TradeStats empty() {
    return const TradeStats(
      teammateKnocks: 0,
      suppCount: 0,
      tradeKills: 0,
      smokeCount: 0,
      smokeRescues: 0,
      revCount: 0,
      baitCount: 0,
      tradeLatencyMs: 0,
      reactionLatencyMs: 0,
      coverRate: 0,
      enemyTeamWipes: 0,
    );
  }
}

/// 2. 교전 고립도 모델
class IsolationData {
  const IsolationData({
    required this.isolationIndex,
    required this.combatIsolation,
    required this.deathIsolation,
    required this.minDist,
    required this.heightDiff,
    required this.isCrossfire,
    required this.teammateCount,
  });

  final double isolationIndex;
  final double combatIsolation;
  final double deathIsolation;
  final double minDist;
  final double heightDiff;
  final bool isCrossfire;
  final int teammateCount;

  static IsolationData fromJson(Map<String, dynamic> json) {
    return IsolationData(
      isolationIndex: _asDouble(json['isolationIndex']),
      combatIsolation: _asDouble(json['combatIsolation']),
      deathIsolation: _asDouble(json['deathIsolation']),
      minDist: _asDouble(json['minDist']),
      heightDiff: _asDouble(json['heightDiff']),
      isCrossfire: json['isCrossfire'] == true,
      teammateCount: _asInt(json['teammateCount']),
    );
  }

  static IsolationData empty() {
    return const IsolationData(
      isolationIndex: 0.0,
      combatIsolation: 0.0,
      deathIsolation: 0.0,
      minDist: 0.0,
      heightDiff: 0.0,
      isCrossfire: false,
      teammateCount: 0,
    );
  }
}

/// 3. 1:1 결투 및 복수(Reversal) 지표 모델
class DuelStats {
  const DuelStats({
    required this.wins,
    required this.losses,
    required this.reversals,
    required this.reversalAttempts,
    required this.duelWinRate,
  });

  final int wins;
  final int losses;
  final int reversals;
  final int reversalAttempts;
  final double duelWinRate;

  static DuelStats fromJson(Map<String, dynamic> json) {
    return DuelStats(
      wins: _asInt(json['wins']),
      losses: _asInt(json['losses']),
      reversals: _asInt(json['reversals']),
      reversalAttempts: _asInt(json['reversalAttempts']),
      duelWinRate: _asDouble(json['duelWinRate']),
    );
  }

  static DuelStats empty() {
    return const DuelStats(
      wins: 0,
      losses: 0,
      reversals: 0,
      reversalAttempts: 0,
      duelWinRate: 0.0,
    );
  }
}

/// 4. 교전 압박 지표 모델
class CombatPressure {
  const CombatPressure({
    required this.pressureIndex,
    required this.isClutched,
    required this.maxHitDistance,
  });

  final double pressureIndex;
  final bool isClutched;
  final double maxHitDistance;

  static CombatPressure fromJson(Map<String, dynamic> json) {
    return CombatPressure(
      pressureIndex: _asDouble(json['pressureIndex']),
      isClutched: json['isClutched'] == true,
      maxHitDistance: _asDouble(json['maxHitDistance']),
    );
  }

  static CombatPressure empty() {
    return const CombatPressure(
      pressureIndex: 0.0,
      isClutched: false,
      maxHitDistance: 0.0,
    );
  }
}

/// 5. 차량 전투 성과 지표 모델
class VehicleCombatStats {
  const VehicleCombatStats({
    required this.leadShotKills,
    required this.leadShotKnocks,
    required this.ridingShotKills,
    required this.ridingShotKnocks,
    required this.roadKills,
    required this.roadKnocks,
  });

  final int leadShotKills;
  final int leadShotKnocks;
  final int ridingShotKills;
  final int ridingShotKnocks;
  final int roadKills;
  final int roadKnocks;

  static VehicleCombatStats fromJson(Map<String, dynamic> json) {
    return VehicleCombatStats(
      leadShotKills: _asInt(json['leadShotKills']),
      leadShotKnocks: _asInt(json['leadShotKnocks']),
      ridingShotKills: _asInt(json['ridingShotKills']),
      ridingShotKnocks: _asInt(json['ridingShotKnocks']),
      roadKills: _asInt(json['roadKills']),
      roadKnocks: _asInt(json['roadKnocks']),
    );
  }

  static VehicleCombatStats empty() {
    return const VehicleCombatStats(
      leadShotKills: 0,
      leadShotKnocks: 0,
      ridingShotKills: 0,
      ridingShotKnocks: 0,
      roadKills: 0,
      roadKnocks: 0,
    );
  }
}

/// 6. 벤치마크 점수 모델
class BenchmarkBreakdown {
  const BenchmarkBreakdown({
    required this.combat,
    required this.tactical,
    required this.survival,
    required this.score,
    required this.tier,
    this.impactGrade,
    required this.impactReasons,
  });

  final double combat;
  final double tactical;
  final double survival;
  final double score;
  final String tier;
  final String? impactGrade;
  final List<String> impactReasons;

  static BenchmarkBreakdown fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty();
    final breakdown = json['breakdown'] is Map ? json['breakdown'] as Map : const {};
    return BenchmarkBreakdown(
      combat: _asDouble(breakdown['combat']),
      tactical: _asDouble(breakdown['tactical']),
      survival: _asDouble(breakdown['survival']),
      score: _asDouble(json['score']),
      tier: json['tier']?.toString() ?? '일반',
      impactGrade: json['impactGrade']?.toString(),
      impactReasons: (json['impactReasons'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static BenchmarkBreakdown empty() {
    return const BenchmarkBreakdown(
      combat: 0.0,
      tactical: 0.0,
      survival: 0.0,
      score: 0.0,
      tier: '분석 대기',
      impactGrade: null,
      impactReasons: [],
    );
  }
}

/// 매치 상세 전체 데이터 모델
class MatchDetail {
  const MatchDetail({
    required this.matchId,
    required this.mapName,
    this.mapId,
    required this.gameMode,
    required this.nickname,
    required this.kills,
    required this.damage,
    required this.rank,
    required this.survivalSeconds,
    required this.teamKills,
    required this.isFallback,
    this.message,
    required this.tradeStats,
    required this.isolationData,
    required this.duelStats,
    required this.combatPressure,
    required this.vehicleCombat,
    required this.benchmark,
  });

  final String matchId;
  final String mapName;
  final String? mapId;
  final String gameMode;
  final String nickname;
  final int kills;
  final double damage;
  final int? rank;
  final int survivalSeconds;
  final int teamKills;
  final bool isFallback;
  final String? message;

  // 고정밀 전술 분석 필드
  final TradeStats tradeStats;
  final IsolationData isolationData;
  final DuelStats duelStats;
  final CombatPressure combatPressure;
  final VehicleCombatStats vehicleCombat;
  final BenchmarkBreakdown benchmark;

  static MatchDetail fromJson(String matchId, Map<String, dynamic> json) {
    final matchInfo = json['matchInfo'] is Map ? json['matchInfo'] as Map : null;
    final player = json['player'] is Map ? json['player'] as Map : null;
    final stats = json['stats'] is Map ? json['stats'] as Map : null;
    final team = json['team'] is Map ? json['team'] as Map : null;

    final trade = json['tradeStats'] is Map ? Map<String, dynamic>.from(json['tradeStats']) : null;
    final iso = json['isolationData'] is Map ? Map<String, dynamic>.from(json['isolationData']) : null;
    final duel = json['duelStats'] is Map ? Map<String, dynamic>.from(json['duelStats']) : null;
    final pressure = json['combatPressure'] is Map ? Map<String, dynamic>.from(json['combatPressure']) : null;
    final bench = json['benchmark'] is Map ? Map<String, dynamic>.from(json['benchmark']) : null;

    return MatchDetail(
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
      nickname: _firstText([
        json['nickname'],
        player?['nickname'],
        player?['name'],
        stats?['name'],
      ], fallback: '플레이어'),
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
        team?['rank'],
      ]),
      survivalSeconds: _firstNum([
        json['survivalSeconds'],
        json['timeSurvived'],
        player?['timeSurvived'],
        stats?['timeSurvived'],
      ]).round(),
      teamKills: _firstNum([
        json['teamKills'],
        team?['kills'],
        team?['teamKills'],
      ]).round(),
      isFallback: false,
      message: json['message']?.toString(),
      tradeStats: trade != null ? TradeStats.fromJson(trade) : TradeStats.empty(),
      isolationData: iso != null ? IsolationData.fromJson(iso) : IsolationData.empty(),
      duelStats: duel != null ? DuelStats.fromJson(duel) : DuelStats.empty(),
      combatPressure: pressure != null ? CombatPressure.fromJson(pressure) : CombatPressure.empty(),
      vehicleCombat: VehicleCombatStats.fromJson(json),
      benchmark: BenchmarkBreakdown.fromJson(bench),
    );
  }

  static MatchDetail fromSummary(
    MatchSummary summary, {
    required String nickname,
    String? message,
  }) {
    return MatchDetail(
      matchId: summary.matchId,
      mapName: summary.mapName,
      mapId: summary.mapId,
      gameMode: summary.gameMode,
      nickname: nickname,
      kills: summary.kills,
      damage: summary.damage,
      rank: summary.rank,
      survivalSeconds: 0,
      teamKills: 0,
      isFallback: true,
      message: message,
      tradeStats: TradeStats.empty(),
      isolationData: IsolationData.empty(),
      duelStats: DuelStats.empty(),
      combatPressure: CombatPressure.empty(),
      vehicleCombat: VehicleCombatStats.empty(),
      benchmark: BenchmarkBreakdown.empty(),
    );
  }

  String get survivalText {
    if (survivalSeconds <= 0) return '-';
    final minutes = survivalSeconds ~/ 60;
    final seconds = survivalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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

// ---------------------------------------------------------------------------
// 파싱 유틸리티 함수들
// ---------------------------------------------------------------------------
int _asInt(Object? value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
