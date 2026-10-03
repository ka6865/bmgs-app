import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요약 캐시가 비어 있는 서버 상태를 재현하는 Fake.
class _EmptySummaryClient extends Fake implements BgmsApiClient {
  var summaryRequests = 0;

  @override
  Future<Map<String, dynamic>> fetchPlayer({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
    bool autoRefresh = false,
  }) async {
    return {
      'nickname': nickname,
      'platform': platform,
      'seasonId': season,
      'stats': {},
      'recentMatches': ['m1', 'm2', 'm3', 'm4', 'm5', 'm6'],
      // 서버가 모드 정보를 주지 않는 상황을 재현한다.
      'matchModes': {},
      'seasonsList': [],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchMatchesSummary({
    required List<String> matchIds,
    required String nickname,
    required String platform,
  }) async {
    summaryRequests++;
    return {'summaries': {}, 'missingMatchIds': matchIds};
  }
}

void main() {
  test('요약이 비면 상세 API를 호출하지 않고 경기 정보 없음 카드로 남긴다', () async {
    final client = _EmptySummaryClient();
    final repository = PlayerStatsRepository(client: client);

    final bundle = await repository.fetchPlayerStats(
      nickname: 'KangHeeSung_',
      platform: 'steam',
    );

    expect(bundle.matches, hasLength(6));
    expect(bundle.matches.every((match) => match.isFallback), isTrue);
    expect(bundle.matches.first.kills, isNull);
    expect(bundle.matches.first.damage, isNull);
    expect(bundle.matches.first.createdAt, isNull);
    expect(bundle.summaryFallback, isTrue);
    expect(client.summaryRequests, 1);
  });

  test('알림용 조회는 요약 API 자체를 생략할 수 있다', () async {
    final client = _EmptySummaryClient();
    final repository = PlayerStatsRepository(client: client);

    final bundle = await repository.fetchPlayerStats(
      nickname: 'KangHeeSung_',
      platform: 'steam',
      includeSummaries: false,
    );

    expect(bundle.matches, isEmpty);
    expect(bundle.summaryFallback, isFalse);
    expect(client.summaryRequests, 0);
  });
}
