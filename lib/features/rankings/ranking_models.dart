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

  String get displaySourceLabel => switch (source) {
    RankingSource.api => '최신 랭킹',
    RankingSource.fallback || RankingSource.unavailable => '준비 중',
  };

  String get displayMessage {
    if (source == RankingSource.api) {
      return '최근 경기 데이터를 기준으로 집계한 랭킹입니다.';
    }
    if (message.contains('비어')) {
      return '아직 이 조건에 맞는 랭킹 데이터가 없습니다. 필터를 바꾸거나 잠시 후 다시 확인해 주세요.';
    }
    return '랭킹 데이터를 일시적으로 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }

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
      message: '랭킹 데이터를 불러왔습니다.',
    );
  }

  static RankingBoard fallback({
    required RankingQuery query,
    String message = '랭킹 데이터를 준비하고 있습니다.',
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
