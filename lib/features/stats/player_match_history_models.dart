import 'player_stats_models.dart';

/// `/api/pubg/player/matches`의 페이지 단위 응답이다.
class PlayerMatchHistoryPage {
  const PlayerMatchHistoryPage({
    required this.matches,
    required this.page,
    required this.totalPages,
    required this.totalCount,
  });

  final List<MatchSummary> matches;
  final int page;
  final int totalPages;
  final int totalCount;

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
    );
  }

  static MatchSummary _summaryFromRecord(Map<String, dynamic> record) {
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
