import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';

import '../../support/fake_http_adapter.dart';

class MockBgmsApiClient extends Fake implements BgmsApiClient {
  String? lastNickname;
  String? lastPlatform;
  String? lastSeason;
  bool? lastRefresh;

  @override
  Future<Map<String, dynamic>> fetchPlayer({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) async {
    lastNickname = nickname;
    lastPlatform = platform;
    lastSeason = season;
    lastRefresh = refresh;
    return {
      'nickname': nickname,
      'platform': platform,
      'seasonId': season,
      'stats': {},
      'recentMatches': [],
      'matchModes': {},
      'seasonsList': [],
    };
  }
}

void main() {
  group('PlayerStatsRepository Tests', () {
    test(
      'fetchPlayerStats forwards refresh parameter to BgmsApiClient',
      () async {
        final mockClient = MockBgmsApiClient();
        final repository = PlayerStatsRepository(client: mockClient);

        await repository.fetchPlayerStats(
          nickname: 'TestUser',
          platform: 'steam',
          refresh: true,
        );

        expect(mockClient.lastRefresh, isTrue);
      },
    );

    test('요약 API 503은 시즌 전적을 유지하고 상세 자동 조회 없이 fallback을 표시한다', () async {
      final playerJson = Map<String, dynamic>.from(
        jsonDecode(
              File('test/fixtures/player_response.json').readAsStringSync(),
            )
            as Map,
      );
      final expectedProfile = PlayerStatsProfile.fromJson(playerJson);
      final adapter = FakeHttpAdapter()
        ..stub('/api/pubg/player', playerJson)
        ..stub('/api/pubg/matches-summary', {
          'error': '요약 서버가 일시적으로 응답하지 않습니다.',
          'diagnostic': 'internal server trace',
        }, statusCode: 503);
      final repository = PlayerStatsRepository(
        client: BgmsApiClient(
          baseUrl: 'https://bgms.kr',
          dio: createFakeDio(adapter),
        ),
      );

      final bundle = await repository.fetchPlayerStats(
        nickname: 'TGLTN',
        platform: 'steam',
      );

      expect(bundle.profile.nickname, expectedProfile.nickname);
      expect(bundle.profile.roundsPlayed, expectedProfile.roundsPlayed);
      expect(bundle.profile.adr, expectedProfile.adr);
      expect(bundle.profile.seasonId, expectedProfile.seasonId);
      expect(
        bundle.matches.map((match) => match.matchId),
        expectedProfile.recentMatches.take(20),
      );
      expect(bundle.matches, isNotEmpty);
      expect(bundle.matches.every((match) => match.isFallback), isTrue);
      expect(bundle.summaryFallback, isTrue);
      expect(bundle.summaryError, '요약 서버가 일시적으로 응답하지 않습니다.');
      expect(adapter.requestedPaths.map((path) => Uri.parse(path).path), [
        '/api/pubg/player',
        '/api/pubg/matches-summary',
      ]);
    });
  });
}
