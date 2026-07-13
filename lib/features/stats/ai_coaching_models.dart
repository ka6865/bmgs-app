import 'dart:convert';

enum AiCoachingStatus {
  available,
  loginRequired,
  costRestricted,
  fallback,
  unavailable,
}

class AiCoachingSummary {
  const AiCoachingSummary({
    required this.status,
    required this.title,
    required this.summary,
    this.grade,
    required this.strengths,
    required this.weaknesses,
    required this.warnings,
    required this.improvements,
  });

  final AiCoachingStatus status;
  final String title;
  final String summary;
  final String? grade;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> warnings;
  final List<String> improvements;

  bool get hasActionableItems =>
      strengths.isNotEmpty ||
      weaknesses.isNotEmpty ||
      warnings.isNotEmpty ||
      improvements.isNotEmpty;

  static AiCoachingSummary unavailable(String reason) {
    return AiCoachingSummary(
      status: AiCoachingStatus.unavailable,
      title: 'AI 코칭 준비 전',
      summary: reason,
      grade: null,
      strengths: const [],
      weaknesses: const [],
      warnings: const [],
      improvements: const [],
    );
  }

  static AiCoachingSummary loginRequired() {
    return const AiCoachingSummary(
      status: AiCoachingStatus.loginRequired,
      title: '로그인 후 사용 가능',
      summary: 'AI 코칭은 서버 인증과 비용 정책이 확정된 뒤 로그인 사용자에게 제공합니다.',
      grade: null,
      strengths: [],
      weaknesses: [],
      warnings: ['AI 전술 분석은 로그인 후 이용할 수 있습니다.'],
      improvements: ['전적과 최근 매치를 먼저 확인하세요'],
    );
  }

  static AiCoachingSummary costRestricted() {
    return const AiCoachingSummary(
      status: AiCoachingStatus.costRestricted,
      title: 'AI 코칭 사용 제한',
      summary: '외부 AI 비용 보호를 위해 현재 모바일 앱에서는 요약 카드만 표시합니다.',
      grade: null,
      strengths: [],
      weaknesses: [],
      warnings: ['사용량 제한 또는 비용 정책으로 서버 분석이 제한되었습니다.'],
      improvements: ['최근 매치 분석 캐시가 충분할 때 다시 시도하세요'],
    );
  }

  static AiCoachingSummary fallback({
    required double adr,
    required double kd,
    required double winRate,
    required int matchCount,
  }) {
    final strengths = <String>[
      if (adr >= 250) '교전 기여도가 안정적입니다',
      if (kd >= 2) '킬 교환에서 우위를 만들고 있습니다',
      if (winRate >= 10) '상위권 마무리 경험이 있습니다',
    ];
    final weaknesses = <String>[
      if (adr < 180) '초반 교전 피해량을 더 확보해야 합니다',
      if (kd < 1) '무리한 진입 후 생존 손실이 보입니다',
      if (winRate < 5) '후반 운영 전환 지표가 낮습니다',
    ];

    return AiCoachingSummary(
      status: AiCoachingStatus.fallback,
      title: '최근 경기 기반 요약',
      summary: '모바일 AI 상세 리포트는 로그인/비용 정책 확정 전이라 핵심 지표 기반으로 표시합니다.',
      grade: _fallbackGrade(adr: adr, kd: kd, winRate: winRate),
      strengths: strengths.isEmpty ? ['최근 매치 데이터가 수집되고 있습니다'] : strengths,
      weaknesses: weaknesses.isEmpty ? ['큰 약점은 지표상 뚜렷하지 않습니다'] : weaknesses,
      warnings: [if (matchCount < 5) '최근 매치 표본이 적어 판단 신뢰도가 낮습니다'],
      improvements: [
        if (matchCount < 5) '최근 매치 표본을 5경기 이상 확보하세요',
        '교전 시작 전 위치 선점과 엄폐 전환을 우선하세요',
        '사망 직전 30초의 동선과 팀 거리 차이를 점검하세요',
      ],
    );
  }

  static AiCoachingSummary fromJson(Map<String, dynamic> json) {
    final status = _parseStatus(json['status']);
    final visuals = json['visuals'] is Map ? json['visuals'] as Map : null;
    final roleInfo = visuals?['roleInfo'] is Map
        ? visuals!['roleInfo'] as Map
        : null;
    final actionItems = _actionItems(json['actionItems']);
    final debateIssues = _debateIssues(json['debateIssues']);
    final weakness = json['weaknessDiagnostic']?.toString().trim();
    return AiCoachingSummary(
      status: status,
      title:
          json['title']?.toString() ??
          json['signature']?.toString() ??
          roleInfo?['title']?.toString() ??
          _titleFor(status),
      summary:
          json['summary']?.toString() ??
          json['finalVerdict']?.toString() ??
          json['final']?.toString() ??
          '',
      grade:
          json['grade']?.toString() ??
          json['tier']?.toString() ??
          roleInfo?['overallTier']?.toString() ??
          visuals?['overallTier']?.toString(),
      strengths: _nonEmptyOr(
        _stringList(json['strengths']),
        debateIssues.strengths,
      ),
      weaknesses: _nonEmptyOr(_stringList(json['weaknesses']), [
        if (weakness != null && weakness.isNotEmpty) weakness,
        ...debateIssues.weaknesses,
      ]),
      warnings: _stringList(json['warnings']),
      improvements: _nonEmptyOr(_stringList(json['improvements']), actionItems),
    );
  }

  static AiCoachingSummary fromNdjson(String body) {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) {
      return unavailable('AI 요약 응답이 비어 있습니다.');
    }

    final decodedBody = _tryDecode(cleanBody);
    if (decodedBody is Map<String, dynamic>) {
      return fromJson(decodedBody);
    }
    if (decodedBody is Map) {
      return fromJson(Map<String, dynamic>.from(decodedBody));
    }

    String finalText = '';
    Map<String, dynamic>? visuals;
    for (final line in const LineSplitter().convert(body)) {
      final decoded = _tryDecode(line);
      if (decoded is Map && decoded['type'] == 'visuals') {
        final data = decoded['data'];
        if (data is Map) visuals = Map<String, dynamic>.from(data);
      }
      if (decoded is Map && decoded['type'] == 'final') {
        final data = decoded['data'];
        if (data is Map) {
          final json = Map<String, dynamic>.from(data);
          if (visuals != null) json['visuals'] ??= visuals;
          return fromJson(json);
        }
        finalText = data?.toString() ?? '';
      }
    }

    if (finalText.trim().isEmpty) {
      return AiCoachingSummary(
        status: AiCoachingStatus.available,
        title: 'AI 코칭 요약',
        summary: cleanBody,
        grade: null,
        strengths: const [],
        weaknesses: const [],
        warnings: const [],
        improvements: const [],
      );
    }

    final decodedFinal = _tryDecode(finalText);
    if (decodedFinal is Map) {
      final json = Map<String, dynamic>.from(decodedFinal);
      if (visuals != null) json['visuals'] ??= visuals;
      return fromJson(json);
    }

    return AiCoachingSummary(
      status: AiCoachingStatus.available,
      title: 'AI 코칭 요약',
      summary: finalText,
      grade: null,
      strengths: const [],
      weaknesses: const [],
      warnings: const [],
      improvements: const [],
    );
  }

  static AiCoachingStatus _parseStatus(Object? value) {
    if (value == null) return AiCoachingStatus.available;
    return AiCoachingStatus.values.firstWhere(
      (status) => status.name == value.toString(),
      orElse: () => AiCoachingStatus.unavailable,
    );
  }

  static String _titleFor(AiCoachingStatus status) {
    return switch (status) {
      AiCoachingStatus.available => 'AI 코칭 요약',
      AiCoachingStatus.loginRequired => '로그인 후 사용 가능',
      AiCoachingStatus.costRestricted => 'AI 코칭 사용 제한',
      AiCoachingStatus.fallback => '최근 경기 기반 요약',
      AiCoachingStatus.unavailable => 'AI 코칭 준비 전',
    };
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _actionItems(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map) {
            final title = item['title']?.toString().trim() ?? '';
            final desc = item['desc']?.toString().trim() ?? '';
            return [title, desc].where((part) => part.isNotEmpty).join(' - ');
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static _DebateItems _debateIssues(Object? value) {
    if (value is! List) return const _DebateItems([], []);
    final strengths = <String>[];
    final weaknesses = <String>[];
    for (final item in value) {
      if (item is! Map) continue;
      final topic = item['topic']?.toString().trim() ?? '';
      final kind = item['kindOpinion']?.toString().trim() ?? '';
      final spicy = item['spicyOpinion']?.toString().trim() ?? '';
      if (kind.isNotEmpty) {
        strengths.add(topic.isEmpty ? kind : '$topic - $kind');
      }
      if (spicy.isNotEmpty) {
        weaknesses.add(topic.isEmpty ? spicy : '$topic - $spicy');
      }
    }
    return _DebateItems(
      strengths.take(2).toList(),
      weaknesses.take(2).toList(),
    );
  }

  static List<String> _nonEmptyOr(List<String> primary, List<String> fallback) {
    return primary.isNotEmpty ? primary : fallback;
  }

  static String _fallbackGrade({
    required double adr,
    required double kd,
    required double winRate,
  }) {
    final score = adr / 100 + kd + winRate / 10;
    if (score >= 6) return 'A';
    if (score >= 4) return 'B';
    return 'C';
  }

  static Object? _tryDecode(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    try {
      return jsonDecode(clean);
    } catch (_) {
      return null;
    }
  }
}

class _DebateItems {
  const _DebateItems(this.strengths, this.weaknesses);

  final List<String> strengths;
  final List<String> weaknesses;
}
