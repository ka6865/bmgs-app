import 'dart:convert';

/// 단일 경기 AI 코칭 결과. 서버가 JSON을 주면 카드 필드로, 아니면 글([markdown])로 보여준다.
class MatchAiResult {
  const MatchAiResult({
    this.coach,
    this.signature,
    this.signatureSub,
    this.feedback = const [],
    this.verdict,
    this.actions = const [],
    this.markdown,
  });

  final String? coach;
  final String? signature;
  final String? signatureSub;
  final List<String> feedback;
  final String? verdict;
  final List<({String icon, String title, String desc})> actions;

  /// JSON이 아닌 응답의 원문.
  final String? markdown;

  /// `/api/pubg/ai-analyze` NDJSON 응답을 읽는다. 서버가 실패를 알리면 [FormatException]을 던진다.
  static MatchAiResult fromNdjson(String body) {
    final buffer = StringBuffer();
    var done = false;
    for (final line in const LineSplitter().convert(body)) {
      if (line.trim().isEmpty) continue;
      final Object? event;
      try {
        event = jsonDecode(line);
      } on FormatException {
        throw const FormatException('AI 분석 응답을 읽을 수 없습니다.');
      }
      if (event is! Map) continue;
      final failed =
          event['type'] == 'error' ||
          (event['type'] == 'done' &&
              (event['valid'] == false || event['error'] != null));
      if (failed) {
        throw FormatException(
          event['error']?.toString() ?? 'AI 분석을 완료하지 못했습니다.',
        );
      }
      if (event['type'] == 'chunk' && event['data'] is String) {
        buffer.write(event['data']);
      }
      if (event['type'] == 'done') done = true;
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw FormatException(
        done ? 'AI 분석 결과가 비어 있습니다.' : 'AI 분석 응답이 중간에 끊겼습니다.',
      );
    }
    return parse(text);
  }

  static MatchAiResult parse(String text) {
    final cleaned = text
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    Object? data;
    try {
      data = jsonDecode(cleaned);
    } on FormatException {
      data = null;
    }
    if (data is! Map) return MatchAiResult(markdown: text);
    String? str(Object? value) {
      final result = value is String || value is num ? value.toString() : null;
      return result == null || result.trim().isEmpty ? null : result.trim();
    }

    return MatchAiResult(
      coach: str(data['coach']),
      signature: str(data['signature']),
      signatureSub: str(data['signatureSub']),
      feedback: [
        if (data['briefFeedback'] is List)
          for (final point in data['briefFeedback'] as List) ?str(point),
      ],
      verdict: str(data['finalVerdict']),
      actions: [
        if (data['actionItems'] is List)
          for (final item in (data['actionItems'] as List).whereType<Map>())
            if (str(item['title']) != null)
              (
                icon: str(item['icon']) ?? '•',
                title: str(item['title'])!,
                desc: str(item['desc']) ?? '',
              ),
      ],
    );
  }
}
