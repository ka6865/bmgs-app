import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요약 캐시가 비어 있는 서버 상태를 재현하는 Fake.
///
/// 실제 서버 `matches-summary`는 캐시만 읽고 분석을 트리거하지 않아
/// 미분석 매치가 전부 missingMatchIds로 빠진다.
class _EmptySummaryClient extends Fake implements BgmsApiClient {
  _EmptySummaryClient({this.failingMatchIds = const {}});

  /// 상세 조회가 실패하는 매치. 개별 실패가 전체를 막지 않는지 확인한다.
  final Set<String> failingMatchIds;

  final List<String> detailRequests = [];

  @override
  Future<Map<String, dynamic>> fetchPlayer({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
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
    return {'summaries': {}, 'missingMatchIds': matchIds};
  }

  @override
  Future<Map<String, dynamic>> fetchMatchDetail({
    required String matchId,
    required String nickname,
    required String platform,
  }) async {
    detailRequests.add(matchId);
    if (failingMatchIds.contains(matchId)) {
      throw Exception('분석 실패');
    }
    return {
      'matchId': matchId,
      'mapName': '태이고',
      'gameMode': 'squad',
      'createdAt': '2026-07-31T15:06:35.092Z',
      'stats': {
        'kills': 2,
        'damageDealt': 244.5,
        'winPlace': 7,
        'headshotKills': 1,
        'timeSurvived': 1024,
      },
    };
  }
}

void main() {
  test('요약이 비면 상세 API로 앞쪽 매치를 채운다', () async {
    final client = _EmptySummaryClient();
    final repository = PlayerStatsRepository(client: client);

    final bundle = await repository.fetchPlayerStats(
      nickname: 'KangHeeSung_',
      platform: 'steam',
    );

    // 상한만큼만 상세를 호출한다.
    expect(
      client.detailRequests.length,
      PlayerStatsRepository.maxDetailBackfill,
    );
    expect(client.detailRequests, ['m1', 'm2', 'm3', 'm4']);

    final filled = bundle.matches.take(4).toList();
    for (final match in filled) {
      expect(match.isFallback, isFalse);
      expect(match.mapName, '태이고');
      expect(match.gameMode, 'squad');
      expect(match.kills, 2);
      expect(match.damage, 244.5);
      expect(match.rank, 7);
    }

    // 상한을 넘은 매치는 fallback으로 남는다.
    expect(bundle.matches[4].isFallback, isTrue);
    expect(bundle.matches[4].mapName, '분석 대기');
    expect(bundle.summaryFallback, isTrue);
  });

  test('개별 상세 조회 실패는 해당 매치만 fallback으로 남긴다', () async {
    final client = _EmptySummaryClient(failingMatchIds: {'m2'});
    final repository = PlayerStatsRepository(client: client);

    final bundle = await repository.fetchPlayerStats(
      nickname: 'KangHeeSung_',
      platform: 'steam',
    );

    expect(bundle.matches[0].isFallback, isFalse);
    expect(bundle.matches[1].isFallback, isTrue);
    expect(bundle.matches[2].isFallback, isFalse);
    expect(bundle.matches[3].isFallback, isFalse);
  });
}
