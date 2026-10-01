import 'package:bgms_mobile_app/features/stats/ai_coaching_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
