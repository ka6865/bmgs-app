enum RankingSource { api, fallback, unavailable }

class RankingQuery {
  const RankingQuery({
    required this.tab,
    this.mode = 'all',
    this.perspective = 'all',
    this.matchType = 'all',
  });

  final String tab;
  final String mode;
  final String perspective;
  final String matchType;
}

class RankingEntry {
  const RankingEntry({
    required this.rank,
    required this.nickname,
    required this.platform,
    required this.value,
    required this.label,
  });

  final int rank;
  final String nickname;
  final String platform;
  final double value;
  final String label;

  static RankingEntry fromJson(Map<String, dynamic> json, int index) {
    return RankingEntry(
      rank: _int(json['rank']) ?? index + 1,
      nickname:
          json['nickname']?.toString() ??
          json['playerName']?.toString() ??
          json['name']?.toString() ??
          'Unknown',
      platform: json['platform']?.toString() ?? 'steam',
      value:
          _double(json['value']) ??
          _double(json['damage']) ??
          _double(json['kills']) ??
          _double(json['score']) ??
          _double(json['tierScore']) ??
          0,
      label:
          json['label']?.toString() ??
          json['tier']?.toString() ??
          json['secondary']?.toString() ??
          '',
    );
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class RankingBoard {
  const RankingBoard({
    required this.source,
    required this.query,
    required this.entries,
    required this.message,
  });

  final RankingSource source;
  final RankingQuery query;
  final List<RankingEntry> entries;
  final String message;

  bool get isFallback => source == RankingSource.fallback;

  static RankingBoard fromJson(
    Map<String, dynamic> json, {
    required RankingQuery query,
  }) {
    final rawEntries = json['entries'] ?? json['rankings'] ?? json['data'];
    final entries = rawEntries is List
        ? rawEntries
              .asMap()
              .entries
              .where((entry) => entry.value is Map)
              .map(
                (entry) => RankingEntry.fromJson(
                  Map<String, dynamic>.from(entry.value as Map),
                  entry.key,
                ),
              )
              .toList()
        : <RankingEntry>[];

    if (entries.isEmpty) {
      return unavailable(query: query, message: '랭킹 API 응답이 비어 있습니다.');
    }

    return RankingBoard(
      source: RankingSource.api,
      query: query,
      entries: entries,
      message: '실제 랭킹 API 응답입니다.',
    );
  }

  static RankingBoard fallback({
    required RankingQuery query,
    String message = '/api/rankings 모바일 계약 준비 중입니다.',
  }) => unavailable(query: query, message: message);

  static RankingBoard unavailable({
    required RankingQuery query,
    required String message,
  }) {
    return RankingBoard(
      source: RankingSource.unavailable,
      query: query,
      entries: _fallbackEntries(query.tab),
      message: message,
    );
  }

  static List<RankingEntry> _fallbackEntries(String tab) => const [];
}
