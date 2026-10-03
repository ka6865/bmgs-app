import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:bgms_mobile_app/features/rankings/ranking_models.dart';
import 'package:bgms_mobile_app/features/stats/ai_coaching_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlayerStatsProfile calculates core metrics from player API shape', () {
    final profile = PlayerStatsProfile.fromJson({
      'nickname': 'KangHeeSung_',
      'platform': 'steam',
      'seasonId': 'division.bro.official.pc-2018-31',
      'updatedAt': '2026-07-05T12:00:00.000Z',
      'stats': {
        'ranked': {
          'squad': {
            'roundsPlayed': 10,
            'wins': 2,
            'losses': 8,
            'kills': 24,
            'damageDealt': 3000,
            'rankPoints': 45,
          },
        },
        'normal': {
          'squad': {
            'roundsPlayed': 5,
            'wins': 1,
            'losses': 4,
            'kills': 6,
            'damageDealt': 900,
            'rankPoints': 30,
          },
        },
      },
      'recentMatches': ['match-1', 'match-2'],
      'matchModes': {'match-1': 'squad-fpp'},
    });

    expect(profile.nickname, 'KangHeeSung_');
    expect(profile.kd, closeTo(2.5, 0.01));
    expect(profile.adr, 260);
    expect(profile.winRate, 20);
    expect(profile.averageRank, 5);
    expect(profile.recentMatches, ['match-1', 'match-2']);
  });

  test('초기 큐·모드는 기록이 있는 항목을 선택하고 모두 없으면 경쟁 스쿼드다', () {
    final profile = PlayerStatsProfile.fromJson({
      'stats': {
        'ranked': {
          'squad': {'roundsPlayed': 0},
        },
        'normal': {
          'duo': {'roundsPlayed': 3},
        },
      },
    });
    expect(profile.firstPlayedMode, (queue: 'normal', mode: 'duo'));
    expect(PlayerStatsProfile.fromJson({}).firstPlayedMode, (
      queue: 'ranked',
      mode: 'squad',
    ));
  });

  test('저장 상태와 수집 등록 상태를 보존하고 부분 실패의 이전 시각을 유지한다', () {
    for (final entry in {
      'saved': PlayerSyncStatus.saved,
      'cached': PlayerSyncStatus.cached,
      'partial': PlayerSyncStatus.partial,
      'save_failed': PlayerSyncStatus.saveFailed,
    }.entries) {
      final profile = PlayerStatsProfile.fromJson({
        'syncStatus': entry.key,
        'historyDiscoveryStatus': 'queued',
        'updatedAt': '2026-10-01T12:00:00Z',
      });
      expect(profile.syncStatus, entry.value);
      expect(profile.historyDiscoveryStatus, HistoryDiscoveryStatus.queued);
      expect(profile.updatedAt, DateTime.utc(2026, 10, 1, 12));
    }
    final partial = PlayerStatsProfile.fromJson({
      'syncStatus': 'partial',
      'historyDiscoveryStatus': 'failed',
    });
    expect(partial.updatedAt, isNull);
    expect(partial.historyDiscoveryStatus, HistoryDiscoveryStatus.failed);
    expect(
      PlayerStatsProfile.fromJson({}).syncStatus,
      PlayerSyncStatus.unknown,
    );
  });

  test('MatchSummary parses common summary fields with fallback values', () {
    final summary = MatchSummary.fromJson('match-1', {
      'matchInfo': {
        'mapName': '에란겔',
        'mode': 'squad-fpp',
        'date': '2026-07-06T15:30:00.000Z',
      },
      'player': {'kills': 3, 'damageDealt': 450.5, 'winPlace': 4},
      'timeSurvived': 1234.5,
    });

    expect(summary.mapName, '에란겔');
    expect(summary.gameMode, 'squad-fpp');
    expect(summary.kills, 3);
    expect(summary.damage, 450.5);
    expect(summary.rank, 4);
    expect(summary.isFallback, isFalse);
    expect(summary.createdAt, DateTime.parse('2026-07-06T15:30:00.000Z'));
    expect(summary.timeSurvived, 1234.5);
  });

  test('강제 갱신 상태와 재시도 대기 시간을 읽는다', () {
    final profile = PlayerStatsProfile.fromJson({
      'nickname': 'tester',
      'platform': 'steam',
      'stats': const {},
      'statsAvailability': {
        'ranked': {'status': 'stale', 'updatedAt': '2026-07-30T00:00:00Z'},
        'normal': {'status': 'unavailable'},
      },
      'retryAfterSeconds': 60,
    });

    expect(
      profile.statsAvailability['ranked']?.status,
      StatsAvailabilityStatus.stale,
    );
    expect(
      profile.statsAvailability['normal']?.status,
      StatsAvailabilityStatus.unavailable,
    );
    expect(profile.retryAfterSeconds, 60);
  });

  test('요약이 없으면 경기 정보 없음 fallback에 0과 현재 시간을 만들지 않는다', () {
    final summary = MatchSummary.fallback(matchId: 'missing', gameMode: '');

    expect(summary.mapName, '경기 정보 없음');
    expect(summary.kills, isNull);
    expect(summary.damage, isNull);
    expect(summary.rank, isNull);
    expect(summary.createdAt, isNull);
  });

  test('unavailable placeholder는 실제 0킬 99등 기록으로 렌더링하지 않는다', () {
    final summary = MatchSummary.fromJson('unavailable-match', {
      'mapName': 'unknown',
      'mapId': 'unknown',
      'gameMode': 'unknown',
      'matchType': 'unavailable',
      'kills': 0,
      'damage': 0,
      'winPlace': 99,
    });

    expect(summary.isFallback, isTrue);
    expect(summary.mapName, '경기 정보 없음');
    expect(summary.kills, isNull);
    expect(summary.damage, isNull);
    expect(summary.rank, isNull);
    expect(summary.createdAt, isNull);
  });

  test('AiCoachingSummary parses normal NDJSON final response', () {
    final summary = AiCoachingSummary.fromNdjson(
      '{"type":"delta","data":"draft"}\n'
      '{"type":"final","data":"최종 요약"}',
    );

    expect(summary.status, AiCoachingStatus.available);
    expect(summary.summary, '최종 요약');
  });

  test('AiCoachingSummary ignores broken NDJSON lines before final', () {
    final summary = AiCoachingSummary.fromNdjson(
      'not-json\n{"type":"final","data":"복구된 요약"}',
    );

    expect(summary.status, AiCoachingStatus.available);
    expect(summary.summary, '복구된 요약');
  });

  test('AiCoachingSummary accepts plain text response safely', () {
    final summary = AiCoachingSummary.fromNdjson('plain text summary');

    expect(summary.status, AiCoachingStatus.available);
    expect(summary.summary, 'plain text summary');
  });

  test('AiCoachingSummary marks empty response unavailable', () {
    final summary = AiCoachingSummary.fromNdjson('   ');

    expect(summary.status, AiCoachingStatus.unavailable);
  });

  test('AiCoachingSummary parses restricted statuses from json', () {
    final login = AiCoachingSummary.fromJson({
      'status': 'loginRequired',
      'summary': '로그인이 필요합니다',
    });
    final cost = AiCoachingSummary.fromJson({
      'status': 'costRestricted',
      'summary': '사용량 제한',
    });

    expect(login.status, AiCoachingStatus.loginRequired);
    expect(cost.status, AiCoachingStatus.costRestricted);
  });

  test(
    'RankingBoard parses api entries and marks empty response unavailable',
    () {
      const query = RankingQuery(tab: 'damage');
      final board = RankingBoard.fromJson({
        'entries': [
          {
            'rank': 1,
            'nickname': 'Player',
            'platform': 'steam',
            'damage': 312.4,
          },
        ],
      }, query: query);
      final unavailable = RankingBoard.fromJson({'entries': []}, query: query);

      expect(board.source, RankingSource.api);
      expect(board.entries.single.nickname, 'Player');
      expect(board.entries.single.value, 312.4);
      expect(board.displaySourceLabel, '최신 랭킹');
      expect(board.displayMessage, contains('최근 7일'));
      expect(unavailable.source, RankingSource.unavailable);
      expect(unavailable.entries, isEmpty);
      expect(unavailable.displaySourceLabel, '준비 중');
      expect(unavailable.displayMessage, contains('필터'));
    },
  );

  test('MapMarkerLayer parses markers and exposes empty error state', () {
    final layer = MapMarkerLayer.fromJson({
      'markers': [
        {
          'id': 'garage-1',
          'label': '차량',
          'layer': 'Garage',
          'x': 0.25,
          'y': 0.75,
        },
      ],
    }, mapId: 'Erangel');
    final unavailable = MapMarkerLayer.fromJson({
      'markers': [],
    }, mapId: 'Erangel');

    expect(layer.source, MapMarkerSource.api);
    expect(layer.displaySourceLabel, '마커 연동');
    expect(layer.displayMessage, contains('전술 마커'));
    expect(layer.markers.single.layer, 'Garage');
    expect(layer.markers.single.source, MapMarkerSource.api);
    expect(layer.markers.single.x, 0.25);
    expect(layer.markers.single.y, 0.75);
    expect(unavailable.source, MapMarkerSource.fallback);
    expect(unavailable.markers, isEmpty);
    expect(unavailable.displaySourceLabel, '마커 준비 중');
    expect(unavailable.displayMessage, contains('다른 맵'));
  });

  test(
    'PlayerStatsProfile parses separate ranked and normal stats for each mode',
    () {
      final mockJson = {
        'nickname': 'TestPlayer',
        'platform': 'steam',
        'seasonId': 'pc-2026-01',
        'seasonsList': ['pc-2026-01'],
        'stats': {
          'ranked': {
            'squad': {
              'roundsPlayed': 10,
              'kills': 20,
              'deaths': 5,
              'damageDealt': 2500.0,
              'currentTier': {'tier': 'Gold', 'subTier': 'III'},
              'currentRankPoint': 2350,
            },
          },
          'normal': {
            'squad': {
              'roundsPlayed': 5,
              'wins': 1,
              'top10s': 3,
              'kills': 15,
              'losses': 4,
              'damageDealt': 1200.0,
            },
          },
        },
      };
      final profile = PlayerStatsProfile.fromJson(mockJson);
      expect(profile.modeStats['ranked']?['squad']?.roundsPlayed, 10);
      expect(profile.modeStats['ranked']?['squad']?.kills, 20);
      expect(
        profile.modeStats['ranked']?['squad']?.currentTierName,
        'Gold III',
      );
      expect(profile.modeStats['normal']?['squad']?.roundsPlayed, 5);
    },
  );

  group('seasonLabel', () {
    test('시즌 ID의 마지막 번호를 사람이 읽는 라벨로 바꾼다', () {
      expect(seasonLabel('division.bro.official.pc-2018-42'), '시즌 42');
      expect(seasonLabel('division.bro.official.pc-2026-01'), '시즌 1');
    });

    test('번호를 해석할 수 없으면 원본과 기본값을 유지한다', () {
      expect(seasonLabel('lifetime'), 'lifetime');
      expect(seasonLabel('   '), '기본 시즌');
    });
  });
}
