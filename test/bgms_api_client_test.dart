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

  test('buildMapMarkersUri joins selected layers for mobile map fallback', () {
    final client = BgmsApiClient(baseUrl: 'https://bgms.kr');

    final uri = client.buildMapMarkersUri(
      mapId: 'Erangel',
      layers: const ['Garage', 'SecretRoom'],
    );

    expect(uri.path, '/api/maps/Erangel/markers');
    expect(uri.queryParameters['layers'], 'Garage,SecretRoom');
  });
}
