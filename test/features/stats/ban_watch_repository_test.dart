import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/stats/ban_watch_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

void main() {
  test('관심 추적 목록 조회와 명시적 삭제는 Bearer 및 DELETE 계약을 사용한다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/pubg/ban-watch': {
          'items': [
            {
              'id': 'watch-1',
              'platform': 'steam',
              'targetAccountId': 'account.target',
              'nicknameAtMatch': 'Opponent',
              'eventAt': '2026-10-01T12:00:00.000Z',
              'createdAt': '2026-10-01T13:00:00.000Z',
              'activeUntil': '2026-11-01T13:00:00.000Z',
            },
          ],
          'statuses': const [],
          'events': const [],
        },
      },
    );
    final repository = BanWatchRepository(
      client: BgmsApiClient(
        baseUrl: 'https://example.test',
        dio: createFakeDio(adapter),
      ),
    );

    final watches = await repository.fetch(accessToken: 'token-1');
    await repository.remove(
      watchId: watches.items.single.id,
      accessToken: 'token-1',
    );

    expect(adapter.recordedRequests, hasLength(2));
    expect(adapter.recordedRequests.first.method, 'GET');
    expect(
      adapter.recordedRequests.first.headers['Authorization'],
      'Bearer token-1',
    );
    expect(adapter.recordedRequests.last.method, 'DELETE');
    expect(adapter.recordedRequests.last.uri.queryParameters['id'], 'watch-1');
    expect(
      adapter.recordedRequests.last.headers['Authorization'],
      'Bearer token-1',
    );
  });
}
