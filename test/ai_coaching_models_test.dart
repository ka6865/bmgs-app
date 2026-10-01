import 'package:bgms_mobile_app/features/stats/ai_coaching_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

void main() {
  final facts = {
    'topicId': 'firepower',
    'topic': '화력',
    'context': {
      'gameMode': 'squad-fpp',
      'matchType': 'competitive',
      'userMatchCount': 3,
    },
    'evidenceIds': ['damage'],
    'evidence': [
      {
        'id': 'damage',
        'label': '평균 화력',
        'userValue': '240',
        'benchmarkValue': null,
        'status': 'user_only',
        'userMatchCount': 2,
      },
    ],
    'analysisStatus': 'pending',
  };
  test('v2 해석 실패 이후에도 서버 지표와 실제 표본을 보존한다', () {
    final result = AiCoachingSummary.fromNdjson(
      [
        jsonEncode({
          'type': 'cards',
          'data': [facts],
        }),
        jsonEncode({'type': 'error', 'error': '해석 실패'}),
        jsonEncode({'type': 'done', 'valid': false}),
      ].join('\n'),
    );
    expect(result.status, AiCoachingStatus.unavailable);
    expect(result.summary, '해석 실패');
    expect(result.cards.single.matchCount, 3);
    expect(result.cards.single.evidence.single.userValue, '240');
    expect(result.cards.single.evidence.single.userMatchCount, 2);
    expect(result.cards.single.analysisReady, false);
  });
  test('최종 v2 카드는 초기 사실카드를 대체하고 잘못된 근거 해석은 숨긴다', () {
    final ready = {
      ...facts,
      'analysisStatus': 'ready',
      'kindOpinion': '엄폐를 유지하세요',
    };
    final result = AiCoachingSummary.fromNdjson(
      [
        jsonEncode({
          'type': 'cards',
          'data': [facts],
        }),
        jsonEncode({
          'type': 'final',
          'data': {
            'summary': '확인한 경기 요약',
            'cards': [ready],
          },
        }),
        jsonEncode({'type': 'done', 'valid': true}),
      ].join('\n'),
    );
    expect(result.cards.single.analysisReady, true);
    expect(result.cards.single.kindOpinion, '엄폐를 유지하세요');
    final invalid = AiCoachingFactCard.parseList([
      {
        ...ready,
        'evidenceIds': ['invented'],
      },
    ]);
    expect(invalid.single.analysisReady, false);
  });
  test('실제 v2 최종 필드와 부분 실패 카드를 함께 보존한다', () {
    final ready = {
      ...facts,
      'question': '화력은 어떤가?',
      'analysisStatus': 'ready',
      'kindOpinion': '엄폐를 유지하세요',
    };
    final finalPayload = {
      'schemaVersion': 2,
      'signature': '전술 코치',
      'signatureSub': '확인된 경기의 해석',
      'finalVerdict': '확인한 기록을 점검하세요',
      'cards': [ready],
      'actionItems': [
        {'icon': 'target', 'title': '위치 점검', 'desc': '다음 경기에서 엄폐를 확인하세요'},
      ],
    };
    final result = AiCoachingSummary.fromNdjson(
      [
        jsonEncode({
          'type': 'cards',
          'data': [facts],
        }),
        jsonEncode({'type': 'final', 'data': jsonEncode(finalPayload)}),
        jsonEncode({'type': 'error', 'error': '일부 해석 실패'}),
        jsonEncode({'type': 'done', 'valid': false}),
      ].join('\n'),
    );
    expect(result.status, AiCoachingStatus.unavailable);
    expect(result.summary, '일부 해석 실패');
    expect(result.cards.single.analysisReady, isTrue);
    expect(result.cards.single.evidence.single.userValue, '240');
    final success = AiCoachingSummary.fromJson(finalPayload);
    expect(success.title, '전술 코치');
    expect(success.subtitle, '확인된 경기의 해석');
    expect(success.summary, '확인한 기록을 점검하세요');
    expect(success.improvements.single, contains('위치 점검'));
    expect(success.cards.single.question, '화력은 어떤가?');
  });
  test('스트림 오류와 실패 완료는 최종 결과 뒤에도 성공으로 표시하지 않는다', () {
    for (final body in [
      '{"type":"error","error":"분석 실패"}',
      '{"type":"error","error":"분석 실패"}\n'
          '{"type":"done","valid":false}',
      '{"type":"final","data":{"summary":"임시 결과"}}\n'
          '{"type":"error","error":"분석 실패"}\n'
          '{"type":"done","valid":false}',
      '{"type":"final","data":"임시 결과"}\n'
          '{"type":"done","valid":false,"error":"분석 실패"}',
    ]) {
      final summary = AiCoachingSummary.fromNdjson(body);
      expect(summary.status, AiCoachingStatus.unavailable, reason: body);
      expect(summary.summary, '분석 실패', reason: body);
    }
  });

  test('최종 결과 없는 스트림은 원시 JSON을 성공 본문으로 표시하지 않는다', () {
    final summary = AiCoachingSummary.fromNdjson(
      '{"type":"visuals","data":{}}\n{"type":"done","valid":true}',
    );
    expect(summary.status, AiCoachingStatus.unavailable);
    expect(summary.summary, isNot(contains('"type"')));
  });

  test('정상 완료와 기존 JSON, 일반 텍스트 응답을 유지한다', () {
    for (final body in [
      '{"type":"final","data":{"summary":"정상 요약"}}\n'
          '{"type":"done","valid":true}',
      '{"type":"final","data":"정상 요약"}',
      '{"summary":"정상 요약"}',
      '정상 요약',
    ]) {
      final summary = AiCoachingSummary.fromNdjson(body);
      expect(summary.status, AiCoachingStatus.available, reason: body);
      expect(summary.summary, '정상 요약', reason: body);
    }
  });
}
