import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildPlayerUri encodes nickname platform and optional season', () {
    final client = BgmsApiClient(baseUrl: 'https://bgms.kr');

    final uri = client.buildPlayerUri(
      nickname: 'Test Player',
      platform: 'steam',
      season: 'division.bro.official.pc-2018-31',
    );

    expect(uri.path, '/api/pubg/player');
    expect(uri.queryParameters['nickname'], 'Test Player');
    expect(uri.queryParameters['platform'], 'steam');
    expect(uri.queryParameters['season'], 'division.bro.official.pc-2018-31');
  });

  test('buildMatchesSummaryUri points at the Next API summary endpoint', () {
    final client = BgmsApiClient(baseUrl: 'https://bgms.kr/');

    final uri = client.buildMatchesSummaryUri();

    expect(uri.toString(), 'https://bgms.kr/api/pubg/matches-summary');
  });

  test('buildMatchUri includes match nickname and platform', () {
    final client = BgmsApiClient(baseUrl: 'https://example.com/');

    final uri = client.buildMatchUri(
      matchId: 'match-1',
      nickname: 'KangHeeSung_',
      platform: 'steam',
    );

    expect(
      uri.toString(),
      'https://example.com/api/pubg/match?matchId=match-1&nickname=KangHeeSung_&platform=steam',
    );
  });

  test('buildAiSummaryUri points at the mobile AI summary endpoint', () {
    final client = BgmsApiClient(baseUrl: 'https://bgms.kr/');

    final uri = client.buildAiSummaryUri();

    expect(uri.path, '/api/pubg/ai-summary');
  });

  test('buildRankingsUri encodes ranking filters', () {
    final client = BgmsApiClient(baseUrl: 'https://bgms.kr');

    final uri = client.buildRankingsUri(
      tab: 'damage',
      mode: 'squad',
      perspective: 'fpp',
      matchType: 'ranked',
    );

    expect(uri.path, '/api/rankings');
    expect(uri.queryParameters['tab'], 'damage');
    expect(uri.queryParameters['mode'], 'squad');
    expect(uri.queryParameters['perspective'], 'fpp');
    expect(uri.queryParameters['matchType'], 'ranked');
  });

  test('buildMapMarkersUri joins selected layers for mobile map fallback', () {
    final client = BgmsApiClient(baseUrl: 'https://bgms.kr');

    final uri = client.buildMapMarkersUri(
      mapId: 'Erangel',
      layers: const ['Garage', 'SecretRoom'],
    );

    expect(uri.path, '/api/maps/Erangel/markers');
    expect(uri.queryParameters['layers'], 'Garage,SecretRoom');
  });

  test('buildBoardPostsUri encodes mobile board query', () {
    final client = BgmsApiClient(baseUrl: 'https://bgms.kr/');

    final uri = client.buildBoardPostsUri(
      category: 'free',
      cursor: '2026-07-05T00:00:00.000Z',
      query: 'erangel',
    );

    expect(uri.path, '/api/mobile/board/posts');
    expect(uri.queryParameters['category'], 'free');
    expect(uri.queryParameters['cursor'], '2026-07-05T00:00:00.000Z');
    expect(uri.queryParameters['q'], 'erangel');
  });

  test('buildBoardPostUri points at mobile board detail', () {
    final client = BgmsApiClient(baseUrl: 'https://bgms.kr/');

    final uri = client.buildBoardPostUri(42);

    expect(uri.toString(), 'https://bgms.kr/api/mobile/board/posts/42');
  });
}
