import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late BgmsApiClient client;
  setUp(() {
    adapter = FakeHttpAdapter();
    client = BgmsApiClient(
      baseUrl: 'https://bgms.kr',
      dio: createFakeDio(adapter),
    );
  });
  test('회원 GET과 문의 메시지는 Bearer 및 Idempotency-Key 계약을 보낸다', () async {
    adapter.stub('/api/support/tickets', {'tickets': []});
    adapter.stub('/api/support/tickets/t1/messages', {'message': {}});
    await client.fetchSupportTickets(accessToken: 'token');
    await client.createSupportMessage(
      ticketId: 't1',
      body: '추가 질문',
      idempotencyKey: 'uuid-key',
      accessToken: 'token',
    );
    expect(
      adapter.recordedRequests.first.headers['Authorization'],
      'Bearer token',
    );
    expect(
      adapter.recordedRequests.last.headers['Idempotency-Key'],
      'uuid-key',
    );
    expect(adapter.recordedRequests.last.data, {'body': '추가 질문'});
    await expectLater(
      client.fetchSupportTickets(accessToken: ''),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.recordedRequests.length, 2);
  });
  test('답글과 AI요약은 부모 ID와 v2를 명시한다', () async {
    adapter.stub('/api/mobile/board/posts/42/comments', {'id': 1});
    adapter.stub('/api/pubg/ai-summary', '{}');
    await client.createBoardComment(
      postId: 42,
      content: '답글',
      accessToken: 'token',
      parentId: 7,
    );
    expect(adapter.recordedRequests.last.data, {
      'content': '답글',
      'parent_id': 7,
    });
    await client.fetchAiSummary(
      matchIds: ['m'],
      nickname: 'TGLTN',
      platform: 'steam',
      accessToken: 'token',
    );
    expect(
      (adapter.recordedRequests.last.data as Map)['summaryContractVersion'],
      2,
    );
  });
  test('리플레이는 요청과 파일의 식별자를 검증하고 외부 URL에 토큰을 보내지 않는다', () async {
    final identity = {
      'matchId': 'm',
      'platform': 'steam',
      'mode': 'lite',
      'playerKey': 'a' * 32,
      'telemetryVersion': 1,
    };
    adapter.stub('/api/pubg/telemetry', {
      'identity': identity,
      'downloadUrl': 'https://assets.example/replay.json',
    });
    adapter.stub('/replay.json', {'identity': identity, 'events': []});
    await client.fetchTelemetry(
      matchId: 'm',
      nickname: 'TGLTN',
      platform: 'steam',
      mapName: 'Erangel',
    );
    expect(adapter.recordedRequests.last.headers['Authorization'], isNull);
    adapter.stub('/replay.json', {
      'identity': {...identity, 'matchId': 'other'},
    });
    await expectLater(
      client.fetchTelemetry(
        matchId: 'm',
        nickname: 'TGLTN',
        platform: 'steam',
        mapName: 'Erangel',
      ),
      throwsA(isA<ApiException>()),
    );
    adapter.stub('/api/pubg/telemetry', {
      'identity': identity,
      'downloadUrl': 'http://assets.example/replay.json',
    });
    final before = adapter.recordedRequests.length;
    await expectLater(
      client.fetchTelemetry(
        matchId: 'm',
        nickname: 'TGLTN',
        platform: 'steam',
        mapName: 'Erangel',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.recordedRequests.length, before + 1);
  });
}
