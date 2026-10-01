class EncounterEntry {
  const EncounterEntry({
    required this.targetAccountId,
    required this.nickname,
    required this.role,
    required this.eventAt,
    this.weapon,
  });

  final String targetAccountId;
  final String nickname;
  final String role;
  final String eventAt;
  final String? weapon;

  factory EncounterEntry.fromJson(Map<String, dynamic> json) => EncounterEntry(
    targetAccountId: json['targetAccountId']?.toString() ?? '',
    nickname: json['nicknameAtMatch']?.toString() ?? '상대',
    role: json['role']?.toString() ?? 'killer',
    eventAt: json['eventAt']?.toString() ?? '',
    weapon: _nullableText(json['weapon']),
  );

  String get roleLabel => switch (role) {
    'knocker' => '기절시킨 상대',
    'finisher' => '마무리한 상대',
    _ => '처치한 상대',
  };
}

class EncounterMatch {
  const EncounterMatch({
    required this.matchId,
    required this.mapName,
    required this.gameMode,
    required this.entries,
  });

  final String matchId;
  final String mapName;
  final String gameMode;
  final List<EncounterEntry> entries;

  factory EncounterMatch.fromJson(Map<String, dynamic> json) {
    final rawEncounter = json['encounter'];
    final encounter = rawEncounter is Map
        ? Map<String, dynamic>.from(rawEncounter)
        : const <String, dynamic>{};
    final rawEntries = encounter['encounters'];
    return EncounterMatch(
      matchId: json['match_id']?.toString() ?? '',
      mapName: json['map_name']?.toString() ?? '맵 정보 없음',
      gameMode: json['game_mode']?.toString() ?? '모드 정보 없음',
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map(
                  (entry) =>
                      EncounterEntry.fromJson(Map<String, dynamic>.from(entry)),
                )
                .where((entry) => entry.targetAccountId.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class EncounterPage {
  const EncounterPage({
    required this.matches,
    required this.page,
    required this.totalPages,
    required this.subjectAccountId,
    required this.subjectNickname,
  });

  final List<EncounterMatch> matches;
  final int page;
  final int totalPages;
  final String subjectAccountId;
  final String subjectNickname;

  factory EncounterPage.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'];
    return EncounterPage(
      matches: rawMatches is List
          ? rawMatches
                .whereType<Map>()
                .map(
                  (match) =>
                      EncounterMatch.fromJson(Map<String, dynamic>.from(match)),
                )
                .toList(growable: false)
          : const [],
      page: _positiveInt(json['page']) ?? 1,
      totalPages: _nonNegativeInt(json['totalPages']) ?? 0,
      subjectAccountId: json['accountId']?.toString() ?? '',
      subjectNickname: json['nickname']?.toString() ?? '',
    );
  }
}

class EncounterProfile {
  const EncounterProfile({
    this.tier,
    this.averageDamage,
    this.rounds,
    this.checkedAt,
    this.retryAt,
    this.pending = false,
  });

  final String? tier;
  final num? averageDamage;
  final int? rounds;
  final DateTime? checkedAt;
  final DateTime? retryAt;
  final bool pending;

  factory EncounterProfile.fromJson(Map<String, dynamic> json) =>
      EncounterProfile(
        tier: _nullableText(json['tier']),
        averageDamage: json['averageDamage'] is num
            ? json['averageDamage'] as num
            : num.tryParse(json['averageDamage']?.toString() ?? ''),
        rounds: _nonNegativeInt(json['rounds']),
        checkedAt: DateTime.tryParse(json['checkedAt']?.toString() ?? ''),
        retryAt: DateTime.tryParse(json['retryAt']?.toString() ?? ''),
        pending: json['pending'] == true,
      );
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _positiveInt(Object? value) {
  final parsed = _nonNegativeInt(value);
  return parsed == null || parsed < 1 ? null : parsed;
}

int? _nonNegativeInt(Object? value) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return parsed == null || parsed < 0 ? null : parsed;
}
