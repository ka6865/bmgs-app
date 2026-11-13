/// 서버 `/api/pubg/squad-analyze`, `/api/pubg/ai-squad` 응답 모델.
library;

int? _int(Object? value) => value is num ? value.round() : null;
String _text(Object? value) => value?.toString().trim() ?? '';
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ]
    : const [];

/// 함께 플레이한 팀 묶음. 같은 팀원 조합의 경기를 모은 단위다.
class SquadGroup {
  const SquadGroup({
    required this.groupKey,
    required this.teamMode,
    required this.matchCount,
    required this.members,
  });

  final String groupKey;
  final String teamMode;
  final int matchCount;
  final List<String> members;

  String get modeLabel => teamMode == 'duo' ? '듀오' : '스쿼드';

  static List<SquadGroup> listFromJson(Map<String, dynamic> json) => [
    for (final group in _maps(json['groups']))
      if (_text(group['groupKey']).isNotEmpty)
        SquadGroup(
          groupKey: _text(group['groupKey']),
          teamMode: _text(group['teamMode']),
          matchCount: _int(group['matchCount']) ?? 0,
          members: [
            for (final member in group['members'] as List? ?? const [])
              member.toString(),
          ],
        ),
  ];
}

/// 서버 계산 등급의 5개 축. 순서와 이름은 웹 `SQUAD_SCORE_AXES`와 같다.
const squadScoreAxes = <(String, String)>[
  ('survivalCare', '소생률'),
  ('backupSpeed', '백업 속도'),
  ('smokeRescue', '연막 구출'),
  ('damageBalance', '딜 균형'),
  ('placement', '순위 성과'),
];

class SquadRole {
  const SquadRole({
    required this.name,
    required this.role,
    required this.roleDescription,
    required this.avgDamage,
    required this.avgKills,
    required this.damageShare,
    required this.killShare,
  });

  final String name;
  final String role;
  final String roleDescription;
  final int? avgDamage;
  final double? avgKills;
  final int? damageShare;
  final int? killShare;
}

class SquadScene {
  const SquadScene({
    required this.title,
    required this.reason,
    required this.mapName,
    required this.displayTime,
    required this.isDanger,
  });

  final String title;
  final String reason;
  final String mapName;
  final String displayTime;
  final bool isDanger;
}

class SquadAnalysis {
  const SquadAnalysis({
    required this.groupKey,
    required this.matchCount,
    required this.grade,
    required this.scores,
    required this.roles,
    required this.scenes,
    this.windowDays,
  });

  final String groupKey;
  final int matchCount;

  /// 측정 축이 부족하면 서버가 등급을 보류해 null이다.
  final String? grade;

  /// 축별 0~100 점수. 측정하지 못한 축은 null이다.
  final Map<String, int?> scores;
  final List<SquadRole> roles;
  final List<SquadScene> scenes;
  final int? windowDays;

  factory SquadAnalysis.fromJson(Map<String, dynamic> json) {
    final scores = json['scores'] is Map ? json['scores'] as Map : const {};
    final grade = _text(json['squadGrade']);
    final recorded = json['recordedSummary'] is Map
        ? json['recordedSummary'] as Map
        : const {};
    return SquadAnalysis(
      groupKey: _text(json['groupKey']),
      matchCount: _int(json['matchCount']) ?? 0,
      grade: grade.isEmpty ? null : grade,
      scores: {for (final (key, _) in squadScoreAxes) key: _int(scores[key])},
      windowDays: _int(recorded['windowDays']),
      roles: [
        for (final role in _maps(json['roleProfiles']))
          SquadRole(
            name: _text(role['name']),
            role: _text(role['role']),
            roleDescription: _text(role['roleDesc']),
            avgDamage: _int(role['avgDamage']),
            avgKills: (role['avgKills'] as num?)?.toDouble(),
            damageShare: _int((role['shares'] as Map?)?['damage']),
            killShare: _int((role['shares'] as Map?)?['kill']),
          ),
      ],
      scenes: [
        for (final scene in _maps(json['causeScenes']))
          SquadScene(
            title: _text(scene['title']),
            reason: _text(scene['reason']),
            mapName: _text(scene['mapDisplayName'] ?? scene['mapName']),
            displayTime: _text(scene['displayTime']),
            isDanger: scene['severity'] == 'danger',
          ),
      ],
    );
  }
}

class SquadMemberFeedback {
  const SquadMemberFeedback({
    required this.name,
    required this.praise,
    required this.fault,
    required this.advice,
  });

  final String name;
  final String praise;
  final String fault;
  final String advice;
}

/// 스쿼드 AI 코칭. 근거가 없는 칸은 서버가 빈 문자열로 보내므로 화면에서 숨긴다.
class SquadAiResult {
  const SquadAiResult({
    required this.summary,
    required this.strength,
    required this.weakness,
    required this.coaching,
    required this.overall,
    required this.members,
  });

  final String summary;
  final String strength;
  final String weakness;
  final String coaching;
  final String overall;
  final List<SquadMemberFeedback> members;

  factory SquadAiResult.fromJson(Map<String, dynamic> json) => SquadAiResult(
    summary: _text(json['summary']),
    strength: _text(json['strength']),
    weakness: _text(json['weakness']),
    coaching: _text(json['coaching']),
    overall: _text(json['overallOpinion']),
    members: [
      for (final member in _maps(json['memberFeedbacks']))
        SquadMemberFeedback(
          name: _text(member['name']),
          praise: _text(member['praise']),
          fault: _text(member['fault']),
          advice: _text(member['advice']),
        ),
    ],
  );
}
