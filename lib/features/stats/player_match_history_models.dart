import 'player_stats_models.dart';

/// `/api/pubg/player/matches`의 페이지 단위 응답이다.
class PlayerMatchHistoryPage {
  const PlayerMatchHistoryPage({
    required this.matches,
    required this.page,
    required this.totalPages,
    required this.totalCount,
    this.historyIngest,
  });

  final List<MatchSummary> matches;
  final int page;
  final int totalPages;
  final int totalCount;
  final HistoryIngest? historyIngest;

  bool get hasPreviousPage => page > 1;
  bool get hasNextPage => page < totalPages;

  static PlayerMatchHistoryPage fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'];
    final matches = rawMatches is List
        ? rawMatches
              .whereType<Map>()
              .map((raw) => _summaryFromRecord(Map<String, dynamic>.from(raw)))
              .toList(growable: false)
        : const <MatchSummary>[];
    final page = _positiveInt(json['page']) ?? 1;
    final totalCount = _nonNegativeInt(json['totalCount']) ?? matches.length;
    final totalPages = _nonNegativeInt(json['totalPages']) ?? 0;
    return PlayerMatchHistoryPage(
      matches: matches,
      page: page,
      totalPages: totalPages,
      totalCount: totalCount,
      historyIngest: HistoryIngest.tryParse(json['historyIngest']),
    );
  }

  static MatchSummary _summaryFromRecord(Map<String, dynamic> record) {
    if (record['match_type']?.toString().trim().toLowerCase() ==
        'unavailable') {
      return MatchSummary.fallback(
        matchId: record['match_id']?.toString() ?? '',
        gameMode: '',
      );
    }
    return MatchSummary(
      matchId: record['match_id']?.toString() ?? '',
      mapName: record['map_name']?.toString().trim().isNotEmpty == true
          ? record['map_name'].toString()
          : '맵 정보 없음',
      gameMode: record['game_mode']?.toString().trim().isNotEmpty == true
          ? record['game_mode'].toString()
          : '모드 정보 없음',
      kills: _nonNegativeInt(record['kills']),
      damage: _nonNegativeDouble(record['damage']),
      rank: _positiveInt(record['win_place']),
      isFallback: false,
      createdAt: DateTime.tryParse(record['played_at']?.toString() ?? ''),
      matchType: record['match_type']?.toString(),
      timeSurvived: _nonNegativeDouble(record['survival_time']) ?? 0,
    );
  }
}

/// 수집 대기는 전체 PUBG 이력의 미저장 건수가 아니다.
class HistoryIngest {
  const HistoryIngest({
    this.pendingCount,
    this.unavailableCount,
    this.lastSavedAt,
  });

  final int? pendingCount;
  final int? unavailableCount;
  final DateTime? lastSavedAt;

  static HistoryIngest? tryParse(Object? value) {
    if (value is! Map) return null;
    return HistoryIngest(
      pendingCount: _nonNegativeInt(value['pendingCount']),
      unavailableCount: _nonNegativeInt(value['unavailableCount']),
      lastSavedAt: DateTime.tryParse(value['lastSavedAt']?.toString() ?? ''),
    );
  }
}

class MatchCollection {
  const MatchCollection({
    this.claimed,
    this.saved,
    this.alreadyStored,
    this.retry,
    this.unavailable,
    this.rateLimited,
    this.durationMs,
    this.failureCounts = const {},
  });

  final int? claimed;
  final int? saved;
  final int? alreadyStored;
  final int? retry;
  final int? unavailable;
  final bool? rateLimited;
  final int? durationMs;
  final Map<String, int> failureCounts;

  // 이전 서버에 alreadyStored가 없으면 saved를 신규 저장으로 추정하지 않는다.
  int? get newSaved {
    if (saved == null || alreadyStored == null) return null;
    final difference = saved! - alreadyStored!;
    return difference >= 0 ? difference : null;
  }

  static MatchCollection? tryParse(Object? value) {
    if (value is! Map) return null;
    final failures = <String, int>{};
    final rawFailures = value['failureCounts'];
    if (rawFailures is Map) {
      for (final entry in rawFailures.entries) {
        final count = _nonNegativeInt(entry.value);
        if (count != null) failures[entry.key.toString()] = count;
      }
    }
    return MatchCollection(
      claimed: _nonNegativeInt(value['claimed']),
      saved: _nonNegativeInt(value['saved']),
      alreadyStored: _nonNegativeInt(value['alreadyStored']),
      retry: _nonNegativeInt(value['retry']),
      unavailable: _nonNegativeInt(value['unavailable']),
      rateLimited: value['rateLimited'] is bool
          ? value['rateLimited'] as bool
          : null,
      durationMs: _nonNegativeInt(value['durationMs']),
      failureCounts: failures,
    );
  }
}

class PlayerMatchCollectionResult {
  const PlayerMatchCollectionResult({this.collection, this.historyIngest});

  final MatchCollection? collection;
  final HistoryIngest? historyIngest;

  static PlayerMatchCollectionResult fromJson(Map<String, dynamic> json) =>
      PlayerMatchCollectionResult(
        collection: MatchCollection.tryParse(json['collection']),
        historyIngest: HistoryIngest.tryParse(json['historyIngest']),
      );
}

int? _positiveInt(Object? value) {
  final parsed = _nonNegativeInt(value);
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _nonNegativeInt(Object? value) {
  if (value is num && value.isFinite && value >= 0) return value.round();
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 0 ? parsed : null;
}

double? _nonNegativeDouble(Object? value) {
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  final parsed = double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
}
