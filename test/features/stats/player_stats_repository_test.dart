import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';


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
    test('fetchPlayerStats forwards refresh parameter to BgmsApiClient', () async {
      final mockClient = MockBgmsApiClient();
      final repository = PlayerStatsRepository(client: mockClient);

      // 아래 코드는 'refresh' 파라미터가 없어서 컴파일 오류가 나거나 실패할 것입니다.
      // TDD 실패 단계를 위해 일단 에러가 나도록 작성합니다.
      // (Dart는 named parameter가 정의되어 있지 않으면 컴파일 에러를 냅니다)
      // compile error는 TDD 실패 테스트 통과용으로 유효합니다.
      await repository.fetchPlayerStats(
        nickname: 'TestUser',
        platform: 'steam',
        refresh: true,
      );

      expect(mockClient.lastRefresh, isTrue);
    });
  });
}
