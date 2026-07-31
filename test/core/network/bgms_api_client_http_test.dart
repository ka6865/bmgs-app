import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;

  setUp(() {
    adapter = FakeHttpAdapter();
  });

  BgmsApiClient buildClient({AuthTokenProvider? authTokenProvider}) {
    return BgmsApiClient(
      baseUrl: 'https://bgms.kr',
      dio: createFakeDio(adapter),
      authTokenProvider: authTokenProvider,
    );
  }

  test('정상 JSON 응답을 맵으로 돌려준다', () async {
    adapter.stub('/api/pubg/player', {'nickname': 'tester'});

    final json = await buildClient().fetchPlayer(
      nickname: 'tester',
      platform: 'steam',
    );

    expect(json['nickname'], 'tester');
  });

  test('404 응답을 notFound ApiException으로 정규화한다', () async {
    adapter.stub('/api/rankings', {'error': '아직 준비되지 않았습니다.'}, statusCode: 404);

    await expectLater(
      buildClient().fetchRankings(tab: 'damage'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.notFound)
            .having((e) => e.message, 'message', '아직 준비되지 않았습니다.'),
      ),
    );
  });

  test('500 응답은 재시도 가능한 server 오류가 된다', () async {
    adapter.stub('/api/maps/Erangel/markers', {}, statusCode: 500);

    await expectLater(
      buildClient().fetchMapMarkers(mapId: 'Erangel'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.server)
            .having((e) => e.isRetryable, 'isRetryable', isTrue),
      ),
    );
  });

  test('AI 요약은 토큰이 없으면 호출 전에 unauthorized로 끊는다', () async {
    await expectLater(
      buildClient().fetchAiSummary(
        matchIds: const ['m1'],
        nickname: 'tester',
        platform: 'steam',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    expect(adapter.requestedPaths, isEmpty);
  });

  test('AI 요약은 authTokenProvider의 토큰으로 호출한다', () async {
    adapter.stub('/api/pubg/ai-summary', '{"advice":"근거리 교전을 줄이세요"}');

    final summary =
        await buildClient(
          authTokenProvider: () async => 'token-abc',
        ).fetchAiSummary(
          matchIds: const ['m1'],
          nickname: 'tester',
          platform: 'steam',
        );

    expect(summary, contains('근거리 교전'));
    expect(adapter.requestedPaths.single, contains('/api/pubg/ai-summary'));
  });

  test('명시 토큰이 authTokenProvider보다 우선한다', () async {
    adapter.stub('/api/pubg/ai-summary', '{}');

    await buildClient(authTokenProvider: () async => null).fetchAiSummary(
      matchIds: const ['m1'],
      nickname: 'tester',
      platform: 'steam',
      accessToken: 'explicit-token',
    );

    expect(adapter.requestedPaths, hasLength(1));
  });

  test('JSON 객체가 아닌 응답은 parse 오류로 처리한다', () async {
    adapter.stub('/api/pubg/player', '[1, 2, 3]');

    await expectLater(
      buildClient().fetchPlayer(nickname: 'tester', platform: 'steam'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.parse),
      ),
    );
  });

  test('suggest 응답에서 닉네임과 플랫폼을 추출한다', () async {
    adapter.stub('/api/pubg/suggest', {
      'suggestions': [
        {'nickname': 'alpha', 'platform': 'kakao'},
        {'name': 'beta'},
        'gamma',
        {'nickname': '  '},
      ],
    });

    final suggestions = await buildClient().fetchSuggestions('a');

    expect(suggestions.map((s) => s.nickname), ['alpha', 'beta', 'gamma']);
    // platform이 없거나 문자열 항목이면 steam으로 채운다.
    expect(suggestions.map((s) => s.platform), ['kakao', 'steam', 'steam']);
  });

  test('맵 카테고리 설정을 파싱한다', () async {
    adapter.stub('/api/maps/settings', {
      'mapCategories': {
        'Erangel': ['Garage', 'Esports', 'SecretRoom'],
        'Taego': ['Garage', ' Porter ', ''],
        'Broken': 'not-a-list',
        'Empty': <String>[],
      },
    });

    final categories = await buildClient().fetchMapCategories();

    expect(categories['Erangel'], ['Garage', 'Esports', 'SecretRoom']);
    // 공백은 정리하고 빈 항목은 제외한다.
    expect(categories['Taego'], ['Garage', 'Porter']);
    // 배열이 아니거나 비어 있으면 키를 만들지 않는다.
    expect(categories.containsKey('Broken'), isFalse);
    expect(categories.containsKey('Empty'), isFalse);
  });

  test('mapCategories가 없으면 빈 맵을 준다', () async {
    adapter.stub('/api/maps/settings', {'success': true});

    expect(await buildClient().fetchMapCategories(), isEmpty);
  });
}
