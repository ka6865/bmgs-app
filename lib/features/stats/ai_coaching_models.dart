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
    this.cards = const [],
    this.subtitle,
  });

  final AiCoachingStatus status;
  final String title;
  final String summary;
  final String? grade;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> warnings;
  final List<String> improvements;
  final List<AiCoachingFactCard> cards;
  final String? subtitle;

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
      summary: '최근 경기 AI 코칭은 로그인한 사용자에게 제공합니다.',
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
      summary: '서버의 사용량 또는 비용 제한으로 AI 코칭 요청을 완료하지 못했습니다.',
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
      cards: AiCoachingFactCard.parseList(json['cards']),
      subtitle: json['signatureSub'] is String
          ? json['signatureSub'] as String
          : null,
    );
  }

  static AiCoachingSummary fromNdjson(String body) {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) {
      return unavailable('AI 요약 응답이 비어 있습니다.');
    }

    final decodedBody = _tryDecode(cleanBody);
    if (decodedBody is Map && decodedBody['type'] == null) {
      return fromJson(Map<String, dynamic>.from(decodedBody));
    }

    Object? finalData;
    Map<String, dynamic>? visuals;
    var cards = <AiCoachingFactCard>[];
    var hasStreamRecords = false;
    String? failure;
    for (final line in const LineSplitter().convert(body)) {
      final decoded = _tryDecode(line);
      if (decoded is! Map || decoded['type'] is! String) continue;
      hasStreamRecords = true;
      if (decoded['type'] == 'error' ||
          (decoded['type'] == 'done' && decoded['valid'] == false)) {
        failure ??= decoded['error']?.toString() ?? 'AI 요약 생성이 완료되지 않았습니다.';
      }
      if (decoded['type'] == 'cards') {
        final parsed = AiCoachingFactCard.parseList(decoded['data']);
        if (parsed.isNotEmpty) cards = parsed;
      }
      if (decoded['type'] == 'visuals' && decoded['data'] is Map) {
        visuals = Map<String, dynamic>.from(decoded['data'] as Map);
      }
      if (decoded['type'] == 'final') {
        finalData = decoded['data'];
        final finalJson = finalData is Map
            ? finalData
            : _tryDecode(finalData?.toString() ?? '');
        if (finalJson is Map) {
          final parsed = AiCoachingFactCard.parseList(finalJson['cards']);
          if (parsed.isNotEmpty) cards = parsed;
        }
      }
    }
    if (failure != null || (hasStreamRecords && finalData == null)) {
      return AiCoachingSummary(
        status: AiCoachingStatus.unavailable,
        title: cards.isEmpty ? 'AI 코칭 준비 전' : '경기 지표 · AI 해석 미완료',
        summary: failure ?? 'AI 요약의 최종 결과가 없습니다.',
        strengths: const [],
        weaknesses: const [],
        warnings: const [],
        improvements: const [],
        cards: cards,
      );
    }

    if (finalData is Map) {
      final json = Map<String, dynamic>.from(finalData);
      if (visuals != null) json['visuals'] ??= visuals;
      if (cards.isNotEmpty) {
        json['cards'] ??= cards.map((card) => card.json).toList();
      }
      return fromJson(json);
    }

    final finalText = finalData?.toString() ?? '';
    if (finalText.trim().isEmpty) {
      if (hasStreamRecords) {
        return unavailable('AI 요약의 최종 결과가 없습니다.');
      }
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
      if (cards.isNotEmpty) {
        json['cards'] ??= cards.map((card) => card.json).toList();
      }
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

class AiCoachingFactCard {
  AiCoachingFactCard(this.json);
  final Map<String, dynamic> json;
  String get topic => json['topic'] as String;
  String get question => json['question']?.toString() ?? '';
  String get analysisReason => json['analysisReason']?.toString() ?? '';
  String get gameMode => (json['context'] as Map)['gameMode']?.toString() ?? '';
  String get matchType =>
      (json['context'] as Map)['matchType']?.toString() ?? '';
  int get matchCount => _count((json['context'] as Map)['userMatchCount']) ?? 0;
  String get analysisStatus =>
      json['analysisStatus']?.toString() ?? 'unavailable';
  bool get analysisReady => analysisStatus == 'ready';
  String get kindOpinion => json['kindOpinion']?.toString() ?? '';
  String get spicyOpinion => json['spicyOpinion']?.toString() ?? '';
  String get reason => json['reason']?.toString() ?? '';
  String get evaluation => json['evaluation']?.toString() ?? '';
  List<AiCoachingEvidence> get evidence => (json['evidence'] as List)
      .whereType<Map>()
      .map((row) => AiCoachingEvidence(row))
      .toList();

  static List<AiCoachingFactCard> parseList(Object? value) {
    if (value is! List) return [];
    final result = <AiCoachingFactCard>[];
    final topics = <String>{};
    for (final row in value.whereType<Map>()) {
      if (row['topicId'] is! String ||
          row['topic'] is! String ||
          row['context'] is! Map ||
          row['evidence'] is! List) {
        continue;
      }
      if (!topics.add(row['topicId'] as String)) continue;
      final evidence = (row['evidence'] as List)
          .whereType<Map>()
          .where((item) => item['id'] is String && item['label'] is String)
          .toList();
      final ids = evidence.map((item) => item['id']).toSet();
      final refs = row['evidenceIds'];
      final validRefs = refs is List && refs.every(ids.contains);
      final json = Map<String, dynamic>.from(row);
      json['evidence'] = evidence;
      if (!validRefs ||
          ![
            'ready',
            'pending',
            'unavailable',
          ].contains(row['analysisStatus'])) {
        json['analysisStatus'] = 'unavailable';
      }
      result.add(AiCoachingFactCard(json));
    }
    return result;
  }
}

class AiCoachingEvidence {
  AiCoachingEvidence(this.json);
  final Map json;
  String get label => json['label'] as String;
  String? get userValue =>
      json['userValue'] is String ? json['userValue'] as String : null;
  String? get benchmarkValue =>
      json['status'] == 'comparable' && json['benchmarkValue'] is String
      ? json['benchmarkValue'] as String
      : null;
  String get benchmarkLabel => json['benchmarkLabel']?.toString() ?? '비교값';
  String? get unavailableReason => json['unavailableReason'] is String
      ? json['unavailableReason'] as String
      : null;
  int? get userMatchCount => _count(json['userMatchCount']);
  int? get sampleCount => _count(json['sampleCount']);
}

int? _count(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.toInt() : null;
